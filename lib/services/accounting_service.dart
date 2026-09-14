import 'package:drift/drift.dart';

import '../database/app_database.dart';

class AccountingSummary {
  final double totalDebits;
  final double totalCredits;
  final double cash;
  final double bank;
  final double receivables;
  final double payables;
  final double inventory;
  final double revenue;
  final double salesReturns;
  final double costOfGoodsSold;
  final double expenses;
  final double inventoryAdjustmentGain;
  final double inventoryAdjustmentLoss;

  const AccountingSummary({
    required this.totalDebits,
    required this.totalCredits,
    required this.cash,
    required this.bank,
    required this.receivables,
    required this.payables,
    required this.inventory,
    required this.revenue,
    required this.salesReturns,
    required this.costOfGoodsSold,
    required this.expenses,
    required this.inventoryAdjustmentGain,
    required this.inventoryAdjustmentLoss,
  });

  bool get balanced => (totalDebits - totalCredits).abs() < 0.01;
  double get difference => totalDebits - totalCredits;
  double get grossProfit =>
      revenue - salesReturns - costOfGoodsSold;
  double get netProfit =>
      grossProfit - expenses +
      inventoryAdjustmentGain -
      inventoryAdjustmentLoss;
}

class AccountingDashboardData {
  final AccountingSummary summary;
  final List<Account> accounts;
  final List<JournalEntry> entries;
  final Map<int, double> rawBalances;

  const AccountingDashboardData({
    required this.summary,
    required this.accounts,
    required this.entries,
    required this.rawBalances,
  });
}

class AccountingService {
  final AppDatabase db;

  AccountingService(this.db);

  static const definitions = [
    ('1000', 'الصندوق', 'asset'),
    ('1010', 'الحساب البنكي', 'asset'),
    ('1100', 'ذمم العملاء', 'asset'),
    ('1200', 'المخزون', 'asset'),
    ('2000', 'ذمم الموردين', 'liability'),
    ('2100', 'مصروفات مستحقة', 'liability'),
    ('3000', 'رأس المال', 'equity'),
    ('4000', 'إيرادات المبيعات', 'revenue'),
    ('4010', 'مردودات المبيعات', 'revenue'),
    ('5000', 'تكلفة البضاعة المباعة', 'expense'),
    ('5100', 'المصروفات التشغيلية', 'expense'),
    ('5200', 'أرباح فروقات المخزون', 'revenue'),
    ('5201', 'خسائر فروقات المخزون', 'expense'),
  ];

  Future<void> ensureChart() async {
    for (final definition in definitions) {
      final existing = await db.accountsDao.byCode(definition.$1);
      if (existing == null) {
        await db.accountsDao.insertAccount(
          AccountsCompanion.insert(
            code: definition.$1,
            name: definition.$2,
            type: definition.$3,
          ),
        );
      }
    }
  }

  Future<int> _account(String code) async {
    final account = await db.accountsDao.byCode(code);
    if (account == null) {
      throw Exception('الحساب $code غير موجود في دليل الحسابات');
    }
    return account.id;
  }

  Future<void> _post({
    required String sourceType,
    required int sourceId,
    required String description,
    required DateTime date,
    required List<(String code, double debit, double credit)> lines,
  }) async {
    final meaningful = lines
        .where((line) => line.$2.abs() > 0.0000001 || line.$3.abs() > 0.0000001)
        .toList();

    if (meaningful.isEmpty) return;

    var debits = 0.0;
    var credits = 0.0;

    for (final line in meaningful) {
      if (line.$2 < 0 || line.$3 < 0) {
        throw Exception('لا يمكن أن يحتوي القيد على قيمة سالبة');
      }
      if (line.$2 > 0 && line.$3 > 0) {
        throw Exception('السطر المحاسبي لا يمكن أن يكون مدينًا ودائنًا معًا');
      }
      debits += line.$2;
      credits += line.$3;
    }

    if ((debits - credits).abs() > 0.01) {
      throw Exception(
        'القيد غير متوازن: $description '
        '(مدين: $debits، دائن: $credits)',
      );
    }

    final existing = await db.journalEntriesDao.bySource(sourceType, sourceId);
    if (existing != null) return;

    final entryId = await db.journalEntriesDao.insertEntry(
      JournalEntriesCompanion.insert(
        entryNumber: 'JE-${DateTime.now().microsecondsSinceEpoch}',
        entryDate: Value(date),
        description: description,
        sourceType: Value(sourceType),
        sourceId: Value(sourceId),
      ),
    );

    for (final line in meaningful) {
      await db.journalLinesDao.insertLine(
        JournalLinesCompanion.insert(
          entryId: entryId,
          accountId: await _account(line.$1),
          debit: Value(line.$2),
          credit: Value(line.$3),
        ),
      );
    }
  }

