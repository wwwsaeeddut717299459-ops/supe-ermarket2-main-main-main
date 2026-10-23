
import 'package:drift/drift.dart';

import 'sales_table.dart';
import 'products_table.dart';

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId =>
      integer().references(Sales, #id)();

  IntColumn get productId =>
      integer().references(Products, #id)();

  TextColumn get productName =>
      text().withLength(min: 1, max: 200)();

  TextColumn get barcode =>
      text().withLength(min: 1, max: 50)();

  RealColumn get quantity =>
      real().withDefault(const Constant(1))();

  RealColumn get unitPrice =>
      real().withDefault(const Constant(0))();

  /// تكلفة الشراء وقت البيع، ولا تعتمد على السعر الحالي للمنتج.
  RealColumn get purchasePriceAtSale =>
      real().withDefault(const Constant(0))();

  RealColumn get discount =>
      real().withDefault(const Constant(0))();

  RealColumn get total =>
      real().withDefault(const Constant(0))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}
