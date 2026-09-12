import 'package:drift/drift.dart';

class InvoiceSettings extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// اسم المحل
  TextColumn get shopName =>
      text().withLength(min: 1, max: 200)();

  /// عنوان المحل
  TextColumn get address =>
      text().nullable()();

  /// رقم الهاتف
  TextColumn get phone =>
      text().nullable()();

  /// الرقم الضريبي
  TextColumn get taxNumber =>
      text().nullable()();

  /// الرسالة أسفل الفاتورة
  TextColumn get footerMessage =>
      text().nullable()();

  /// حجم الورق:
  /// thermal58
  /// thermal80
  /// a4
  TextColumn get paperSize =>
      text().withDefault(
        const Constant('thermal80'),
      )();

  /// إظهار رقم الفاتورة
  BoolColumn get showInvoiceNumber =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار التاريخ
  BoolColumn get showDate =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار الباركود
  BoolColumn get showBarcode =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار الخصم
  BoolColumn get showDiscount =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار المدفوع
  BoolColumn get showPaid =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار المتبقي
  BoolColumn get showRemaining =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار طريقة الدفع
  BoolColumn get showPaymentMethod =>
      boolean().withDefault(
        const Constant(true),
      )();

  /// إظهار الملاحظات
  BoolColumn get showNotes =>
      boolean().withDefault(
        const Constant(true),
      )();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();
}