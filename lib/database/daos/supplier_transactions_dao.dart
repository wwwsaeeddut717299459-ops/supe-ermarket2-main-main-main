import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/supplier_transactions_table.dart';

part 'supplier_transactions_dao.g.dart';

@DriftAccessor(tables: [SupplierTransactions])
class SupplierTransactionsDao extends DatabaseAccessor<AppDatabase>
    with _$SupplierTransactionsDaoMixin {
  SupplierTransactionsDao(super.db);

  Future<List<SupplierTransaction>> getAll() {
    return (select(supplierTransactions)
          ..orderBy([
            (transaction) => OrderingTerm(
                  expression: transaction.date,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<List<SupplierTransaction>> bySupplier(int supplierId) {
    return (select(supplierTransactions)
          ..where(
            (transaction) =>
                transaction.supplierId.equals(supplierId),
          )
          ..orderBy([
            (transaction) => OrderingTerm(
                  expression: transaction.date,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<int> insertTransaction(
    SupplierTransactionsCompanion transaction,
  ) {
    return into(supplierTransactions).insert(transaction);
  }

  Future<double> getBalanceDelta(int supplierId) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS balance '
      'FROM supplier_transactions WHERE supplier_id = ?',
      variables: [Variable.withInt(supplierId)],
      readsFrom: {supplierTransactions},
    ).getSingle();
    return result.read<double>('balance');
  }
}
