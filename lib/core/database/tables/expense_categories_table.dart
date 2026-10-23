import 'package:drift/drift.dart';

class ExpenseCategories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 150)();

  TextColumn get description => text().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();
}