  Future<double> _sumReturnTotals({
    required String type,
    required String column,
    required int sourceId,
  }) async {
    final row = await db.customSelect(
      'SELECT COALESCE(SUM(total), 0) AS value '
      'FROM returns WHERE type = ? AND $column = ? AND status = ?',
      variables: [
        Variable.withString(type),
        Variable.withInt(sourceId),
        Variable.withString('completed'),
      ],
      readsFrom: {db.returns},
    ).getSingle();
    return row.read<double>('value');
  }

  Future<double> _saleReturnCost(Return returned) async {
    if (returned.saleId == null) return 0;

    final sourceItems = await db.saleItemsDao.getBySaleId(returned.saleId!);
    final returnedItems = await db.returnItemsDao.byReturn(returned.id);

    var cost = 0.0;
    for (final returnItem in returnedItems) {
      final matching = sourceItems
          .where((item) => item.productId == returnItem.productId)
          .toList();

      var sourceQuantity = 0.0;
      var sourceCost = 0.0;
      for (final item in matching) {
        sourceQuantity += item.quantity;
        sourceCost += item.purchasePriceAtSale * item.quantity;
      }

      if (sourceQuantity > 0) {
        cost +=
            returnItem.quantity * (sourceCost / sourceQuantity);
      }
    }
    return cost;
  }

