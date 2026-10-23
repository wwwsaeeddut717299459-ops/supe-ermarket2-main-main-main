import 'package:drift/drift.dart';

import '../database/app_database.dart';

class InventoryAuditItem {
  final DateTime date;
  final String type;
  final String reference;
  final String party;
  final double amount;
  final String details;

  const InventoryAuditItem({
    required this.date,
    required this.type,
    required this.reference,
    required this.party,
    required this.amount,
    required this.details,
  });
}

class InventoryAuditReport {
  final DateTime from;
  final DateTime to;
  final List<InventoryAuditItem> items;
  final Map<String, double> totals;

  const InventoryAuditReport({
    required this.from,
    required this.to,
    required this.items,
    required this.totals,
  });

  int get count => items.length;
}

/// جرد آلي شامل: يجمع كل الحركات التجارية والمالية والمخزنية خلال الفترة.
class AutomaticInventoryService {
  final AppDatabase db;

  const AutomaticInventoryService(this.db);

  Future<InventoryAuditReport> build({
    required DateTime from,
    required DateTime to,
  }) async {
    final end = DateTime(to.year, to.month, to.day).add(const Duration(days: 1));
    final items = <InventoryAuditItem>[];
    final totals = <String, double>{
      'sales': 0,
      'purchases': 0,
      'saleReturns': 0,
      'purchaseReturns': 0,
      'expenses': 0,
      'customerPayments': 0,
      'supplierPayments': 0,
      'employeePayments': 0,
      'stockIn': 0,
      'stockOut': 0,
    };

    final sales = await (db.select(db.sales)
          ..where((t) => t.saleDate.isBiggerOrEqualValue(from) & t.saleDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.saleDate)]))
        .get();
    for (final s in sales) {
      totals['sales'] = totals['sales']! + s.total;
      final rows = await (db.select(db.saleItems)..where((t) => t.saleId.equals(s.id))).get();
      final details = rows.map((x) => '${x.productName} × ${x.quantity} بسعر ${x.unitPrice} = ${x.total}').join(' | ');
      items.add(InventoryAuditItem(
        date: s.saleDate,
        type: s.paymentMethod == 'credit' || s.remaining > 0 ? 'بيع آجل' : 'بيع نقدي',
        reference: s.invoiceNumber,
        party: s.customerId == null ? 'عميل نقدي' : 'عميل #${s.customerId}',
        amount: s.total,
        details: 'الإجمالي ${s.total} • المدفوع ${s.paid} • المتبقي ${s.remaining}' + (details.isEmpty ? '' : ' • الأصناف: $details'),
      ));
    }

    final purchases = await (db.select(db.purchases)
          ..where((t) => t.purchaseDate.isBiggerOrEqualValue(from) & t.purchaseDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.purchaseDate)]))
        .get();
    for (final p in purchases) {
      totals['purchases'] = totals['purchases']! + p.total;
      final rows = await (db.select(db.purchaseItems)..where((t) => t.purchaseId.equals(p.id))).get();
      final details = rows.map((x) => '${x.productName} × ${x.quantity} بسعر ${x.unitPrice} = ${x.total}').join(' | ');
      items.add(InventoryAuditItem(
        date: p.purchaseDate,
        type: p.paymentMethod == 'credit' || p.remaining > 0 ? 'شراء آجل' : 'شراء نقدي',
        reference: p.invoiceNumber,
        party: p.supplierId == null ? 'مورد غير محدد' : 'مورد #${p.supplierId}',
        amount: p.total,
        details: 'الإجمالي ${p.total} • المدفوع ${p.paid} • المتبقي ${p.remaining}' + (details.isEmpty ? '' : ' • الأصناف: $details'),
      ));
    }

    final returns = await (db.select(db.returns)
          ..where((t) => t.returnDate.isBiggerOrEqualValue(from) & t.returnDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.returnDate)]))
        .get();
    for (final r in returns) {
      final saleReturn = r.type == 'sale_return';
      final key = saleReturn ? 'saleReturns' : 'purchaseReturns';
      totals[key] = totals[key]! + r.total;
      final rows = await (db.select(db.returnItems)..where((t) => t.returnId.equals(r.id))).get();
      final details = rows.map((x) => '${x.productName} × ${x.quantity} = ${x.total}').join(' | ');
      items.add(InventoryAuditItem(
        date: r.returnDate,
        type: saleReturn ? 'مرتجع مبيعات' : 'مرتجع مشتريات',
        reference: r.returnNumber,
        party: saleReturn ? 'عميل #${r.customerId ?? '-'}' : 'مورد #${r.supplierId ?? '-'}',
        amount: r.total,
        details: 'السبب: ${r.reason ?? '-'}' + (details.isEmpty ? '' : ' • الأصناف: $details'),
      ));
    }

    final expenses = await (db.select(db.expenses)
          ..where((t) => t.expenseDate.isBiggerOrEqualValue(from) & t.expenseDate.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.expenseDate)]))
        .get();
    for (final e in expenses) {
      totals['expenses'] = totals['expenses']! + e.amount;
      items.add(InventoryAuditItem(
        date: e.expenseDate,
        type: 'مصروف',
        reference: 'مصروف #${e.id}',
        party: 'تصنيف #${e.categoryId}',
        amount: e.amount,
        details: [e.description, e.notes, 'طريقة الدفع: ${e.paymentMethod}'].whereType<String>().where((x) => x.trim().isNotEmpty).join(' • '),
      ));
    }

    final customerTransactions = await (db.select(db.customerTransactions)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(from) & t.createdAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    for (final x in customerTransactions) {
      if (x.type == 'payment') totals['customerPayments'] = totals['customerPayments']! + x.amount;
      items.add(InventoryAuditItem(
        date: x.createdAt,
        type: x.type == 'payment' ? 'سداد عميل' : 'حركة عميل',
        reference: x.saleId == null ? 'حركة عميل #${x.id}' : 'فاتورة بيع #${x.saleId}',
        party: 'عميل #${x.customerId}',
        amount: x.amount,
        details: x.notes ?? 'نوع الحركة: ${x.type}',
      ));
    }

    final supplierTransactions = await (db.select(db.supplierTransactions)
          ..where((t) => t.date.isBiggerOrEqualValue(from) & t.date.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.date)]))
        .get();
    for (final x in supplierTransactions) {
      if (x.type == 'payment') totals['supplierPayments'] = totals['supplierPayments']! + x.amount;
      items.add(InventoryAuditItem(
        date: x.date,
        type: x.type == 'payment' ? 'سداد مورد' : 'حركة مورد',
        reference: 'حركة مورد #${x.id}',
        party: 'مورد #${x.supplierId}',
        amount: x.amount,
        details: [x.referenceType, x.referenceId?.toString(), x.notes].whereType<String>().where((x) => x.trim().isNotEmpty).join(' • '),
      ));
    }

    final stock = await (db.select(db.stockMovements)
          ..where((t) => t.createdAt.isBiggerOrEqualValue(from) & t.createdAt.isSmallerThanValue(end))
          ..orderBy([(t) => OrderingTerm(expression: t.createdAt)]))
        .get();
    for (final x in stock) {
      if (x.quantity >= 0) {
        totals['stockIn'] = totals['stockIn']! + x.quantity;
      } else {
        totals['stockOut'] = totals['stockOut']! + x.quantity.abs();
      }
      items.add(InventoryAuditItem(
        date: x.createdAt,
        type: 'حركة مخزون • ${_stockType(x.type)}',
        reference: x.referenceNumber ?? 'حركة مخزون #${x.id}',
        party: 'منتج #${x.productId}',
        amount: x.quantity,
        details: 'الكمية: ${x.quantity} • الرصيد بعد الحركة: ${x.balanceAfter}' + (x.notes == null ? '' : ' • ${x.notes}'),
      ));
    }

    // معاملات الموظفين موجودة كجداول محلية مخصصة في قاعدة البيانات.
    try {
      final employeeRows = await db.customSelect('''
        SELECT et.*, e.name AS employee_name
        FROM employee_transactions et
        LEFT JOIN employees e ON e.id = et.employee_id
        WHERE datetime(et.transaction_date) >= datetime(?)
          AND datetime(et.transaction_date) < datetime(?)
        ORDER BY datetime(et.transaction_date)
      ''', variables: [Variable.withDateTime(from), Variable.withDateTime(end)]).get();
      for (final x in employeeRows) {
        final amount = x.read<double>('amount');
        totals['employeePayments'] = totals['employeePayments']! + amount;
        final dateText = x.read<String>('transaction_date');
        items.add(InventoryAuditItem(
          date: DateTime.tryParse(dateText) ?? from,
          type: 'موظف • ${_employeeType(x.read<String>('type'))}',
          reference: 'حركة موظف #${x.read<int>('id')}',
          party: x.read<String?>('employee_name') ?? 'موظف',
          amount: amount,
          details: x.read<String?>('description') ?? x.read<String?>('notes') ?? 'حركة مالية للموظف',
        ));
      }
    } catch (_) {
      // عدم وجود جداول الموظفين في قاعدة قديمة لا يمنع الجرد.
    }

    // القيود المحاسبية المنشورة خلال الفترة، مع تفاصيل المدين والدائن والحسابات.
    final journalRows = await db.customSelect('''
      SELECT je.id, je.entry_number, je.entry_date, je.description,
             jl.debit, jl.credit, a.code AS account_code, a.name AS account_name,
             jl.memo
      FROM journal_entries je
      JOIN journal_lines jl ON jl.entry_id = je.id
      JOIN accounts a ON a.id = jl.account_id
      WHERE datetime(je.entry_date) >= datetime(?)
        AND datetime(je.entry_date) < datetime(?)
      ORDER BY datetime(je.entry_date)
    ''', variables: [Variable.withDateTime(from), Variable.withDateTime(end)]).get();
    final grouped = <int, List<QueryRow>>{};
    for (final row in journalRows) {
      grouped.putIfAbsent(row.read<int>('id'), () => []).add(row);
    }
    for (final entry in grouped.entries) {
      final first = entry.value.first;
      final date = first.read<DateTime>('entry_date');
      final lines = entry.value.map((x) =>
          '${x.read<String>('account_code')} ${x.read<String>('account_name')}: مدين ${x.read<double>('debit')} / دائن ${x.read<double>('credit')}'
          '${(x.read<String?>('memo') ?? '').trim().isEmpty ? '' : ' • ${x.read<String>('memo')}'}').join(' | ');
      items.add(InventoryAuditItem(
        date: date,
        type: 'قيد محاسبي',
        reference: first.read<String>('entry_number'),
        party: 'القيد #${entry.key}',
        amount: entry.value.fold<double>(0, (sum, x) => sum + x.read<double>('debit')),
        details: '${first.read<String>('description')} • $lines',
      ));
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return InventoryAuditReport(from: from, to: to, items: items, totals: totals);
  }

  static String _stockType(String value) => switch (value) {
    'purchase' => 'شراء',
    'sale' => 'بيع',
    'sale_return' => 'مرتجع بيع',
    'purchase_return' => 'مرتجع شراء',
    'adjustment' => 'تسوية / جرد',
    'opening' => 'رصيد افتتاحي',
    _ => value,
  };

  static String _employeeType(String value) => switch (value) {
    'salary' => 'راتب',
    'advance' => 'سلفة',
    'withdrawal' => 'سحب',
    'payment' => 'صرف',
    _ => 'حركة',
  };
}
