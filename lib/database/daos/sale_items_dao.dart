
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sale_items_table.dart';

part 'sale_items_dao.g.dart';

@DriftAccessor(tables: [SaleItems])
class SaleItemsDao extends DatabaseAccessor<AppDatabase>
    with _$SaleItemsDaoMixin {
  SaleItemsDao(super.db);

  // ============================================================
  // GET ALL
  // ============================================================

  /// جلب جميع عناصر المبيعات
  Future<List<SaleItem>> getAll() {
    return (select(saleItems)
          ..orderBy([
            (item) => OrderingTerm(
                  expression: item.id,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // GET BY SALE ID
  // ============================================================

  /// جلب جميع عناصر فاتورة معينة
  Future<List<SaleItem>> getBySaleId(int saleId) {
    return (select(saleItems)
          ..where(
            (item) => item.saleId.equals(saleId),
          )
          ..orderBy([
            (item) => OrderingTerm(
              expression: item.id,
            ),
          ]))
        .get();
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  /// جلب عنصر بيع محدد
  Future<SaleItem?> getById(int id) {
    return (select(saleItems)
          ..where(
            (item) => item.id.equals(id),
          ))
        .getSingleOrNull();
  }

  // ============================================================
  // GET BY PRODUCT
  // ============================================================

  /// جلب جميع عمليات بيع منتج معين
  Future<List<SaleItem>> getByProductId(int productId) {
    return (select(saleItems)
          ..where(
            (item) => item.productId.equals(productId),
          )
          ..orderBy([
            (item) => OrderingTerm(
                  expression: item.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // INSERT
  // ============================================================

  /// إضافة عنصر إلى الفاتورة
  Future<int> insertSaleItem(
    SaleItemsCompanion item,
  ) {
    return into(saleItems).insert(item);
  }

  // ============================================================
  // UPDATE
  // ============================================================

  /// تحديث عنصر بيع
  Future<bool> updateSaleItem(
    SaleItemsCompanion item,
  ) {
    return update(saleItems).replace(item);
  }

  // ============================================================
  // DELETE
  // ============================================================

  /// حذف عنصر بيع
  Future<int> deleteSaleItem(int id) {
    return (delete(saleItems)
          ..where(
            (item) => item.id.equals(id),
          ))
        .go();
  }

  // ============================================================
  // DELETE BY SALE
  // ============================================================

  /// حذف جميع عناصر فاتورة معينة
  Future<int> deleteBySaleId(int saleId) {
    return (delete(saleItems)
          ..where(
            (item) => item.saleId.equals(saleId),
          ))
        .go();
  }

  // ============================================================
  // TOTAL
  // ============================================================

  /// حساب إجمالي عناصر فاتورة معينة
  Future<double> getSaleTotal(int saleId) async {
    final items = await getBySaleId(saleId);

    return items.fold<double>(
      0,
      (sum, item) => sum + item.total,
    );
  }
}
