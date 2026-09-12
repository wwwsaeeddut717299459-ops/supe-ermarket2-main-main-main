import 'package:drift/drift.dart';

import '../database/app_database.dart';

class ValidationIssue {
  final String severity;
  final String code;
  final String message;

  const ValidationIssue({
    required this.severity,
    required this.code,
    required this.message,
  });
}

class ValidationReport {
  final DateTime checkedAt;
  final List<ValidationIssue> issues;

  const ValidationReport({required this.checkedAt, required this.issues});

  bool get passed => issues.where((issue) => issue.severity == 'error').isEmpty;
}

class AutomatedValidationService {
  final AppDatabase db;

  AutomatedValidationService(this.db);

  Future<ValidationReport> run() async {
    final issues = <ValidationIssue>[];
    Future<int> count(
      String sql, {
      Set<TableInfo<Table, dynamic>> readsFrom = const {},
    }) async {
      final row = await db.customSelect(sql, readsFrom: readsFrom).getSingle();
      return row.read<int>('value');
    }

    final negativeStock = await count(
      'SELECT COUNT(*) AS value FROM products WHERE stock_quantity < 0',
      readsFrom: {db.products},
    );
    if (negativeStock > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'negative_stock',
          message: 'توجد منتجات برصيد مخزون سالب',
        ),
      );

    final duplicateBarcodes = await count(
      'SELECT COUNT(*) AS value FROM (SELECT barcode FROM products GROUP BY barcode HAVING COUNT(*) > 1)',
      readsFrom: {db.products},
    );
    if (duplicateBarcodes > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'duplicate_barcodes',
          message: 'توجد باركودات مكررة',
        ),
      );

    final orphanSaleItems = await count(
      'SELECT COUNT(*) AS value FROM sale_items i LEFT JOIN sales s ON s.id = i.sale_id WHERE s.id IS NULL',
      readsFrom: {db.saleItems, db.sales},
    );
    if (orphanSaleItems > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'orphan_sale_items',
          message: 'توجد بنود مبيعات بلا فاتورة',
        ),
      );

    final orphanPurchaseItems = await count(
      'SELECT COUNT(*) AS value FROM purchase_items i LEFT JOIN purchases p ON p.id = i.purchase_id WHERE p.id IS NULL',
      readsFrom: {db.purchaseItems, db.purchases},
    );
    if (orphanPurchaseItems > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'orphan_purchase_items',
          message: 'توجد بنود مشتريات بلا فاتورة',
        ),
      );

    final orphanExpenses = await count(
      'SELECT COUNT(*) AS value FROM expenses e LEFT JOIN expense_categories c ON c.id = e.category_id WHERE c.id IS NULL',
      readsFrom: {db.expenses, db.expenseCategories},
    );
    if (orphanExpenses > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'orphan_expenses',
          message: 'توجد مصروفات بلا تصنيف',
        ),
      );

    final missingAdmin = await count(
      "SELECT COUNT(*) AS value FROM users WHERE username = 'admin'",
      readsFrom: {db.users},
    );
    if (missingAdmin == 0)
      issues.add(
        const ValidationIssue(
          severity: 'warning',
          code: 'missing_admin',
          message: 'لم يتم العثور على مستخدم admin',
        ),
      );

    final unbalancedEntries = await count(
      'SELECT COUNT(*) AS value FROM (SELECT entry_id FROM journal_lines GROUP BY entry_id HAVING ABS(SUM(debit) - SUM(credit)) > 0.01)',
      readsFrom: {db.journalLines},
    );
    if (unbalancedEntries > 0)
      issues.add(
        const ValidationIssue(
          severity: 'error',
          code: 'unbalanced_journals',
          message: 'توجد قيود محاسبية غير متوازنة',
        ),
      );

    final accountCount = await count(
      'SELECT COUNT(*) AS value FROM accounts',
      readsFrom: {db.accounts},
    );
    if (accountCount < 9)
      issues.add(
        const ValidationIssue(
          severity: 'warning',
          code: 'incomplete_chart',
          message: 'دليل الحسابات غير مكتمل؛ شغّل إعادة ترحيل الحسابات',
        ),
      );

    if (issues.isEmpty)
      issues.add(
        const ValidationIssue(
          severity: 'success',
          code: 'passed',
          message: 'اجتازت قاعدة البيانات جميع فحوصات السلامة الحالية',
        ),
      );
    return ValidationReport(checkedAt: DateTime.now(), issues: issues);
  }
}
