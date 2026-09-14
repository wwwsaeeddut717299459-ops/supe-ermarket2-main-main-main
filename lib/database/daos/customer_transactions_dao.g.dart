// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'customer_transactions_dao.dart';

// ignore_for_file: type=lint
mixin _$CustomerTransactionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $CustomersTable get customers => attachedDatabase.customers;
  $SalesTable get sales => attachedDatabase.sales;
  $CustomerTransactionsTable get customerTransactions =>
      attachedDatabase.customerTransactions;
  CustomerTransactionsDaoManager get managers =>
      CustomerTransactionsDaoManager(this);
}

class CustomerTransactionsDaoManager {
  final _$CustomerTransactionsDaoMixin _db;
  CustomerTransactionsDaoManager(this._db);
  $$CustomersTableTableManager get customers =>
      $$CustomersTableTableManager(_db.attachedDatabase, _db.customers);
  $$SalesTableTableManager get sales =>
      $$SalesTableTableManager(_db.attachedDatabase, _db.sales);
  $$CustomerTransactionsTableTableManager get customerTransactions =>
      $$CustomerTransactionsTableTableManager(
        _db.attachedDatabase,
        _db.customerTransactions,
      );
}
