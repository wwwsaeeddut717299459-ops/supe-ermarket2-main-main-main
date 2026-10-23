import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/expenses_table.dart';

part 'expenses_dao.g.dart';

@DriftAccessor(tables: [Expenses])
class ExpensesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpensesDaoMixin {
  ExpensesDao(super.db);

  Future<List<Expense>> getAll() {
    return (select(expenses)
          ..orderBy([
            (expense) => OrderingTerm(
                  expression: expense.expenseDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<Expense?> getById(int id) {
    return (select(expenses)
          ..where((expense) => expense.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Expense>> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return getAll();

    return (select(expenses)
          ..where(
            (expense) =>
                expense.description.like('%$normalized%') |
                expense.paymentMethod.like('%$normalized%') |
                expense.notes.like('%$normalized%'),
          )
          ..orderBy([
            (expense) => OrderingTerm(
                  expression: expense.expenseDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<int> insertExpense(ExpensesCompanion expense) {
    return into(expenses).insert(expense);
  }

  Future<bool> updateExpense(ExpensesCompanion expense) {
    return update(expenses).replace(expense);
  }

  Future<int> deleteExpense(int id) {
    return (delete(expenses)..where((expense) => expense.id.equals(id))).go();
  }

  Future<double> totalBetween(DateTime from, DateTime to) async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(amount), 0) AS total '
      'FROM expenses WHERE expense_date >= ? AND expense_date < ?',
      variables: [
        Variable.withDateTime(from),
        Variable.withDateTime(to),
      ],
      readsFrom: {expenses},
    ).getSingle();
    return result.read<double>('total');
  }
}
