import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'purchases_table.dart';
import 'sales_table.dart';
import 'suppliers_table.dart';

class Returns extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get returnNumber => text().unique()();
  TextColumn get type => text().withLength(min: 1, max: 30)();
  IntColumn get saleId => integer().nullable().references(Sales, #id)();
  IntColumn get purchaseId => integer().nullable().references(Purchases, #id)();
  IntColumn get customerId => integer().nullable().references(Customers, #id)();
  IntColumn get supplierId => integer().nullable().references(Suppliers, #id)();
  RealColumn get subtotal => real().withDefault(const Constant(0))();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
  TextColumn get reason => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('completed'))();
  DateTimeColumn get returnDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
