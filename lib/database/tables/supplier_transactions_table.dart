import 'package:drift/drift.dart';

import 'suppliers_table.dart';

class SupplierTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId =>
      integer().references(Suppliers, #id)();

  TextColumn get type =>
      text().withLength(min: 1, max: 50)();

  RealColumn get amount =>
      real().withDefault(const Constant(0))();

  IntColumn get referenceId => integer().nullable()();

  TextColumn get referenceType => text().nullable()();

  DateTimeColumn get date =>
      dateTime().withDefault(currentDateAndTime)();

  TextColumn get notes => text().nullable()();
}
