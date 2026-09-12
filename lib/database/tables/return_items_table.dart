import 'package:drift/drift.dart';

import 'products_table.dart';
import 'returns_table.dart';

class ReturnItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get returnId => integer().references(Returns, #id)();
  IntColumn get productId => integer().references(Products, #id)();
  TextColumn get productName => text()();
  TextColumn get barcode => text()();
  RealColumn get unitPrice => real().withDefault(const Constant(0))();
  RealColumn get quantity => real().withDefault(const Constant(0))();
  RealColumn get total => real().withDefault(const Constant(0))();
}
