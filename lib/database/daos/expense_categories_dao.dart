import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/expense_categories_table.dart';

part 'expense_categories_dao.g.dart';

@DriftAccessor(tables: [ExpenseCategories])
class ExpenseCategoriesDao extends DatabaseAccessor<AppDatabase>
    with _$ExpenseCategoriesDaoMixin {
  ExpenseCategoriesDao(super.db);

  Future<List<ExpenseCategory>> getAll() {
    return (select(expenseCategories)
          ..where((category) => category.isActive.equals(true))
          ..orderBy([
            (category) => OrderingTerm(
                  expression: category.name,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<ExpenseCategory?> getById(int id) {
    return (select(expenseCategories)
          ..where((category) => category.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertCategory(ExpenseCategoriesCompanion category) {
    return into(expenseCategories).insert(category);
  }

  Future<bool> updateCategory(ExpenseCategoriesCompanion category) {
    return update(expenseCategories).replace(category);
  }
}