  Future<void> _rebuildInTransaction() async {
    await ensureChart();

    await db.journalLinesDao.deleteAll();
    await db.journalEntriesDao.deleteAll();

    // المبيعات: النقد المدفوع + ذمم العميل = إجمالي الفاتورة.
    final sales = await db.salesDao.getCompletedSales();
    for (final sale in sales) {
      final remaining = sale.remaining < 0 ? 0.0 : sale.remaining;
      final paid = sale.paid < 0 ? 0.0 : sale.paid;

      await _post(
        sourceType: 'sale',
        sourceId: sale.id,
        description: 'فاتورة بيع ${sale.invoiceNumber}',
        date: sale.saleDate,
        lines: [
          ('1000', paid, 0),
          ('1100', remaining, 0),
          ('4000', 0, sale.total),
        ],
      );

      final items = await db.saleItemsDao.getBySaleId(sale.id);
      final cost = items.fold<double>(
        0,
        (sum, item) => sum + item.purchasePriceAtSale * item.quantity,
      );

      if (cost > 0) {
        await _post(
          sourceType: 'sale_cogs',
          sourceId: sale.id,
          description: 'تكلفة بضاعة فاتورة ${sale.invoiceNumber}',
          date: sale.saleDate,
          lines: [
            ('5000', cost, 0),
            ('1200', 0, cost),
          ],
        );
      }
    }

    // المشتريات: المدفوع نقدًا + المتبقي للمورد = قيمة الشراء.
    final purchases = await db.purchasesDao.getAll();
    for (final purchase in purchases) {
      if (purchase.status == 'cancelled') continue;

      final paid = purchase.paid < 0 ? 0.0 : purchase.paid;
      final remaining = purchase.remaining < 0 ? 0.0 : purchase.remaining;

      await _post(
        sourceType: 'purchase',
        sourceId: purchase.id,
        description: 'فاتورة شراء ${purchase.invoiceNumber}',
        date: purchase.purchaseDate,
        lines: [
          ('1200', purchase.total, 0),
          ('1000', 0, paid),
          ('2000', 0, remaining),
        ],
      );
    }

    // المصروفات.
    final expenses = await db.expensesDao.getAll();
    for (final expense in expenses) {
      if (expense.amount <= 0) continue;

      final paymentAccount = switch (expense.paymentMethod) {
        'bank' => '1010',
        'credit' => '2100',
        _ => '1000',
      };

      await _post(
        sourceType: 'expense',
        sourceId: expense.id,
        description: expense.description?.trim().isNotEmpty == true
            ? expense.description!.trim()
            : 'مصروف #${expense.id}',
        date: expense.expenseDate,
        lines: [
          ('5100', expense.amount, 0),
          (paymentAccount, 0, expense.amount),
        ],
      );
    }

    // مرتجعات البيع والشراء.
    final returns = await db.returnsDao.search('');
    for (final returned in returns) {
      if (returned.status != 'completed' || returned.total <= 0) continue;

      if (returned.type == 'sale_return') {
        final sale = returned.saleId == null
            ? null
            : await db.salesDao.getById(returned.saleId!);
        if (sale == null) continue;

        final priorReturns =
            await _sumReturnTotals(
              type: 'sale_return',
              column: 'sale_id',
              sourceId: sale.id,
            );
        final priorBeforeThis = priorReturns - returned.total;
        final originalReceivable =
            sale.remaining < 0 ? 0.0 : sale.remaining;
        final receivableBefore =
            (originalReceivable - priorBeforeThis).clamp(0.0, double.infinity).toDouble();
        final receivableReduction =
            returned.total < receivableBefore
                ? returned.total
                : receivableBefore;
        final cashRefund = returned.total - receivableReduction;

        await _post(
          sourceType: 'sale_return',
          sourceId: returned.id,
          description: 'مرتجع بيع ${returned.returnNumber}',
          date: returned.returnDate,
          lines: [
            ('4010', returned.total, 0),
            ('1100', 0, receivableReduction),
            ('1000', 0, cashRefund),
          ],
        );

        final cost = await _saleReturnCost(returned);
        if (cost > 0) {
          await _post(
            sourceType: 'sale_return_cogs',
            sourceId: returned.id,
            description: 'عكس تكلفة مرتجع ${returned.returnNumber}',
            date: returned.returnDate,
            lines: [
              ('1200', cost, 0),
              ('5000', 0, cost),
            ],
          );
        }
      } else if (returned.type == 'purchase_return') {
        final purchase = returned.purchaseId == null
            ? null
            : await db.purchasesDao.getById(returned.purchaseId!);
        if (purchase == null) continue;

        final priorReturns =
            await _sumReturnTotals(
              type: 'purchase_return',
              column: 'purchase_id',
              sourceId: purchase.id,
            );
        final priorBeforeThis = priorReturns - returned.total;
        final originalPayable =
            purchase.remaining < 0 ? 0.0 : purchase.remaining;
        final payableBefore =
            (originalPayable - priorBeforeThis).clamp(0.0, double.infinity).toDouble();
        final payableReduction =
            returned.total < payableBefore
                ? returned.total
                : payableBefore;
        final cashRefund = returned.total - payableReduction;

        await _post(
          sourceType: 'purchase_return',
          sourceId: returned.id,
          description: 'مرتجع شراء ${returned.returnNumber}',
          date: returned.returnDate,
          lines: [
            ('2000', payableReduction, 0),
            ('1000', cashRefund, 0),
            ('1200', 0, returned.total),
          ],
        );
      }
    }

    // أرصدة افتتاحية وتسويات المخزون التي لا تمثل بيعًا أو شراءً.
    // تستخدم تكلفة الشراء الحالية كأفضل تكلفة متاحة لهذه الحركة لأن
    // جدول StockMovements لا يخزن تكلفة تاريخية.
    final stockMovements = await db.stockMovementsDao.getAll();
    for (final movement in stockMovements) {
      if (movement.quantity == 0) continue;

      final isOpening = movement.type == 'opening';
      final isAdjustment = movement.type == 'adjustment';
      if (!isOpening && !isAdjustment) continue;

      final product = await db.productsDao.getById(movement.productId);
      if (product == null) continue;

      final value =
          movement.quantity.abs() * product.purchasePrice;
      if (value <= 0) continue;

      if (isOpening || movement.quantity > 0) {
        await _post(
          sourceType: isOpening
              ? 'stock_opening'
              : 'stock_adjustment_gain',
          sourceId: movement.id,
          description: movement.notes?.trim().isNotEmpty == true
              ? movement.notes!.trim()
              : (isOpening ? 'رصيد مخزون افتتاحي' : 'زيادة تسوية مخزون'),
          date: movement.createdAt,
          lines: [
            ('1200', value, 0),
            (isOpening ? '3000' : '5200', 0, value),
          ],
        );
      } else {
        await _post(
          sourceType: 'stock_adjustment_loss',
          sourceId: movement.id,
          description: movement.notes?.trim().isNotEmpty == true
              ? movement.notes!.trim()
              : 'نقص تسوية مخزون',
          date: movement.createdAt,
          lines: [
            ('5201', value, 0),
            ('1200', 0, value),
          ],
        );
      }
    }

    // سداد العملاء: credit_sale و sale_return مشتقان من المبيعات والمرتجعات
    // ولا يعاد ترحيلهما هنا. payment فقط حركة نقدية فعلية.
    final customerTransactions =
        await db.customerTransactionsDao.getAll();
    for (final transaction in customerTransactions) {
      if (transaction.type != 'payment' || transaction.amount <= 0) continue;

      await _post(
        sourceType: 'customer_payment',
        sourceId: transaction.id,
        description: transaction.notes?.trim().isNotEmpty == true
            ? transaction.notes!.trim()
            : 'سداد عميل #${transaction.customerId}',
        date: transaction.createdAt,
        lines: [
          ('1000', transaction.amount, 0),
          ('1100', 0, transaction.amount),
        ],
      );
    }

    // سداد الموردين فقط؛ أما credit_purchase و purchase_return
    // فهما مشتقان من جداول المشتريات والمرتجعات.
    final supplierTransactions =
        await db.supplierTransactionsDao.getAll();
    for (final transaction in supplierTransactions) {
      if (transaction.type != 'payment' || transaction.amount >= 0) continue;

      final amount = -transaction.amount;
      await _post(
        sourceType: 'supplier_payment',
        sourceId: transaction.id,
        description: transaction.notes?.trim().isNotEmpty == true
            ? transaction.notes!.trim()
            : 'سداد مورد #${transaction.supplierId}',
        date: transaction.date,
        lines: [
          ('2000', amount, 0),
          ('1000', 0, amount),
        ],
      );
    }

    // الأرصدة الافتتاحية للموردين.
    final suppliers = await db.suppliersDao.getAll();
    for (final supplier in suppliers) {
      if (supplier.openingBalance <= 0) continue;

      await _post(
        sourceType: 'supplier_opening',
        sourceId: supplier.id,
        description: 'رصيد افتتاحي للمورد ${supplier.name}',
        date: supplier.createdAt,
        lines: [
          ('3000', supplier.openingBalance, 0),
          ('2000', 0, supplier.openingBalance),
        ],
      );
    }
  }

