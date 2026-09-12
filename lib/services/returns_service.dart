import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class ReturnLineInput {
  final int productId;
  final String productName;
  final String barcode;
  final double unitPrice;
  final double quantity;

  const ReturnLineInput({
    required this.productId,
    required this.productName,
    required this.barcode,
    required this.unitPrice,
    required this.quantity,
  });
}

class SaleBarcodeReturnSource {
  final int saleId;
  final String invoiceNumber;
  final ReturnLineInput line;

  const SaleBarcodeReturnSource({
    required this.saleId,
    required this.invoiceNumber,
    required this.line,
  });
}

class ReturnsService {
  final AppDatabase db;

  ReturnsService(this.db);

  Future<List<ReturnLineInput>> saleLines(int saleId) async {
    final items = await db.saleItemsDao.getBySaleId(saleId);
    return items
        .map(
          (dynamic item) => ReturnLineInput(
            productId: item.productId as int,
            productName: item.productName as String,
            barcode: item.barcode as String,
            quantity: (item.quantity as num).toDouble(),
            unitPrice: (item.unitPrice as num).toDouble(),
          ),
        )
        .toList();
  }

  /// البحث عن أحدث فاتورة مكتملة تحتوي على الصنف بالباركود
  /// مع تجاهل الفواتير التي استُرجعت منها الكمية كاملة.
  Future<SaleBarcodeReturnSource?> findSaleByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;

    final rows = await db.customSelect(
      'SELECT si.sale_id, si.product_id, si.product_name, si.barcode, '
      'si.quantity, si.unit_price, si.id AS sale_item_id, '
      's.invoice_number, s.sale_date '
      'FROM sale_items si '
      'JOIN sales s ON s.id = si.sale_id '
      'WHERE s.status = ? AND si.barcode = ? '
      'ORDER BY s.sale_date DESC, si.id DESC',
      variables: [
        Variable.withString('completed'),
        Variable.withString(normalized),
      ],
      readsFrom: {db.saleItems, db.sales},
    ).get();

    for (final row in rows) {
      final saleId = row.read<int>('sale_id');
      final productId = row.read<int>('product_id');
      final sourceQuantity = row.read<double>('quantity');

      final returned = await _returnedQuantity(
        type: 'sale_return',
        sourceId: saleId,
        productId: productId,
      );

      final available = sourceQuantity - returned;
      if (available <= 0.000001) continue;

      return SaleBarcodeReturnSource(
        saleId: saleId,
        invoiceNumber: row.read<String>('invoice_number'),
        line: ReturnLineInput(
          productId: productId,
          productName: row.read<String>('product_name'),
          barcode: row.read<String>('barcode'),
          unitPrice: row.read<double>('unit_price'),
          quantity: available,
        ),
      );
    }

