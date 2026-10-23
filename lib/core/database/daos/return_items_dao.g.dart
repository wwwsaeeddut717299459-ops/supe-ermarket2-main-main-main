// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'return_items_dao.dart';

// ignore_for_file: type=lint
mixin _$ReturnItemsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $ReturnsTable get returns => attachedDatabase.returns;
  $CategoriesTable get categories => attachedDatabase.categories;
  $ProductsTable get products => attachedDatabase.products;
  $ReturnItemsTable get returnItems => attachedDatabase.returnItems;
  ReturnItemsDaoManager get managers => ReturnItemsDaoManager(this);
}

class ReturnItemsDaoManager {
  final _$ReturnItemsDaoMixin _db;
  ReturnItemsDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$SuppliersTableTableManager get suppliers =>
      $$SuppliersTableTableManager(_db.attachedDatabase, _db.suppliers);
  $$PurchasesTableTableManager get purchases =>
      $$PurchasesTableTableManager(_db.attachedDatabase, _db.purchases);
  $$ReturnsTableTableManager get returns =>
      $$ReturnsTableTableManager(_db.attachedDatabase, _db.returns);
  $$CategoriesTableTableManager get categories =>
      $$CategoriesTableTableManager(_db.attachedDatabase, _db.categories);
  $$ProductsTableTableManager get products =>
      $$ProductsTableTableManager(_db.attachedDatabase, _db.products);
  $$ReturnItemsTableTableManager get returnItems =>
      $$ReturnItemsTableTableManager(_db.attachedDatabase, _db.returnItems);
}
