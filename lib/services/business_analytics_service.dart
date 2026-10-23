import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'finance_service.dart';

class InvoiceSummaryRow {
  final int id;
  final String type;
  final String invoiceNumber;
  final DateTime date;
  final double total;
  final String status;
  final String paymentMethod;
  final String party;

  const InvoiceSummaryRow({
    required this.id,
    required this.type,
    required this.invoiceNumber,
    required this.date,
    required this.total,
    required this.status,
    required this.paymentMethod,
    required this.party,
  });
}

class ProfitForecast {
  final int historyDays;
  final int forecastDays;
  final double historicalSales;
  final double historicalCost;
  final double historicalProfit;
  final double averageDailySales;
  final double averageDailyProfit;
  final double projectedSales;
  final double projectedProfit;
  final double margin;

  const ProfitForecast({
    required this.historyDays,
    required this.forecastDays,
    required this.historicalSales,
    required this.historicalCost,
    required this.historicalProfit,
    required this.averageDailySales,
    required this.averageDailyProfit,
    required this.projectedSales,
    required this.projectedProfit,
    required this.margin,
  });
}

class InventoryInsight {
  final int productId;
  final String productName;
  final String category;
  final double stock;
  final double soldQuantity;
  final double revenue;
  final double profit;
  final String state;
  final String advice;

  const InventoryInsight({
    required this.productId,
    required this.productName,
    required this.category,
    required this.stock,
    required this.soldQuantity,
    required this.revenue,
    required this.profit,
    required this.state,
    required this.advice,
  });
}

class BusinessAnalyticsService {
  final AppDatabase db;

  BusinessAnalyticsService(this.db);