    return null;
  }

  Future<List<ReturnLineInput>> purchaseLines(int purchaseId) async {
    final items = await db.purchaseItemsDao.byPurchase(purchaseId);
    final grouped = <int, List<dynamic>>{};

    for (final item in items) {
      grouped.putIfAbsent(item.productId as int, () => []).add(item);
    }

    final result = <ReturnLineInput>[];
    for (final entry in grouped.entries) {
      final productItems = entry.value;
      final originalQuantity = productItems.fold<double>(
        0,
        (sum, dynamic item) =>
            sum + (item.quantity as num).toDouble(),
      );
      final originalTotal = productItems.fold<double>(
        0,
        (sum, dynamic item) =>
            sum + (item.total as num).toDouble(),
      );
      final returned = await _returnedQuantity(
        type: 'purchase_return',
        sourceId: purchaseId,
        productId: entry.key,
      );
      final available =
          (originalQuantity - returned).clamp(0.0, double.infinity).toDouble();

      if (available <= 0.000001) continue;

      final first = productItems.first;
      result.add(
        ReturnLineInput(
          productId: entry.key,
          productName: first.productName as String,
          barcode: first.barcode as String,
          quantity: available,
          unitPrice: originalQuantity > 0
              ? originalTotal / originalQuantity
              : (first.unitPrice as num).toDouble(),
        ),
      );
    }

    return result;
  }

  Future<double> _returnedQuantity({
    required String type,
    required int sourceId,
    required int productId,
  }) async {
    final sourceColumn =
        type == 'sale_return' ? 'sale_id' : 'purchase_id';

    final row = await db.customSelect(
      'SELECT COALESCE(SUM(ri.quantity), 0) AS value '
      'FROM return_items ri '
      'JOIN returns r ON r.id = ri.return_id '
      'WHERE r.type = ? AND r.$sourceColumn = ? '
      'AND r.status = ? AND ri.product_id = ?',
      variables: [
        Variable.withString(type),
        Variable.withInt(sourceId),
        Variable.withString('completed'),
        Variable.withInt(productId),
      ],
      readsFrom: {db.returns, db.returnItems},
    ).getSingle();

    return row.read<double>('value');
  }

  Future<double> _priorReturnTotal({
    required String type,
    required String column,
    required int sourceId,
  }) async {
    final row = await db.customSelect(
      'SELECT COALESCE(SUM(total), 0) AS value '
      'FROM returns WHERE type = ? AND $column = ? AND status = ?',
      variables: [
        Variable.withString(type),
        Variable.withInt(sourceId),
        Variable.withString('completed'),
      ],
      readsFrom: {db.returns},
    ).getSingle();

    return row.read<double>('value');
  }

  /// يعيد صافي سعر الوحدة بعد خصم خصم الفاتورة وتوزيعه
  /// تناسبيًا على بنود الفاتورة.
  double _effectiveUnitPrice({
    required double lineTotal,
    required double lineQuantity,
    required double invoiceSubtotal,
    required double invoiceDiscount,
  }) {
    if (lineQuantity <= 0) return 0;
    final share = invoiceSubtotal > 0
        ? invoiceDiscount * lineTotal / invoiceSubtotal
        : 0.0;
    final netLine =
        (lineTotal - share).clamp(0.0, double.infinity).toDouble();
    return netLine / lineQuantity;
  }

  Future<double> _saleReturnCost(Return returned) async {
    if (returned.saleId == null) return 0;

    final sourceItems =
        await db.saleItemsDao.getBySaleId(returned.saleId!);
    final returnedItems =
        await db.returnItemsDao.byReturn(returned.id);

    var cost = 0.0;
    for (final dynamic returnItem in returnedItems) {
      final matching = sourceItems
          .where((dynamic item) => item.productId == returnItem.productId)
          .toList();

      var quantity = 0.0;
      var totalCost = 0.0;

      for (final dynamic item in matching) {
        quantity += (item.quantity as num).toDouble();
        totalCost += ((item.purchasePriceAtSale as num) * (item.quantity as num)).toDouble();
      }

      if (quantity > 0) {
        cost += (returnItem.quantity as num).toDouble() * totalCost / quantity;
      }
    }

    return cost;
  }

  Future<int> createSaleReturn({
    required int saleId,
    required List<ReturnLineInput> items,
    String? reason,
    String? notes,
  }) async {
    final sale = await db.salesDao.getById(saleId);
    if (sale == null || sale.status != 'completed') {
      throw Exception('فاتورة البيع غير موجودة أو غير مكتملة');
    }

    return _create(
      type: 'sale_return',
      saleId: saleId,
      customerId: sale.customerId,
      items: items,
      reason: reason,
      notes: notes,
    );
  }

  Future<int> createPurchaseReturn({
    required int purchaseId,
    required List<ReturnLineInput> items,
    String? reason,
    String? notes,
  }) async {
    final purchase = await db.purchasesDao.getById(purchaseId);
    if (purchase == null || purchase.status != 'completed') {
      throw Exception('فاتورة الشراء غير موجودة أو غير مكتملة');
    }

    return _create(
      type: 'purchase_return',
      purchaseId: purchaseId,
      supplierId: purchase.supplierId,
      items: items,
      reason: reason,
      notes: notes,
    );
  }

  Future<int> _create({
    required String type,
    int? saleId,
    int? purchaseId,
    int? customerId,
    int? supplierId,
    required List<ReturnLineInput> items,
    String? reason,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw Exception('يجب إضافة صنف واحد على الأقل');
    }

    final uniqueProducts = <int>{};
    for (final item in items) {
      if (!uniqueProducts.add(item.productId)) {
        throw Exception('لا يمكن تكرار المنتج نفسه في نفس المرتجع');
      }
    }

    final sourceId = saleId ?? purchaseId!;

    return db.transaction(() async {
      final returnNumber =
          'RET-${DateTime.now().microsecondsSinceEpoch}';

      final sale = saleId == null
          ? null
          : await db.salesDao.getById(saleId);
      final purchase = purchaseId == null
          ? null
          : await db.purchasesDao.getById(purchaseId);

      if (type == 'sale_return' && sale == null) {
        throw Exception('فاتورة البيع غير موجودة');
      }
      if (type == 'purchase_return' && purchase == null) {
        throw Exception('فاتورة الشراء غير موجودة');
      }

      final List<dynamic> sourceItems = type == 'sale_return'
          ? await db.saleItemsDao.getBySaleId(sourceId)
          : await db.purchaseItemsDao.byPurchase(sourceId);

      final sourceSubtotal = type == 'sale_return'
          ? sale!.subtotal
          : purchase!.subtotal;
      final sourceDiscount = type == 'sale_return'
          ? sale!.discount
          : purchase!.discount;

      var total = 0.0;

      for (final item in items) {
        if (item.quantity <= 0) {
          throw Exception('كمية المرتجع يجب أن تكون أكبر من صفر');
        }

        final matching = sourceItems
            .where((dynamic line) => line.productId == item.productId)
            .toList();

        final sourceQuantity = matching.fold<double>(
          0,
          (sum, dynamic line) => sum + (line.quantity as num).toDouble(),
        );

        final alreadyReturned = await _returnedQuantity(
          type: type,
          sourceId: sourceId,
          productId: item.productId,
        );

        if (sourceQuantity <= 0 ||
            alreadyReturned + item.quantity > sourceQuantity + 0.000001) {
          throw Exception(
            'كمية المرتجع تتجاوز الكمية الأصلية للصنف ${item.productName}',
          );
        }

        final sourceBaseTotal = matching.fold<double>(
          0,
          (sum, dynamic line) => sum + (line.total as num).toDouble(),
        );

        final effectiveUnitPrice = _effectiveUnitPrice(
          lineTotal: sourceBaseTotal,
          lineQuantity: sourceQuantity,
          invoiceSubtotal: sourceSubtotal,
          invoiceDiscount: sourceDiscount,
        );

        total += effectiveUnitPrice * item.quantity;
      }

      if (total <= 0) {
        throw Exception('قيمة المرتجع يجب أن تكون أكبر من صفر');
      }

      final id = await db.returnsDao.insertReturn(
        ReturnsCompanion.insert(
          returnNumber: returnNumber,
          type: type,
          saleId: Value(saleId),
          purchaseId: Value(purchaseId),
          customerId: Value(customerId),
          supplierId: Value(supplierId),
          subtotal: Value(total),
          total: Value(total),
          reason: Value(reason),
          notes: Value(notes),
        ),
      );

      for (final item in items) {
        final product = await db.productsDao.getById(item.productId);
        if (product == null) {
          throw Exception('المنتج غير موجود');
        }

        final matching = sourceItems
            .where((dynamic line) => line.productId == item.productId)
            .toList();

        final sourceQuantity = matching.fold<double>(
          0,
          (sum, dynamic line) => sum + (line.quantity as num).toDouble(),
        );
        final sourceBaseTotal = matching.fold<double>(
          0,
          (sum, dynamic line) => sum + (line.total as num).toDouble(),
        );

        final effectiveUnitPrice = _effectiveUnitPrice(
          lineTotal: sourceBaseTotal,
          lineQuantity: sourceQuantity,
          invoiceSubtotal: sourceSubtotal,
          invoiceDiscount: sourceDiscount,
        );
        final lineTotal = effectiveUnitPrice * item.quantity;

        final newStock = type == 'sale_return'
            ? product.stockQuantity + item.quantity
            : product.stockQuantity - item.quantity;

        if (newStock < 0) {
          throw Exception(
            'لا يمكن إرجاع المشتريات لأن المخزون الحالي لا يكفي',
          );
        }

        await db.productsDao.updateStock(product.id, newStock);

        await db.returnItemsDao.insertItem(
          ReturnItemsCompanion.insert(
            returnId: id,
            productId: item.productId,
            productName: item.productName,
            barcode: item.barcode,
            unitPrice: Value(effectiveUnitPrice),
            quantity: Value(item.quantity),
            total: Value(lineTotal),
          ),
        );

        await db.stockMovementsDao.insertMovement(
          StockMovementsCompanion.insert(
            productId: item.productId,
            type: type,
            quantity: Value(
              type == 'sale_return'
                  ? item.quantity
                  : -item.quantity,
            ),
            balanceAfter: Value(newStock),
            referenceId: Value(id),
            referenceNumber: Value(returnNumber),
            notes: Value('مرتجع $returnNumber'),
          ),
        );
      }

      if (type == 'sale_return' && customerId != null) {
        final allReturns = await _priorReturnTotal(
          type: 'sale_return',
          column: 'sale_id',
          sourceId: saleId!,
        );
        final priorBeforeThis = allReturns - total;
        final originalDebt =
            sale!.remaining < 0 ? 0.0 : sale.remaining;
        final debtBeforeThis =
            (originalDebt - priorBeforeThis)
                .clamp(0.0, double.infinity)
                .toDouble();
        final debtReduction =
            total < debtBeforeThis ? total : debtBeforeThis;

        if (debtReduction > 0) {
          await db.customerTransactionsDao.insertTransaction(
            CustomerTransactionsCompanion.insert(
              customerId: customerId,
              saleId: Value(saleId),
              type: 'sale_return',
              amount: Value(-debtReduction),
              notes: Value(
                'تخفيض ذمة العميل بسبب مرتجع $returnNumber',
              ),
            ),
          );
        }
      }

      if (type == 'purchase_return' && supplierId != null) {
        final allReturns = await _priorReturnTotal(
          type: 'purchase_return',
          column: 'purchase_id',
          sourceId: purchaseId!,
        );
        final priorBeforeThis = allReturns - total;
        final originalPayable =
            purchase!.remaining < 0 ? 0.0 : purchase.remaining;
        final payableBefore =
            (originalPayable - priorBeforeThis)
                .clamp(0.0, double.infinity)
                .toDouble();
        final payableReduction =
            total < payableBefore ? total : payableBefore;

        final supplier =
            await db.suppliersDao.getById(supplierId);
        if (supplier != null) {
          final newBalance =
              supplier.currentBalance - payableReduction;

          await (db.update(db.suppliers)
                ..where((row) => row.id.equals(supplierId)))
              .write(
            SuppliersCompanion(
              currentBalance: Value(
                newBalance < 0 ? 0 : newBalance,
              ),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }

        if (payableReduction > 0) {
          await db.supplierTransactionsDao.insertTransaction(
            SupplierTransactionsCompanion.insert(
              supplierId: supplierId,
              type: 'purchase_return',
              amount: Value(-payableReduction),
              referenceId: Value(id),
              referenceType: const Value('return'),
              notes: Value(
                'تخفيض مستحقات مرتجع $returnNumber',
              ),
            ),
          );
        }
      }

      await AccountingService(db).rebuildInTransaction();
      return id;
    });
  }
}
