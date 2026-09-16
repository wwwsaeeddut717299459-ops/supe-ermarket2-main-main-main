import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class SaleService {
  final AppDatabase db;

  SaleService(this.db);

  /// ============================================================
  /// إنشاء عملية بيع كاملة
  ///
  /// العملية كلها داخل Transaction واحدة:
  ///
  /// 1. إنشاء الفاتورة
  /// 2. إضافة عناصر الفاتورة
  /// 3. خصم المخزون
  /// 4. تسجيل حركة المخزون
  /// 5. تسجيل دين العميل إذا كان البيع آجلًا
  ///
  /// إذا حدث خطأ في أي خطوة يتم Rollback للعملية كاملة.
  /// ============================================================

  Future<int> createSale({
    String? invoiceNumber,
    required List<SaleItemsCompanion> items,
    required double discount,
    required double paid,
    required String paymentMethod,
    int? customerId,
    String? notes,
  }) async {
    if (items.isEmpty) {
      throw Exception('لا توجد منتجات في الفاتورة');
    }

    if (paymentMethod != 'cash' && paymentMethod != 'credit') {
      throw Exception('طريقة الدفع غير صحيحة');
    }

    // البيع النقدي لا يحتاج إلى عميل.
    if (paymentMethod == 'cash' && customerId != null) {
      throw Exception('لا يمكن ربط العميل بفاتورة نقدية');
    }

    // البيع الآجل يجب أن يكون مرتبطًا بعميل.
    if (paymentMethod == 'credit' && customerId == null) {
      throw Exception('يجب اختيار العميل عند البيع الآجل');
    }

    return db.transaction(() async {
      // الرقم يُحجز داخل نفس المعاملة لضمان عدم التكرار.
      final generatedInvoiceNumber = await db.nextInvoiceNumber();

      // ==========================================================
      // 1. حساب الإجماليات
      // ==========================================================

      double subtotal = 0;

      for (final item in items) {
        final quantity = item.quantity.value;
        final unitPrice = item.unitPrice.value;
        final itemDiscount = item.discount.value;

        final itemTotal =
            (unitPrice * quantity) - itemDiscount;

        if (quantity <= 0) {
          throw Exception('كمية المنتج يجب أن تكون أكبر من صفر');
        }

        if (unitPrice < 0) {
          throw Exception('سعر المنتج غير صحيح');
        }

        if (itemDiscount < 0) {
          throw Exception('خصم المنتج غير صحيح');
        }

        if (itemTotal < 0) {
          throw Exception('إجمالي أحد المنتجات غير صحيح');
        }

        subtotal += itemTotal;
      }

      if (discount < 0) {
        throw Exception('الخصم غير صحيح');
      }

      if (discount > subtotal) {
        throw Exception('الخصم أكبر من إجمالي الفاتورة');
      }

      final total = subtotal - discount;

      if (paid < 0) {
        throw Exception('المبلغ المدفوع غير صحيح');
      }

      if (paid > total) {
        throw Exception(
          'المبلغ المدفوع أكبر من إجمالي الفاتورة',
        );
      }

      final remaining = total - paid;

      if (paymentMethod == 'cash' && remaining.abs() > 0.01) {
        throw Exception('البيع النقدي يجب أن يكون مدفوعًا بالكامل');
      }

      // ==========================================================
      // 2. التحقق من العميل
      // ==========================================================

      if (customerId != null) {
        final customer = await db.customersDao.getById(
          customerId,
        );

        if (customer == null) {
          throw Exception('العميل غير موجود');
        }

        if (!customer.isActive) {
          throw Exception('العميل غير نشط');
        }

        // التحقق من سقف مديونية العميل قبل إنشاء الفاتورة.
        // الصفر يعني بدون سقف.
        if (paymentMethod == 'credit' &&
            customer.creditLimit > 0 &&
            remaining > 0) {
          final currentDebt = await db.customerTransactionsDao
              .getCustomerDebt(customer.id);
          final newDebt = currentDebt + remaining;

          if (newDebt > customer.creditLimit + 0.01) {
            final available = customer.creditLimit - currentDebt;
            throw Exception(
              'تم تجاوز سقف مديونية العميل "${customer.name}". '
              'السقف: ${customer.creditLimit.toStringAsFixed(2)}، '
              'المتبقي الحالي: ${currentDebt.toStringAsFixed(2)}، '
              'المتاح للبيع الآجل: '
              '${available > 0 ? available.toStringAsFixed(2) : '0.00'}',
            );
          }
        }
      }

      // ==========================================================
      // 3. إنشاء الفاتورة
      // ==========================================================

      final saleId = await db.salesDao.insertSale(
        SalesCompanion.insert(
          invoiceNumber: generatedInvoiceNumber,
          subtotal: Value(subtotal),
          discount: Value(discount),
          total: Value(total),
          paid: Value(paid),
          remaining: Value(remaining),
          paymentMethod: Value(paymentMethod),
          customerId: Value(customerId),
          notes: Value(notes),
          status: const Value('completed'),
        ),
      );

      // ==========================================================
      // 4. إضافة عناصر الفاتورة + خصم المخزون
      // ==========================================================

      for (final item in items) {
        final productId = item.productId.value;
        final quantity = item.quantity.value;

        // --------------------------------------------------------
        // جلب المنتج
        // --------------------------------------------------------

        final product = await db.productsDao.getById(
          productId,
        );

        if (product == null) {
          throw Exception(
            'المنتج رقم $productId غير موجود',
          );
        }

        if (!product.isActive) {
          throw Exception(
            'المنتج "${product.name}" غير نشط',
          );
        }

        // --------------------------------------------------------
        // التحقق من المخزون
        // --------------------------------------------------------

        if (quantity > product.stockQuantity) {
          throw Exception(
            'الكمية المطلوبة من "${product.name}" '
            'أكبر من المخزون المتوفر '
            '(${product.stockQuantity})',
          );
        }

        // --------------------------------------------------------
        // حساب إجمالي العنصر
        // --------------------------------------------------------

        final unitPrice = item.unitPrice.value;
        final itemDiscount = item.discount.value;

        final itemTotal =
            (unitPrice * quantity) - itemDiscount;

        // --------------------------------------------------------
        // إضافة عنصر الفاتورة
        // --------------------------------------------------------

        await db.saleItemsDao.insertSaleItem(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: productId,
            productName: item.productName.value,
            barcode: item.barcode.value,
            quantity: Value(quantity),
            unitPrice: Value(unitPrice),
            purchasePriceAtSale: Value(product.purchasePrice),
            discount: Value(itemDiscount),
            total: Value(itemTotal),
          ),
        );

        // --------------------------------------------------------
        // حساب الرصيد الجديد للمخزون
        // --------------------------------------------------------

        final newStock =
            product.stockQuantity - quantity;

        // --------------------------------------------------------
        // تحديث المخزون
        // --------------------------------------------------------

        

        await db.productsDao.updateStock(
  product.id,
  newStock,
);

        // --------------------------------------------------------
        // تسجيل حركة المخزون
        // --------------------------------------------------------

        await db.stockMovementsDao.insertMovement(
          StockMovementsCompanion.insert(
            productId: product.id,
            type: 'sale',
            quantity: Value(-quantity),
            balanceAfter: Value(newStock),
            referenceNumber: Value(generatedInvoiceNumber),
            referenceId: Value(saleId),
            notes: Value(
              'بيع من الفاتورة $generatedInvoiceNumber',
            ),
          ),
        );
      }

      // ==========================================================
      // 5. تسجيل دين العميل
      // ==========================================================

      if (paymentMethod == 'credit' &&
          customerId != null &&
          remaining > 0) {
        await db.customerTransactionsDao.insertTransaction(
          CustomerTransactionsCompanion.insert(
            customerId: customerId,
            saleId: Value(saleId),
            type: 'credit_sale',
            amount: Value(remaining),
            notes: Value(
              'دين ناتج عن الفاتورة $generatedInvoiceNumber',
            ),
          ),
        );
      }

      await AccountingService(db).rebuildInTransaction();

      return saleId;
    });
  }
}