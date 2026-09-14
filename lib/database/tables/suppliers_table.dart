import 'package:drift/drift.dart';

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().withLength(min: 1, max: 150)();

  TextColumn get phone => text().nullable()();

  TextColumn get address => text().nullable()();

  TextColumn get email => text().nullable()();

  TextColumn get notes => text().nullable()();

  RealColumn get openingBalance =>
      real().withDefault(const Constant(0))();

  RealColumn get currentBalance =>
      real().withDefault(const Constant(0))();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
