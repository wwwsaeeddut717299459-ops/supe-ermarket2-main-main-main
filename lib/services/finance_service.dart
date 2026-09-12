import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'accounting_service.dart';

class FinanceSummary {
  final double sales;
  final double saleReturns;
  final double purchases;
  final double cogs;
  final double grossProfit;
  final double expenses;
  final double purchaseReturns;
  final double netProfit;
  final double saleReturnCost;

  const FinanceSummary({
    required this.sales,
    required this.saleReturns,
    required this.purchases,
    required this.cogs,
    required this.grossProfit,
    required this.expenses,
    required this.purchaseReturns,
    required this.netProfit,
    required this.saleReturnCost,
  });
}

class FinanceService {
  final AppDatabase db;

  FinanceService(this.db);

  Future<FinanceSummary> summary(DateTime from, DateTime to) async {
    final salesResult = await db
        .customSelect(
          'SELECT COALESCE(SUM(total), 0) AS value FROM sales WHERE status = ? AND sale_date >= ? AND sale_date < ?',
          variables: [
            Variable.withString('completed'),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {db.sales},
        )
        .getSingle();
    final cogsResult = await db
        .customSelect(
          'SELECT COALESCE(SUM(si.purchase_price_at_sale * si.quantity), 0) AS value FROM sale_items si JOIN sales s ON s.id = si.sale_id WHERE s.status = ? AND s.sale_date >= ? AND s.sale_date < ?',
          variables: [
            Variable.withString('completed'),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {db.saleItems, db.sales},
        )
        .getSingle();
    final expenses = await db.expensesDao.totalBetween(from, to);
    final saleReturnsResult = await db
        .customSelect(
          "SELECT COALESCE(SUM(total), 0) AS value FROM returns WHERE type = 'sale_return' AND status = 'completed' AND return_date >= ? AND return_date < ?",
          variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
          readsFrom: {db.returns},
        )
        .getSingle();
    final sales = salesResult.read<double>('value');
    final saleReturns = saleReturnsResult.read<double>('value');
    final cogs = cogsResult.read<double>('value');
    final saleReturnCost = await _saleReturnCost(from, to);
    final netCogs = (cogs - saleReturnCost).clamp(0.0, double.infinity).toDouble();
    final gross = (sales - saleReturns) - netCogs;
    final purchaseReturns = await _purchaseReturns(from, to);
    final purchases = await _totalPurchases(from, to);
    return FinanceSummary(
      sales: sales,
      saleReturns: saleReturns,
      purchases: purchases,
      cogs: netCogs,
      grossProfit: gross,
      expenses: expenses,
      purchaseReturns: purchaseReturns,
      netProfit: gross - expenses,
      saleReturnCost: saleReturnCost,
    );
  }

  Future<double> _saleReturnCost(DateTime from, DateTime to) async {
    final row = await db.customSelect(
      '''SELECT COALESCE(SUM(ri.quantity * (
        SELECT CASE WHEN COALESCE(SUM(si2.quantity), 0) = 0 THEN 0
          ELSE COALESCE(SUM(si2.purchase_price_at_sale * si2.quantity), 0) / SUM(si2.quantity) END
        FROM sale_items si2
        WHERE si2.sale_id = r.sale_id AND si2.product_id = ri.product_id
      )), 0) AS value
      FROM returns r
      JOIN return_items ri ON ri.return_id = r.id
      WHERE r.type = 'sale_return' AND r.status = 'completed'
        AND r.return_date >= ? AND r.return_date < ?''',
      variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
      readsFrom: {db.returns, db.returnItems, db.saleItems},
    ).getSingle();
    return row.read<double>('value');
  }

  Future<double> _purchaseReturns(DateTime from, DateTime to) async {
    final result = await db
        .customSelect(
          "SELECT COALESCE(SUM(total), 0) AS value FROM returns WHERE type = 'purchase_return' AND status = 'completed' AND return_date >= ? AND return_date < ?",
          variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
          readsFrom: {db.returns},
        )
        .getSingle();
    return result.read<double>('value');
  }

  Future<double> _totalPurchases(DateTime from, DateTime to) async {
    final result = await db
        .customSelect(
          'SELECT COALESCE(SUM(total), 0) AS value FROM purchases WHERE status != ? AND purchase_date >= ? AND purchase_date < ?',
          variables: [
            Variable.withString('cancelled'),
            Variable.withDateTime(from),
            Variable.withDateTime(to),
          ],
          readsFrom: {db.purchases},
        )
        .getSingle();
    return result.read<double>('value');
  }

  Future<double> totalPurchases(DateTime from, DateTime to) async {
    return (await _totalPurchases(from, to)) - await _purchaseReturns(from, to);
  }

  Future<Map<String, double>> expensesByCategory(
    DateTime from,
    DateTime to,
  ) async {
    final rows = await db
        .customSelect(
          'SELECT ec.name AS name, COALESCE(SUM(e.amount), 0) AS value FROM expenses e JOIN expense_categories ec ON ec.id = e.category_id WHERE e.expense_date >= ? AND e.expense_date < ? GROUP BY ec.id, ec.name ORDER BY value DESC',
          variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
          readsFrom: {db.expenses, db.expenseCategories},
        )
        .get();
    return {
      for (final row in rows)
        row.read<String>('name'): row.read<double>('value'),
    };
  }
}

class ExpenseService {
  final AppDatabase db;

  ExpenseService(this.db);

  Future<void> addCategory(String name, String? description) async {
    if (name.trim().isEmpty) throw Exception('اسم التصنيف مطلوب');
    await db.expenseCategoriesDao.insertCategory(
      ExpenseCategoriesCompanion.insert(
        name: name.trim(),
        description: Value(description),
      ),
    );
  }

  Future<void> addExpense({
    required int categoryId,
    required double amount,
    required String paymentMethod,
    required DateTime date,
    String? description,
    String? notes,
  }) async {
    if (amount <= 0) throw Exception('قيمة المصروف يجب أن تكون أكبر من صفر');
    if (!{'cash', 'bank', 'credit'}.contains(paymentMethod)) {
      throw Exception('طريقة دفع المصروف غير صحيحة');
    }

    await db.transaction(() async {
      await db.expensesDao.insertExpense(
        ExpensesCompanion.insert(
          categoryId: categoryId,
          amount: Value(amount),
          paymentMethod: Value(paymentMethod),
          expenseDate: Value(date),
          description: Value(description),
          notes: Value(notes),
        ),
      );

      await AccountingService(db).rebuildInTransaction();
    });
  }

  Future<void> deleteExpense(int id) async {
    await db.transaction(() async {
      final expense = await db.expensesDao.getById(id);
      if (expense == null) throw Exception('المصروف غير موجود');

      await db.expensesDao.deleteExpense(id);
      await AccountingService(db).rebuildInTransaction();
    });
  }
}
