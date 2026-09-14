// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'expense_categories_dao.dart';

// ignore_for_file: type=lint
mixin _$ExpenseCategoriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ExpenseCategoriesTable get expenseCategories =>
      attachedDatabase.expenseCategories;
  ExpenseCategoriesDaoManager get managers => ExpenseCategoriesDaoManager(this);
}

class ExpenseCategoriesDaoManager {
  final _$ExpenseCategoriesDaoMixin _db;
  ExpenseCategoriesDaoManager(this._db);
  $$ExpenseCategoriesTableTableManager get expenseCategories =>
      $$ExpenseCategoriesTableTableManager(
        _db.attachedDatabase,
        _db.expenseCategories,
      );
}
