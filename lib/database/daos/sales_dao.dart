
import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/sales_table.dart';

part 'sales_dao.g.dart';

@DriftAccessor(tables: [Sales])
class SalesDao extends DatabaseAccessor<AppDatabase>
    with _$SalesDaoMixin {
  SalesDao(super.db);

  /// جلب جميع الفواتير
  Future<List<Sale>> getAll() {
    return (select(sales)
          ..orderBy([
            (sale) => OrderingTerm(
                  expression: sale.saleDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// جلب فاتورة بواسطة الرقم
  Future<Sale?> getById(int id) {
    return (select(sales)
          ..where(
            (sale) => sale.id.equals(id),
          ))
        .getSingleOrNull();
  }

  /// البحث برقم الفاتورة
  Future<Sale?> getByInvoiceNumber(
    String invoiceNumber,
  ) {
    final normalized = invoiceNumber.trim();

    if (normalized.isEmpty) {
      return Future.value(null);
    }

    return (select(sales)
          ..where(
            (sale) =>
                sale.invoiceNumber.equals(normalized),
          ))
        .getSingleOrNull();
  }

  /// البحث في الفواتير
  Future<List<Sale>> search(String query) {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      return getAll();
    }

    return (select(sales)
          ..where(
            (sale) =>
                sale.invoiceNumber.like(
                  '%$normalized%',
                ) |
                sale.paymentMethod.like(
                  '%$normalized%',
                ) |
                sale.status.like(
                  '%$normalized%',
                ),
          )
          ..orderBy([
            (sale) => OrderingTerm(
                  expression: sale.saleDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// إضافة فاتورة
  Future<int> insertSale(
    SalesCompanion sale,
  ) {
    return into(sales).insert(sale);
  }

  /// تحديث فاتورة
  Future<bool> updateSale(
    SalesCompanion sale,
  ) {
    return update(sales).replace(sale);
  }

  /// حذف فاتورة
  Future<int> deleteSale(int id) {
    return (delete(sales)
          ..where(
            (sale) => sale.id.equals(id),
          ))
        .go();
  }

  /// الفواتير المكتملة
  Future<List<Sale>> getCompletedSales() {
    return (select(sales)
          ..where(
            (sale) => sale.status.equals('completed'),
          )
          ..orderBy([
            (sale) => OrderingTerm(
                  expression: sale.saleDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// الفواتير المعلقة
  Future<List<Sale>> getPendingSales() {
    return (select(sales)
          ..where(
            (sale) => sale.status.equals('pending'),
          )
          ..orderBy([
            (sale) => OrderingTerm(
                  expression: sale.saleDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  /// إجمالي المبيعات
  Future<double> getTotalSales() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(total), 0) AS total '
      'FROM sales '
      'WHERE status = ?',
      variables: [
        Variable.withString('completed'),
      ],
      readsFrom: {sales},
    ).getSingle();

    return result.read<double>('total');
  }

  /// إجمالي المبالغ المدفوعة
  Future<double> getTotalPaid() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(paid), 0) AS paid '
      'FROM sales '
      'WHERE status = ?',
      variables: [
        Variable.withString('completed'),
      ],
      readsFrom: {sales},
    ).getSingle();

    return result.read<double>('paid');
  }

  /// إجمالي المبالغ المتبقية
  Future<double> getTotalRemaining() async {
    final result = await customSelect(
      'SELECT COALESCE(SUM(remaining), 0) AS remaining '
      'FROM sales '
      'WHERE status = ?',
      variables: [
        Variable.withString('completed'),
      ],
      readsFrom: {sales},
    ).getSingle();

    return result.read<double>('remaining');
  }
}

