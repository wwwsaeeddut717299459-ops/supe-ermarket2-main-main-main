// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stock_movements_dao.dart';

// ignore_for_file: type=lint
mixin _$StockMovementsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $StockMovementsTable get stockMovements => attachedDatabase.stockMovements;
  StockMovementsDaoManager get managers => StockMovementsDaoManager(this);
}

class StockMovementsDaoManager {
  final _$StockMovementsDaoMixin _db;
  StockMovementsDaoManager(this._db);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$StockMovementsTableTableManager get stockMovements =>
      $$StockMovementsTableTableManager(
        _db.attachedDatabase,
        _db.stockMovements,
      );
}
