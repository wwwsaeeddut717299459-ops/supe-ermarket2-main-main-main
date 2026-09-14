import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/sales_dao.dart';
import '../database/daos/sale_items_dao.dart';
import '../database/daos/products_dao.dart';
import '../services/sale_service.dart';

class SalesRepository {
  final AppDatabase db;
  final SalesDao salesDao;
  final SaleItemsDao saleItemsDao;
  final ProductsDao productsDao;

  late final SaleService _saleService;

  SalesRepository(
    this.db,
    this.salesDao,
    this.saleItemsDao,
    this.productsDao,
  ) {
    _saleService = SaleService(db);
  }

  // ============================================================
  // GET ALL
  // ============================================================

  Future<List<Sale>> getAll() {
    return salesDao.getAll();
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  Future<Sale?> getById(int id) {
    return salesDao.getById(id);
  }

  // ============================================================
  // GET BY INVOICE NUMBER
  // ============================================================

  Future<Sale?> getByInvoiceNumber(
    String invoiceNumber,
  ) {
    return salesDao.getByInvoiceNumber(
      invoiceNumber.trim(),
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<List<Sale>> search(String query) {
    return salesDao.search(query.trim());
  }

  // ============================================================
  // GET SALE ITEMS
  // ============================================================

  Future<List<SaleItem>> getItems(int saleId) {
    return saleItemsDao.getBySaleId(saleId);
  }

  // ============================================================
  // GET SALE ITEMS TOTAL
  // ============================================================

  Future<double> getSaleItemsTotal(int saleId) {
    return saleItemsDao.getSaleTotal(saleId);
  }

  // ============================================================
  // CREATE SALE
  // ============================================================

  Future<int> create({
    String? invoiceNumber,
    required List<SaleItemsCompanion> items,
    double discount = 0,
    double paid = 0,
    String paymentMethod = 'cash',
    int? customerId,
    String? notes,
    String status = 'completed',
  }) async {
    if (items.isEmpty) {
      throw Exception(
        'لا يمكن إنشاء فاتورة بدون منتجات',
      );
    }

    if (discount < 0) {
      throw Exception(
        'قيمة الخصم غير صحيحة',
      );
    }

    if (paid < 0) {
      throw Exception(
        'المبلغ المدفوع غير صحيح',
      );
    }

    // ==========================================================
    // طريقة الدفع
    // ==========================================================

    if (paymentMethod != 'cash' &&
        paymentMethod != 'credit') {
      throw Exception(
        'طريقة الدفع غير صحيحة',
      );
    }

    // ==========================================================
    // البيع النقدي
    // ==========================================================

    if (paymentMethod == 'cash' &&
        customerId != null) {
      throw Exception(
        'لا يمكن ربط العميل بفاتورة نقدية',
      );
    }

    // ==========================================================
    // البيع الآجل
    // ==========================================================

    if (paymentMethod == 'credit' &&
        customerId == null) {
      throw Exception(
        'يجب اختيار العميل عند البيع الآجل',
      );
    }

    // ==========================================================
    // إنشاء الفاتورة عن طريق SaleService
    // ==========================================================

    return _saleService.createSale(
      invoiceNumber: invoiceNumber,
      items: items,
      discount: discount,
      paid: paid,
      paymentMethod: paymentMethod,
      customerId: customerId,
      notes: notes,
    );
  }

  // ============================================================
  // UPDATE SALE HEADER
  // ============================================================

  Future<bool> update({
    required int id,
    required String invoiceNumber,
    double discount = 0,
    double paid = 0,
    String paymentMethod = 'cash',
    String? notes,
    String status = 'completed',
  }) async {
    final oldSale = await salesDao.getById(id);

    if (oldSale == null) {
      throw Exception(
        'الفاتورة غير موجودة',
      );
    }

    final normalizedInvoiceNumber =
        invoiceNumber.trim();

    if (normalizedInvoiceNumber.isEmpty) {
      throw Exception(
        'رقم الفاتورة مطلوب',
      );
    }

    if (discount < 0) {
      throw Exception(
        'قيمة الخصم غير صحيحة',
      );
    }

    if (paid < 0) {
      throw Exception(
        'المبلغ المدفوع غير صحيح',
      );
    }

    if (paymentMethod != 'cash' &&
        paymentMethod != 'credit') {
      throw Exception(
        'طريقة الدفع غير صحيحة',
      );
    }

    final items =
        await saleItemsDao.getBySaleId(id);

    if (items.isEmpty) {
      throw Exception(
        'الفاتورة لا تحتوي على منتجات',
      );
    }

    final subtotal = items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );

    final total = subtotal - discount;

    if (total < 0) {
      throw Exception(
        'قيمة الخصم أكبر من قيمة الفاتورة',
      );
    }

    final remaining = total - paid;

    if (remaining < 0) {
      throw Exception(
        'المبلغ المدفوع أكبر من إجمالي الفاتورة',
      );
    }

    return salesDao.updateSale(
      SalesCompanion(
        id: Value(id),
        invoiceNumber:
            Value(normalizedInvoiceNumber),
        saleDate:
            Value(oldSale.saleDate),
        subtotal:
            Value(subtotal),
        discount:
            Value(discount),
        total:
            Value(total),
        paid:
            Value(paid),
        remaining:
            Value(remaining),
        paymentMethod:
            Value(paymentMethod),
        notes:
            Value(notes),
        status:
            Value(status),
        createdAt:
            Value(oldSale.createdAt),
      ),
    );
  }

  // ============================================================
  // DELETE SALE
  // ============================================================

  Future<void> delete(int id) async {
    final sale =
        await salesDao.getById(id);

    if (sale == null) {
      throw Exception(
        'الفاتورة غير موجودة',
      );
    }

    final items =
        await saleItemsDao.getBySaleId(id);

    await db.transaction(
      () async {
        // ------------------------------------------------------
        // إرجاع المنتجات إلى المخزون
        // ------------------------------------------------------

        for (final item in items) {
          final product =
              await productsDao.getById(
            item.productId,
          );

          if (product == null) {
            continue;
          }

          final newStock =
              product.stockQuantity +
                  item.quantity;

          await productsDao.updateProduct(
            ProductsCompanion(
              id: Value(product.id),
              barcode:
                  Value(product.barcode),
              name:
                  Value(product.name),
              categoryId:
                  product.categoryId == null
                      ? const Value.absent()
                      : Value(product.categoryId),
              purchasePrice:
                  Value(product.purchasePrice),
              sellingPrice:
                  Value(product.sellingPrice),
              stockQuantity:
                  Value(newStock),
              minimumStock:
                  Value(product.minimumStock),
              unit:
                  Value(product.unit),
              isActive:
                  Value(product.isActive),
              createdAt:
                  Value(product.createdAt),
              updatedAt:
                  Value(DateTime.now()),
            ),
          );
        }

        // ------------------------------------------------------
        // حذف عناصر الفاتورة
        // ------------------------------------------------------

        await saleItemsDao.deleteBySaleId(id);

        // ------------------------------------------------------
        // حذف الفاتورة
        // ------------------------------------------------------

        await salesDao.deleteSale(id);
      },
    );
  }

  // ============================================================
  // STATISTICS
  // ============================================================

  Future<double> getTotalSales() {
    return salesDao.getTotalSales();
  }

  Future<double> getTotalPaid() {
    return salesDao.getTotalPaid();
  }

  Future<double> getTotalRemaining() {
    return salesDao.getTotalRemaining();
  }
}