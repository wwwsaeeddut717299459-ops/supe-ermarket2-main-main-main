import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class PurchaseLineInput {
  final int? productId;
  final String barcode;
  final String productName;
  final double unitPrice;
  final double sellingPrice;
  final double quantity;
  final double discount;

  const PurchaseLineInput({
    this.productId,
    required this.barcode,
    required this.productName,
    required this.unitPrice,
    this.sellingPrice = 0,
    required this.quantity,
    this.discount = 0,
  });
}

class PurchaseService {
  final AppDatabase db;

  PurchaseService(this.db);

  double lineTotal(PurchaseLineInput line) {
    final value = (line.unitPrice * line.quantity) - line.discount;
    return value < 0 ? 0 : value;
  }

  Future<int> createPurchase({
    String? invoiceNumber,
    required List<PurchaseLineInput> items,
    required double discount,
    required double paid,
    required String paymentMethod,
    int? supplierId,
    String? notes,
    DateTime? purchaseDate,
  }) async {
    if (items.isEmpty) throw Exception('يجب إضافة صنف واحد على الأقل');
    if (paymentMethod != 'cash' && paymentMethod != 'credit') {
      throw Exception('طريقة الدفع غير صحيحة');
    }
    if (paymentMethod == 'credit' && supplierId == null) {
      throw Exception('يجب اختيار المورد عند الشراء الآجل');
    }

    return db.transaction(() async {
      final normalizedInvoice = await db.nextInvoiceNumber();

      final existing = await db.purchasesDao.getByInvoiceNumber(
        normalizedInvoice,
      );
      if (existing != null) throw Exception('رقم الفاتورة مستخدم مسبقًا');

      if (supplierId != null) {
        final supplier = await db.suppliersDao.getById(supplierId);
        if (supplier == null || !supplier.isActive) {
          throw Exception('المورد غير موجود أو غير نشط');
        }
      }

      var subtotal = 0.0;
      for (final item in items) {
        if (item.productName.trim().isEmpty)
          throw Exception('اسم المنتج مطلوب');
        if (item.barcode.trim().isEmpty) throw Exception('الباركود مطلوب');
        if (item.quantity <= 0)
          throw Exception('الكمية يجب أن تكون أكبر من صفر');
        if (item.unitPrice < 0) throw Exception('سعر الشراء غير صحيح');
        if (item.sellingPrice < 0) throw Exception('سعر البيع غير صحيح');
        if (item.discount < 0 ||
            item.discount > item.unitPrice * item.quantity) {
          throw Exception('خصم الصنف غير صحيح');
        }
        subtotal += lineTotal(item);
      }
      if (discount < 0 || discount > subtotal)
        throw Exception('خصم الفاتورة غير صحيح');
      final total = subtotal - discount;
      if (paid < 0 || paid > total) throw Exception('المبلغ المدفوع غير صحيح');
      final remaining = total - paid;

      if (paymentMethod == 'cash' && remaining.abs() > 0.01) {
        throw Exception('الشراء النقدي يجب أن يكون مدفوعًا بالكامل');
      }

      final purchaseId = await db.purchasesDao.insertPurchase(
        PurchasesCompanion.insert(
          invoiceNumber: normalizedInvoice,
          purchaseDate: Value(purchaseDate ?? DateTime.now()),
          supplierId: Value(supplierId),
          paymentMethod: Value(paymentMethod),
          subtotal: Value(subtotal),
          discount: Value(discount),
          total: Value(total),
          paid: Value(paid),
          remaining: Value(remaining),
          notes: Value(notes),
        ),
      );

      for (final item in items) {
        Product? product;
        if (item.productId != null) {
          product = await db.productsDao.getById(item.productId!);
        }
        product ??= await db.productsDao.getByBarcode(item.barcode.trim());

        final productId =
            product?.id ??
            await db
                .into(db.products)
                .insert(
                  ProductsCompanion.insert(
                    barcode: item.barcode.trim(),
                    name: item.productName.trim(),
                    purchasePrice: Value(item.unitPrice),
                  ),
                );
        product ??= await db.productsDao.getById(productId);
        if (product == null) throw Exception('تعذر إنشاء المنتج');

        final lineBaseTotal = lineTotal(item);
        final invoiceDiscountShare = subtotal > 0
            ? discount * lineBaseTotal / subtotal
            : 0.0;
        final netLineCost =
            (lineBaseTotal - invoiceDiscountShare).clamp(0.0, double.infinity).toDouble();
        final effectiveUnitCost =
            item.quantity > 0 ? netLineCost / item.quantity : 0.0;

        final newStock = product.stockQuantity + item.quantity;
        await db.productsDao.updateStock(product.id, newStock);
        await (db.update(
          db.products,
        )..where((p) => p.id.equals(product!.id))).write(
          ProductsCompanion(
            purchasePrice: Value(effectiveUnitCost),
            sellingPrice: Value(item.sellingPrice),
            updatedAt: Value(DateTime.now()),
          ),
        );

        await db.purchaseItemsDao.insertItem(
          PurchaseItemsCompanion.insert(
            purchaseId: purchaseId,
            productId: product.id,
            productName: item.productName.trim(),
            barcode: item.barcode.trim(),
            unitPrice: Value(item.unitPrice),
            quantity: Value(item.quantity),
            discount: Value(item.discount),
            total: Value(lineTotal(item)),
          ),
        );
        await db.stockMovementsDao.insertMovement(
          StockMovementsCompanion.insert(
            productId: product.id,
            type: 'purchase',
            quantity: Value(item.quantity),
            balanceAfter: Value(newStock),
            referenceId: Value(purchaseId),
            referenceNumber: Value(normalizedInvoice),
            notes: Value('شراء من الفاتورة $normalizedInvoice'),
          ),
        );
      }

      if (supplierId != null && remaining > 0) {
        final supplier = await db.suppliersDao.getById(supplierId);
        if (supplier != null) {
          await (db.update(
            db.suppliers,
          )..where((s) => s.id.equals(supplierId))).write(
            SuppliersCompanion(
              currentBalance: Value(supplier.currentBalance + remaining),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        await db.supplierTransactionsDao.insertTransaction(
          SupplierTransactionsCompanion.insert(
            supplierId: supplierId,
            type: 'credit_purchase',
            amount: Value(remaining),
            referenceId: Value(purchaseId),
            referenceType: const Value('purchase'),
            notes: Value('مستحقات الفاتورة $normalizedInvoice'),
          ),
        );
      }

      await AccountingService(db).rebuildInTransaction();
      return purchaseId;
    });
  }

  Future<void> cancelPurchase(int purchaseId) async {
    await db.transaction(() async {
      final purchase = await db.purchasesDao.getById(purchaseId);
      if (purchase == null) throw Exception('الفاتورة غير موجودة');
      if (purchase.status == 'cancelled')
        throw Exception('الفاتورة ملغاة مسبقًا');
      final items = await db.purchaseItemsDao.byPurchase(purchaseId);
      for (final item in items) {
        final product = await db.productsDao.getById(item.productId);
        if (product == null || product.stockQuantity < item.quantity) {
          throw Exception('لا يمكن إلغاء الفاتورة بسبب رصيد المخزون الحالي');
        }
        final newStock = product.stockQuantity - item.quantity;
        await db.productsDao.updateStock(product.id, newStock);
        await db.stockMovementsDao.insertMovement(
          StockMovementsCompanion.insert(
            productId: product.id,
            type: 'purchase_return',
            quantity: Value(-item.quantity),
            balanceAfter: Value(newStock),
            referenceId: Value(purchaseId),
            referenceNumber: Value(purchase.invoiceNumber),
            notes: Value('إلغاء فاتورة شراء ${purchase.invoiceNumber}'),
          ),
        );
      }
      if (purchase.supplierId != null && purchase.remaining > 0) {
        final supplier = await db.suppliersDao.getById(purchase.supplierId!);
        if (supplier != null) {
          final balance = supplier.currentBalance - purchase.remaining;
          await (db.update(
            db.suppliers,
          )..where((s) => s.id.equals(supplier.id))).write(
            SuppliersCompanion(
              currentBalance: Value(balance < 0 ? 0 : balance),
              updatedAt: Value(DateTime.now()),
            ),
          );
        }
        await db.supplierTransactionsDao.insertTransaction(
          SupplierTransactionsCompanion.insert(
            supplierId: purchase.supplierId!,
            type: 'purchase_return',
            amount: Value(-purchase.remaining),
            referenceId: Value(purchaseId),
            referenceType: const Value('purchase'),
            notes: Value('عكس مستحقات ${purchase.invoiceNumber}'),
          ),
        );
      }
      await db.purchasesDao.updatePurchase(
        purchase
            .toCompanion(true)
            .copyWith(
              status: const Value('cancelled'),
              updatedAt: Value(DateTime.now()),
            ),
      );

      await AccountingService(db).rebuildInTransaction();
    });
  }
}
