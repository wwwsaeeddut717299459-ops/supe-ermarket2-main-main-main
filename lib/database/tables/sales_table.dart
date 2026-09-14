import 'package:drift/drift.dart';

import 'customers_table.dart';

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get invoiceNumber =>
      text().unique().withLength(min: 1, max: 50)();

  DateTimeColumn get saleDate =>
      dateTime().withDefault(currentDateAndTime)();

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

  /// طريقة الدفع:
  /// cash   = نقداً
  /// credit = آجل
  TextColumn get paymentMethod =>
      text().withDefault(const Constant('cash'))();

  /// العميل المرتبط بالفاتورة
  /// يكون null في البيع النقدي
  IntColumn get customerId =>
      integer().nullable().references(Customers, #id)();

  TextColumn get notes =>
      text().nullable()();

  TextColumn get status =>
      text().withDefault(const Constant('completed'))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}