  /// يعاد بناؤه بالكامل داخل Transaction واحدة، وهو idempotent.
  Future<void> rebuild() async {
    await db.transaction(_rebuildInTransaction);
  }

  /// يستخدم من الخدمات داخل Transaction خارجية حتى يكون حفظ العملية
  /// والقيود المحاسبية Atomic في نفس المعاملة.
  Future<void> rebuildInTransaction() => _rebuildInTransaction();

  Future<AccountingSummary> summary() async {
    await ensureChart();

    final accounts = await db.accountsDao.getAll();
    final ids = {for (final account in accounts) account.code: account.id};
    final balances = await db.journalLinesDao.balances();
    final totals = await db.journalLinesDao.totals();

    double raw(String code) => balances[ids[code]] ?? 0.0;

    return AccountingSummary(
      totalDebits: totals.$1,
      totalCredits: totals.$2,
      cash: raw('1000'),
      bank: raw('1010'),
      receivables: raw('1100'),
      payables: -raw('2000') - raw('2100'),
      inventory: raw('1200'),
      revenue: -raw('4000'),
      salesReturns: raw('4010'),
      costOfGoodsSold: raw('5000'),
      expenses: raw('5100'),
      inventoryAdjustmentGain: -raw('5200'),
      inventoryAdjustmentLoss: raw('5201'),
    );
  }

  Future<AccountingDashboardData> dashboard() async {
    await ensureChart();
    final summaryFuture = summary();
    final accountsFuture = db.accountsDao.getAll();
    final entriesFuture = db.journalEntriesDao.recent(limit: 20);
    final balancesFuture = db.journalLinesDao.balances();

    return AccountingDashboardData(
      summary: await summaryFuture,
      accounts: await accountsFuture,
      entries: await entriesFuture,
      rawBalances: await balancesFuture,
    );
  }

  Future<void> postManual({
    required String description,
    required String debitCode,
    required String creditCode,
    required double amount,
  }) async {
    final clean = description.trim();
    if (clean.isEmpty) throw Exception('وصف القيد مطلوب');
    if (amount <= 0) throw Exception('قيمة القيد يجب أن تكون أكبر من صفر');
    if (debitCode == creditCode) {
      throw Exception('لا يمكن أن يتطابق الحساب المدين والدائن');
    }

    await db.transaction(() async {
      await ensureChart();
      final sourceId = DateTime.now().microsecondsSinceEpoch;
      await _post(
        sourceType: 'manual',
        sourceId: sourceId,
        description: clean,
        date: DateTime.now(),
        lines: [
          (debitCode, amount, 0),
          (creditCode, 0, amount),
        ],
      );
    });
  }
}
