// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'returns_dao.dart';

// ignore_for_file: type=lint
mixin _$ReturnsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $SuppliersTable get suppliers => attachedDatabase.suppliers;
  $PurchasesTable get purchases => attachedDatabase.purchases;
  $ReturnsTable get returns => attachedDatabase.returns;
  ReturnsDaoManager get managers => ReturnsDaoManager(this);
}

class ReturnsDaoManager {
  final _$ReturnsDaoMixin _db;
  ReturnsDaoManager(this._db);
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
}
