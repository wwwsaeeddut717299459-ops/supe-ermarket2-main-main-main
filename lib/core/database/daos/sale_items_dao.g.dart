// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sale_items_dao.dart';

// ignore_for_file: type=lint
mixin _$SaleItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $SaleItemsTable get saleItems => attachedDatabase.saleItems;
  SaleItemsDaoManager get managers => SaleItemsDaoManager(this);
}

class SaleItemsDaoManager {
  final _$SaleItemsDaoMixin _db;
  SaleItemsDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$SaleItemsTableTableManager get saleItems =>
      $$SaleItemsTableTableManager(_db.attachedDatabase, _db.saleItems);
}
