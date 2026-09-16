import 'package:drift/drift.dart';

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// اسم العميل
  TextColumn get name =>
      text().withLength(min: 1, max: 200)();

  /// رقم الهاتف
  TextColumn get phone =>
      text().nullable()();

  /// العنوان
  TextColumn get address =>
      text().nullable()();

  /// ملاحظات
  TextColumn get notes =>
      text().nullable()();

  /// الحد الائتماني للعميل. الصفر يعني بدون سقف.
  RealColumn get creditLimit =>
      real().withDefault(const Constant(0))();

  /// هل العميل نشط؟
  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}
