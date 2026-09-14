import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/products_table.dart';

part 'products_dao.g.dart';

@DriftAccessor(tables: [Products])
class ProductsDao extends DatabaseAccessor<AppDatabase>
    with _$ProductsDaoMixin {
  ProductsDao(super.db);

  // ============================================================
  // GET ALL
  // ============================================================

  Future<List<Product>> getAll() {
    return (select(products)
          ..orderBy([
            (product) => OrderingTerm(
                  expression: product.name,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<List<Product>> search(String query) {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      return getAll();
    }

    return (select(products)
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
          ]))
        .get();
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