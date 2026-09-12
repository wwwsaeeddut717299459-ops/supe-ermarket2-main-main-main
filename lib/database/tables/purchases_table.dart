import 'package:drift/drift.dart';

import 'suppliers_table.dart';

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get invoiceNumber =>
      text().unique().withLength(min: 1, max: 50)();

  DateTimeColumn get purchaseDate =>
      dateTime().withDefault(currentDateAndTime)();

  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id)();

  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();

  RealColumn get subtotal =>
      real().withDefault(const Constant(0))();

  RealColumn get discount =>
      real().withDefault(const Constant(0))();

  RealColumn get total =>
      real().withDefault(const Constant(0))();

  RealColumn get paid =>
      real().withDefault(const Constant(0))();

  RealColumn get remaining =>
      real().withDefault(const Constant(0))();

  TextColumn get status =>
      text().withDefault(const Constant('completed'))();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
