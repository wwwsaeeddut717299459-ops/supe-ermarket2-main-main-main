
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/stock_movements_table.dart';
import '../tables/products_table.dart';

part 'stock_movements_dao.g.dart';

@DriftAccessor(
  tables: [
    StockMovements,
    Products,
  ],
)
class StockMovementsDao extends DatabaseAccessor<AppDatabase>
    with _$StockMovementsDaoMixin {
  StockMovementsDao(super.db);

  // ============================================================
  // جلب جميع حركات المخزون
  // ============================================================

  Future<List<StockMovement>> getAll() {
    return (select(stockMovements)
          ..orderBy([
            (movement) => OrderingTerm(
                  expression: movement.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // جلب حركات منتج معين
  // ============================================================

  Future<List<StockMovement>> getByProductId(
    int productId,
  ) {
    return (select(stockMovements)
          ..where(
            (movement) =>
                movement.productId.equals(productId),
          )
          ..orderBy([
            (movement) => OrderingTerm(
                  expression: movement.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // جلب حركة بواسطة ID
  // ============================================================

  Future<StockMovement?> getById(int id) {
    return (select(stockMovements)
          ..where(
            (movement) => movement.id.equals(id),
          ))
        .getSingleOrNull();
  }

  // ============================================================
  // جلب الحركات حسب نوع الحركة
  // ============================================================

  Future<List<StockMovement>> getByType(
    String type,
  ) {
    return (select(stockMovements)
          ..where(
            (movement) => movement.type.equals(type),
          )
          ..orderBy([
            (movement) => OrderingTerm(
                  expression: movement.createdAt,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // إضافة حركة مخزون
  // ============================================================

  Future<int> insertMovement(
    StockMovementsCompanion movement,
  ) {
    return into(stockMovements).insert(movement);
  }

  // ============================================================
  // حذف حركة
  // ============================================================

  Future<int> deleteMovement(int id) {
    return (delete(stockMovements)
          ..where(
            (movement) => movement.id.equals(id),
          ))
        .go();
  }

  // ============================================================
  // إجمالي حركة منتج معين
  // ============================================================

  Future<double> getProductMovementTotal(
    int productId,
  ) async {
    final result = await customSelect(
      '''
      SELECT COALESCE(SUM(quantity), 0) AS total
      FROM stock_movements
      WHERE product_id = ?
      ''',
      variables: [
        Variable.withInt(productId),
      ],
      readsFrom: {
        stockMovements,
      },
    ).getSingle();

    return result.read<double>('total');
  }

  // ============================================================
  // آخر حركة للمنتج
  // ============================================================

  Future<StockMovement?> getLastMovement(
    int productId,
  ) {
    return (select(stockMovements)
          ..where(
            (movement) =>
                movement.productId.equals(productId),
          )
          ..orderBy([
            (movement) => OrderingTerm(
                  expression: movement.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }
}
