import 'package:drift/drift.dart';

import 'products_table.dart';
import 'purchases_table.dart';

class PurchaseItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get purchaseId =>
      integer().references(Purchases, #id)();

  IntColumn get productId =>
      integer().references(Products, #id)();

  TextColumn get productName => text()();

  TextColumn get barcode => text()();

  RealColumn get unitPrice =>
      real().withDefault(const Constant(0))();

  RealColumn get quantity =>
      real().withDefault(const Constant(0))();

  RealColumn get discount =>
      real().withDefault(const Constant(0))();

  RealColumn get total =>
      real().withDefault(const Constant(0))();
}
