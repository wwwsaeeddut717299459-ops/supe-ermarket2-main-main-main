import 'package:drift/drift.dart';

import 'customers_table.dart';
import 'sales_table.dart';

class CustomerTransactions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// العميل صاحب الحركة
  IntColumn get customerId =>
      integer().references(Customers, #id)();

  /// الفاتورة المرتبطة بالحركة - اختيارية
  IntColumn get saleId =>
      integer().nullable().references(Sales, #id)();

  /// نوع الحركة:
  /// credit_sale  = بيع آجل
  /// payment      = سداد من العميل
  /// sale_return  = مرتجع بيع
  TextColumn get type =>
      text().withLength(min: 1, max: 50)();

  /// قيمة الحركة
  RealColumn get amount =>
      real().withDefault(const Constant(0))();

  /// ملاحظات
  TextColumn get notes =>
      text().nullable()();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();
}