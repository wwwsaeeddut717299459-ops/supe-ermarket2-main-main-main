import 'package:drift/drift.dart';

import 'expense_categories_table.dart';

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get categoryId =>
      integer().references(ExpenseCategories, #id)();

  RealColumn get amount =>
      real().withDefault(const Constant(0))();

  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();

  DateTimeColumn get expenseDate =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get description => text().nullable()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
