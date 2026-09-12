import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/customer_transactions_table.dart';

part 'customer_transactions_dao.g.dart';

@DriftAccessor(
  tables: [CustomerTransactions],
)
class CustomerTransactionsDao
    extends DatabaseAccessor<AppDatabase>
    with _$CustomerTransactionsDaoMixin {
  CustomerTransactionsDao(super.db);

  Future<List<CustomerTransaction>> getAll() {
    return (select(customerTransactions)
          ..orderBy([
            (transaction) => OrderingTerm(
                  expression: transaction.createdAt,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  // ============================================================
  // GET CUSTOMER TRANSACTIONS
  // ============================================================

  Future<List<CustomerTransaction>>
      getByCustomerId(int customerId) {
    return (select(customerTransactions)
          ..where(
            (transaction) =>
                transaction.customerId
                    .equals(customerId),
          )
          ..orderBy([
            (transaction) =>
                OrderingTerm(
              expression:
                  transaction.createdAt,
              mode: OrderingMode.desc,
            ),
          ]))
        .get();
  }

  // ============================================================
  // GET CUSTOMER DEBT
  // ============================================================

  Future<double> getCustomerDebt(
    int customerId,
  ) async {
    final transactions =
        await getByCustomerId(customerId);

    double debt = 0;

    for (final transaction
        in transactions) {
      switch (transaction.type) {
        case 'credit_sale':
          debt += transaction.amount;
          break;

        case 'payment':
          debt -= transaction.amount;
          break;

        case 'sale_return':
          debt -= transaction.amount;
          break;
      }
    }

    if (debt < 0) {
      return 0;
    }

    return debt;
  }

  // ============================================================
  // GET ALL DEBTS
  // ============================================================

  Future<Map<int, double>>
      getAllCustomerDebts() async {
    final transactions =
        await (select(customerTransactions)
              ..orderBy([
                (transaction) =>
                    OrderingTerm(
                  expression:
                      transaction.createdAt,
                ),
              ]))
            .get();

    final result = <int, double>{};

    for (final transaction
        in transactions) {
      final current =
          result[transaction.customerId] ??
              0;

      switch (transaction.type) {
        case 'credit_sale':
          result[transaction.customerId] =
              current + transaction.amount;
          break;

        case 'payment':
        case 'sale_return':
          result[transaction.customerId] =
              current - transaction.amount;
          break;
      }
    }

    result.removeWhere(
      (_, value) => value <= 0,
    );

    return result;
  }

  // ============================================================
  // ADD TRANSACTION
  // ============================================================

  Future<int> insertTransaction(
    CustomerTransactionsCompanion transaction,
  ) {
    return into(customerTransactions)
        .insert(transaction);
  }

  // ============================================================
  // DELETE
  // ============================================================

  Future<int> deleteTransaction(int id) {
    return (delete(customerTransactions)
          ..where(
            (transaction) =>
                transaction.id.equals(id),
          ))
        .go();
  }
}