import 'package:drift/drift.dart';

import 'package:almajed_pro/core/database/app_database.dart';
import 'package:almajed_pro/core/database/tables/products_table.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // ============================================================
  // GET ALL
  // ============================================================

  /// لا تُرجع عشرات/مئات الآلاف من الصفوف إلى واجهة Flutter.
  /// القوائم الكبيرة يجب أن تُعرض على صفحات.
  Future<List<Product>> getAll({int limit = 200}) {
    return (select(products)
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.name,
                  mode: OrderingMode.asc,
                ),
          ])
          ..limit(limit))
        .get();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  /// بحث سريع ومحدود النتائج.
  ///
  /// يبدأ ببحث prefix حتى يستطيع SQLite الاستفادة من فهرس الاسم،
  /// ثم يرجع إلى contains عند الحاجة مع حد أقصى ثابت.
  /// هذا يمنع إغراق الذاكرة بآلاف النتائج عند كل حرف.
  Future<List<Product>> search(String query, {int limit = 100}) async {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      return getAll(limit: limit);
    }

    final prefixRows = await (select(products)
          ..where(
            (product) =>
                product.barcode.equals(normalized) |
                product.name.like('$normalized%'),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.name,
                  mode: OrderingMode.asc,
                ),
          ])
          ..limit(limit))
        .get();

    if (prefixRows.length >= limit) {
      return prefixRows;
    }

    // الحفاظ على البحث الجزئي الموجود سابقًا، لكن بحد أقصى.
    final containsRows = await (select(products)
          ..where(
            (product) =>
                product.name.like('%$normalized%') |
                product.barcode.like('%$normalized%'),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.name,
                  mode: OrderingMode.asc,
                ),
          ])
          ..limit(limit))
        .get();

    final seen = <int>{};
    final result = <Product>[];
    for (final row in [...prefixRows, ...containsRows]) {
      if (seen.add(row.id)) {
        result.add(row);
        if (result.length >= limit) break;
      }
    }
    return result;
  }

  // ============================================================
  // GET BY ID
  // ============================================================

  Future<Product?> getById(int id) {
    return (select(products)
          ..where(
            (product) => product.id.equals(id),
          ))
        .getSingleOrNull();
  }

  // ============================================================
  // GET BY BARCODE
  // ============================================================

  Future<Product?> getByBarcode(String barcode) async {
    final normalized = barcode.trim();

    if (normalized.isEmpty) {
      return null;
    }

    return (select(products)
          ..where(
            (product) =>
                product.barcode.equals(normalized),
          ))
        .getSingleOrNull();
  }

  // ============================================================
  // INSERT
  // ============================================================

  Future<int> insertProduct(
    ProductsCompanion product,
  ) {
    return into(products).insert(product);
  }

  // ============================================================
  // UPDATE
  // ============================================================

  Future<bool> updateProduct(
    ProductsCompanion product,
  ) {
    return update(products).replace(product);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> deleteProduct(int id) {
    return (delete(products)
          ..where(
            (product) => product.id.equals(id),
          ))
        .go();
  }

  // ============================================================
  // LOW STOCK
  // ============================================================

  Future<List<Product>> getLowStockProducts() {
    return (select(products)
          ..where(
            (product) =>
                product.stockQuantity.isSmallerOrEqual(
              product.minimumStock,
            ),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.stockQuantity,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // EXPIRING SOON
  // ============================================================

  Future<List<Product>> getExpiringProducts({
    int days = 30,
  }) {
    final now = DateTime.now();

    final endDate = now.add(
      Duration(days: days),
    );

    final nowExpression =
        Variable<DateTime>(now);

    final endDateExpression =
        Variable<DateTime>(endDate);

    return (select(products)
          ..where(
            (product) =>
                product.expiryDate.isNotNull() &
                product.expiryDate.isBiggerOrEqual(
                  nowExpression,
                ) &
                product.expiryDate.isSmallerOrEqual(
                  endDateExpression,
                ),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.expiryDate,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // EXPIRED
  // ============================================================

  Future<List<Product>> getExpiredProducts() {
    final now = DateTime.now();

    final nowExpression =
        Variable<DateTime>(now);

    return (select(products)
          ..where(
            (product) =>
                product.expiryDate.isNotNull() &
                product.expiryDate.isSmallerThan(
                  nowExpression,
                ),
          )
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.expiryDate,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // UPDATE STOCK
  // ============================================================

  Future<void> updateStock(
    int productId,
    double newQuantity,
  ) async {
    await (update(products)
          ..where(
            (product) =>
                product.id.equals(productId),
          ))
        .write(
      ProductsCompanion(
        stockQuantity: Value(newQuantity),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}