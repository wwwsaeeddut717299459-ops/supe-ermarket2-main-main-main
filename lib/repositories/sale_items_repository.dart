
import '../database/app_database.dart';
import '../database/daos/sale_items_dao.dart';
import 'package:drift/drift.dart';

class SaleItemsRepository {
  final SaleItemsDao dao;

  SaleItemsRepository(this.dao);

  // ============================================================
  // GET ALL
  // ============================================================

  /// جلب جميع عناصر المبيعات
  Future<List<SaleItem>> getAll() {
    return dao.getAll();
  }

  // ============================================================
  // GET BY SALE
  // ============================================================

  /// جلب جميع عناصر فاتورة معينة
  Future<List<SaleItem>> getBySaleId(int saleId) {
    return dao.getBySaleId(saleId);
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  /// جلب عنصر بيع بواسطة المعرف
  Future<SaleItem?> getById(int id) {
    return dao.getById(id);
  }

  // ============================================================
  // GET BY PRODUCT
  // ============================================================

  /// جلب جميع عمليات بيع منتج معين
  Future<List<SaleItem>> getByProductId(int productId) {
    return dao.getByProductId(productId);
  }

  // ============================================================
  // CREATE
  // ============================================================

  /// إضافة عنصر بيع جديد
  Future<int> create({
    required int saleId,
    required int productId,
    required String productName,
    required String barcode,
    double quantity = 1,
    double unitPrice = 0,
    double discount = 0,
  }) {
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    if (unitPrice < 0) {
      throw Exception('سعر الوحدة غير صحيح');
    }

    if (discount < 0) {
      throw Exception('الخصم غير صحيح');
    }

    final itemSubtotal = quantity * unitPrice;

    if (discount > itemSubtotal) {
      throw Exception(
        'خصم العنصر أكبر من قيمة العنصر',
      );
    }

    final total = itemSubtotal - discount;

    return dao.insertSaleItem(
      SaleItemsCompanion.insert(
        saleId: saleId,
        productId: productId,
        productName: productName,
        barcode: barcode,
        quantity: Value(quantity),
        unitPrice: Value(unitPrice),
        discount: Value(discount),
        total: Value(total),
      ),
    );
  }

  // ============================================================
  // UPDATE
  // ============================================================

  /// تحديث عنصر بيع
  Future<bool> update({
    required int id,
    required int saleId,
    required int productId,
    required String productName,
    required String barcode,
    required double quantity,
    required double unitPrice,
    required double discount,
  }) {
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    if (unitPrice < 0) {
      throw Exception('سعر الوحدة غير صحيح');
    }

    if (discount < 0) {
      throw Exception('الخصم غير صحيح');
    }

    final itemSubtotal = quantity * unitPrice;

    if (discount > itemSubtotal) {
      throw Exception(
        'خصم العنصر أكبر من قيمة العنصر',
      );
    }

    final total = itemSubtotal - discount;

    return dao.updateSaleItem(
      SaleItemsCompanion(
        id: Value(id),
        saleId: Value(saleId),
        productId: Value(productId),
        productName: Value(productName),
        barcode: Value(barcode),
        quantity: Value(quantity),
        unitPrice: Value(unitPrice),
        discount: Value(discount),
        total: Value(total),
      ),
    );
  }

  // ============================================================
  // DELETE
  // ============================================================

  /// حذف عنصر بيع
  Future<int> delete(int id) {
    return dao.deleteSaleItem(id);
  }

  // ============================================================
  // DELETE BY SALE
  // ============================================================

  /// حذف جميع عناصر فاتورة معينة
  Future<int> deleteBySaleId(int saleId) {
    return dao.deleteBySaleId(saleId);
  }

  // ============================================================
  // TOTAL
  // ============================================================

  /// حساب إجمالي عناصر فاتورة معينة
  Future<double> getSaleTotal(int saleId) {
    return dao.getSaleTotal(saleId);
  }

  // ============================================================
  // CALCULATE ITEM TOTAL
  // ============================================================

  /// حساب إجمالي عنصر واحد بدون حفظه في قاعدة البيانات
  double calculateTotal({
    required double quantity,
    required double unitPrice,
    double discount = 0,
  }) {
    if (quantity <= 0) {
      throw Exception('الكمية يجب أن تكون أكبر من صفر');
    }

    if (unitPrice < 0) {
      throw Exception('سعر الوحدة غير صحيح');
    }

    if (discount < 0) {
      throw Exception('الخصم غير صحيح');
    }

    final subtotal = quantity * unitPrice;

    if (discount > subtotal) {
      throw Exception(
        'الخصم أكبر من قيمة المنتج',
      );
    }

    return subtotal - discount;
  }
}