  Future<List<InvoiceSummaryRow>> invoices({
    required DateTime from,
    required DateTime to,
    String type = 'all',
  }) async {
    final result = <InvoiceSummaryRow>[];
    if (type == 'all' || type == 'sale') {
      final rows = await db
          .customSelect(
            'SELECT s.id, s.invoice_number, s.sale_date, s.total, s.status, s.payment_method, COALESCE(c.name, \'نقدي\') AS party FROM sales s LEFT JOIN customers c ON c.id = s.customer_id WHERE s.sale_date >= ? AND s.sale_date < ? ORDER BY s.sale_date DESC',
            variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
            readsFrom: {db.sales, db.customers},
          )
          .get();
      result.addAll(
        rows.map(
          (row) => InvoiceSummaryRow(
            id: row.read<int>('id'),
            type: 'sale',
            invoiceNumber: row.read<String>('invoice_number'),
            date: row.read<DateTime>('sale_date'),
            total: row.read<double>('total'),
            status: row.read<String>('status'),
            paymentMethod: row.read<String>('payment_method'),
            party: row.read<String>('party'),
          ),
        ),
      );
    }
    if (type == 'all' || type == 'purchase') {
      final rows = await db
          .customSelect(
            'SELECT p.id, p.invoice_number, p.purchase_date, p.total, p.status, p.payment_method, COALESCE(s.name, \'غير محدد\') AS party FROM purchases p LEFT JOIN suppliers s ON s.id = p.supplier_id WHERE p.purchase_date >= ? AND p.purchase_date < ? ORDER BY p.purchase_date DESC',
            variables: [Variable.withDateTime(from), Variable.withDateTime(to)],
            readsFrom: {db.purchases, db.suppliers},
          )
          .get();
      result.addAll(
        rows.map(
          (row) => InvoiceSummaryRow(
            id: row.read<int>('id'),
            type: 'purchase',
            invoiceNumber: row.read<String>('invoice_number'),
            date: row.read<DateTime>('purchase_date'),
            total: row.read<double>('total'),
            status: row.read<String>('status'),
            paymentMethod: row.read<String>('payment_method'),
            party: row.read<String>('party'),
          ),
        ),
      );
    }
    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  Future<ProfitForecast> forecast({
    required int historyDays,
    required int forecastDays,
  }) async {
    if (historyDays <= 0 || forecastDays <= 0) {
      throw Exception('عدد أيام التحليل والتوقع يجب أن يكون أكبر من صفر');
    }
    final to = DateTime.now();
    final from = to.subtract(Duration(days: historyDays));
    final summary = await FinanceService(db).summary(from, to);
    final revenue = summary.sales - summary.saleReturns;
    final cost = summary.cogs;
    final profit = summary.grossProfit;
    final averageSales = revenue / historyDays;
    final averageProfit = profit / historyDays;
    return ProfitForecast(
      historyDays: historyDays,
      forecastDays: forecastDays,
      historicalSales: revenue,
      historicalCost: cost,
      historicalProfit: profit,
      averageDailySales: averageSales,
      averageDailyProfit: averageProfit,
      projectedSales: averageSales * forecastDays,
      projectedProfit: averageProfit * forecastDays,
      margin: revenue == 0 ? 0 : profit / revenue,
    );
  }

  Future<List<InventoryInsight>> inventoryInsights({int days = 90}) async {
    final from = DateTime.now().subtract(Duration(days: days));
    final rows = await db
        .customSelect(
          "SELECT p.id, p.name AS product_name, COALESCE(c.name, 'بدون تصنيف') AS category, p.stock_quantity, COALESCE(SUM(CASE WHEN s.status = 'completed' AND s.sale_date >= ? THEN si.quantity ELSE 0 END), 0) AS sold_quantity, COALESCE(SUM(CASE WHEN s.status = 'completed' AND s.sale_date >= ? THEN (si.total - CASE WHEN COALESCE(s.subtotal, 0) > 0 THEN s.discount * si.total / s.subtotal ELSE 0 END) ELSE 0 END), 0) AS revenue, COALESCE(SUM(CASE WHEN s.status = 'completed' AND s.sale_date >= ? THEN (si.total - CASE WHEN COALESCE(s.subtotal, 0) > 0 THEN s.discount * si.total / s.subtotal ELSE 0 END) - (si.purchase_price_at_sale * si.quantity) ELSE 0 END), 0) AS profit FROM products p LEFT JOIN categories c ON c.id = p.category_id LEFT JOIN sale_items si ON si.product_id = p.id LEFT JOIN sales s ON s.id = si.sale_id GROUP BY p.id, p.name, c.name, p.stock_quantity ORDER BY sold_quantity DESC",
          variables: [
            Variable.withDateTime(from),
            Variable.withDateTime(from),
            Variable.withDateTime(from),
          ],
          readsFrom: {db.products, db.categories, db.saleItems, db.sales},
        )
        .get();
    return rows.map((row) {
      final stock = row.read<double>('stock_quantity');
      final sold = row.read<double>('sold_quantity');
      final profit = row.read<double>('profit');
      final category = row.read<String>('category');
      final state = sold == 0
          ? 'راكد'
          : stock <= 5
          ? 'سريع الحركة'
          : 'مستقر';
      final advice = sold == 0
          ? 'راجع الطلب، نفّذ عرضًا أو أوقف إعادة الشراء مؤقتًا.'
          : profit <= 0
          ? 'راجع سعر البيع وتكلفة الشراء لتحسين الهامش.'
          : stock <= 5
          ? 'اقترب من حد إعادة الطلب؛ راقب التوريد.'
          : 'حافظ على المخزون وراقب معدل البيع.';
      return InventoryInsight(
        productId: row.read<int>('id'),
        productName: row.read<String>('product_name'),
        category: category,
        stock: stock,
        soldQuantity: sold,
        revenue: row.read<double>('revenue'),
        profit: profit,
        state: state,
        advice: advice,
      );
    }).toList();
  }

  Map<String, String> categoryAdvice(List<InventoryInsight> insights) {
    final result = <String, String>{};
    for (final insight in insights) {
      result.putIfAbsent(
        insight.category,
        () => insight.state == 'راكد'
            ? 'ركّز على عروض التصريف وتقليل الشراء.'
            : insight.state == 'سريع الحركة'
            ? 'ارفع حد إعادة الطلب وتابع التوريد.'
            : 'وازن المخزون مع سرعة المبيعات والهامش.',
      );
    }
    return result;
  }
}
