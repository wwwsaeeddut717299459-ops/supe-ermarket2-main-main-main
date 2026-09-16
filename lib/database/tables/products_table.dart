import 'package:drift/drift.dart';

import 'categories_table.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get barcode =>
      text().unique().withLength(min: 1, max: 50)();

  TextColumn get name =>
      text().withLength(min: 1, max: 200)();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id)();

  RealColumn get purchasePrice =>
      real().withDefault(const Constant(0))();

  RealColumn get sellingPrice =>
      real().withDefault(const Constant(0))();

  RealColumn get stockQuantity =>
      real().withDefault(const Constant(0))();

  RealColumn get minimumStock =>
      real().withDefault(const Constant(0))();

  TextColumn get unit =>
      text().withDefault(const Constant('piece'))();

  /// تاريخ انتهاء الصلاحية
  ///
  /// اختياري لأن بعض المنتجات ليس لها تاريخ انتهاء.
  DateTimeColumn get expiryDate =>
      dateTime().nullable()();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}