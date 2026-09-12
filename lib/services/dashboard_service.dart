import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';
import 'finance_service.dart';

class DashboardMetrics {
  final DateTime from;
  final DateTime to;
  final double salesToday;
  final double purchasesToday;
  final double expensesToday;
  final double profitToday;
  final int productsCount;
  final int customersCount;
  final int suppliersCount;
  final double cashBalance;

  const DashboardMetrics({
    required this.from,
    required this.to,
    required this.salesToday,
    required this.purchasesToday,
    required this.expensesToday,
    required this.profitToday,
    required this.productsCount,
    required this.customersCount,
    required this.suppliersCount,
    required this.cashBalance,
  });
}

class DashboardService {
  final AppDatabase db;

  DashboardService(this.db);

  Future<double> _amount(
    String sql,
    List<Variable<Object>> variables,
    Set<TableInfo<Table, dynamic>> readsFrom,
  ) async {
    final result = await db
        .customSelect(sql, variables: variables, readsFrom: readsFrom)
        .getSingle();
    return result.read<double>('value');
  }

  Future<int> _count(
    String table,
    String where,
    Set<TableInfo<Table, dynamic>> readsFrom,
  ) async {
    final result = await db
        .customSelect(
          'SELECT COUNT(*) AS value FROM $table WHERE $where',
          readsFrom: readsFrom,
        )
        .getSingle();
    return result.read<int>('value');
  }

  Future<DashboardMetrics> load() async {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day);
    final to = from.add(const Duration(days: 1));
    final variables = [Variable.withDateTime(from), Variable.withDateTime(to)];
    final sales = await _amount(
      "SELECT COALESCE(SUM(total), 0) AS value FROM sales WHERE status = 'completed' AND sale_date >= ? AND sale_date < ?",
      variables,
      {db.sales},
    );
    final purchases = await _amount(
      "SELECT COALESCE(SUM(total), 0) AS value FROM purchases WHERE status != 'cancelled' AND purchase_date >= ? AND purchase_date < ?",
      variables,
      {db.purchases},
    );
    final expenses = await _amount(
      'SELECT COALESCE(SUM(amount), 0) AS value FROM expenses WHERE expense_date >= ? AND expense_date < ?',
      variables,
      {db.expenses},
    );
    final finance = await FinanceService(db).summary(from, to);
    final accounting = await AccountingService(db).summary();
    return DashboardMetrics(
      from: from,
      to: to,
      salesToday: sales,
      purchasesToday: purchases,
      expensesToday: expenses,
      profitToday: finance.netProfit,
      productsCount: await _count('products', 'is_active = 1', {db.products}),
      customersCount: await _count('customers', 'is_active = 1', {
        db.customers,
      }),
      suppliersCount: await _count('suppliers', 'is_active = 1', {
        db.suppliers,
      }),
      cashBalance: accounting.cash,
    );
  }
}
