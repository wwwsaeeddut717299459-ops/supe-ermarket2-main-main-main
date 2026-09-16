import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';

enum OperationKind {
  all,
  sale,
  purchase,
  customerDebt,
  customerPayment,
  supplierDebt,
  supplierPayment,
  expense,
  returnOperation,
  employee,
}

class _Operation {
  final OperationKind kind;
  final int id;
  final DateTime date;
  final double amount;
  final String title;
  final String subtitle;
  final String reference;
  final String details;
  final String paymentMethod;

  const _Operation({
    required this.kind,
    required this.id,
    required this.date,
    required this.amount,
    required this.title,
    required this.subtitle,
    required this.reference,
    required this.details,
    required this.paymentMethod,
  });
}

class OperationsPage extends ConsumerStatefulWidget {
  const OperationsPage({super.key});

  @override
  ConsumerState<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends ConsumerState<OperationsPage> {
  OperationKind _filter = OperationKind.all;
  String _query = '';
  DateTime? _from;
  DateTime? _to;
  late Future<List<_Operation>> _future;
  late final CurrencyService _currency;
  bool _currencyReady = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
    _future = _load();
  }

  Future<List<_Operation>> _load() async {
    final db = ref.read(databaseProvider);
    final sales = await db.salesDao.getAll();
    final purchases = await db.purchasesDao.getAll();
    final expenses = await db.expensesDao.getAll();
    final customerTransactions = await db.customerTransactionsDao.getAll();
    final supplierTransactions = await db.supplierTransactionsDao.getAll();
    final returns = await db.returnsDao.getAll();
    final customers = await db.customersDao.getAll();
    final suppliers = await db.suppliersDao.getAll();
    final categories = await db.expenseCategoriesDao.getAll();
    final employeeRows = await db.customSelect('SELECT et.*, e.name AS employee_name FROM employee_transactions et JOIN employees e ON e.id=et.employee_id ORDER BY et.transaction_date DESC').get();

    final customerNames = {for (final x in customers) x.id: x.name};
    final supplierNames = {for (final x in suppliers) x.id: x.name};
    final categoryNames = {for (final x in categories) x.id: x.name};

    final result = <_Operation>[];

    for (final x in sales) {
      final isCredit = x.paymentMethod == 'credit' || x.remaining > 0;
      result.add(_Operation(
        kind: isCredit ? OperationKind.customerDebt : OperationKind.sale,
        id: x.id,
        date: x.saleDate,
        amount: x.total,
        title: isCredit ? 'دين عميل • بيع آجل' : 'عملية بيع',
        subtitle: x.customerId == null
            ? 'عميل نقدي'
            : (customerNames[x.customerId!] ?? 'عميل #${x.customerId}'),
        reference: 'فاتورة ${x.invoiceNumber}',
        details:
            'الإجمالي: ${_money(x.total)} • المدفوع: ${_money(x.paid)} • المتبقي: ${_money(x.remaining)}',
        paymentMethod: _paymentName(x.paymentMethod),
      ));
    }

    for (final x in purchases) {
      final isCredit = x.paymentMethod == 'credit' || x.remaining > 0;
      result.add(_Operation(
        kind: isCredit ? OperationKind.supplierDebt : OperationKind.purchase,
        id: x.id,
        date: x.purchaseDate,
        amount: x.total,
        title: isCredit ? 'دين للمورد • شراء آجل' : 'عملية شراء',
        subtitle: x.supplierId == null
            ? 'مورد غير محدد'
            : (supplierNames[x.supplierId!] ?? 'مورد #${x.supplierId}'),
        reference: 'فاتورة ${x.invoiceNumber}',
        details:
            'الإجمالي: ${_money(x.total)} • المدفوع: ${_money(x.paid)} • المتبقي: ${_money(x.remaining)}',
        paymentMethod: _paymentName(x.paymentMethod),
      ));
    }

    for (final x in customerTransactions) {
      if (x.type != 'payment') continue;
      result.add(_Operation(
        kind: OperationKind.customerPayment,
        id: x.id,
        date: x.createdAt,
        amount: x.amount,
        title: 'سداد عميل',
        subtitle: customerNames[x.customerId] ?? 'عميل #${x.customerId}',
        reference: x.saleId == null ? 'سند سداد #${x.id}' : 'مرتبط بفاتورة #${x.saleId}',
        details: x.notes?.trim().isNotEmpty == true
            ? x.notes!
            : 'تم تسجيل سداد بقيمة ${_money(x.amount)}',
        paymentMethod: 'نقدي/تحصيل',
      ));
    }

    for (final x in supplierTransactions) {
      if (x.type != 'payment') continue;
      result.add(_Operation(
        kind: OperationKind.supplierPayment,
        id: x.id,
        date: x.date,
        amount: x.amount,
        title: 'سداد للمورد',
        subtitle: supplierNames[x.supplierId] ?? 'مورد #${x.supplierId}',
        reference: x.referenceId == null
            ? 'سند سداد #${x.id}'
            : 'مرجع #${x.referenceId}',
        details: x.notes?.trim().isNotEmpty == true
            ? x.notes!
            : 'تم تسجيل سداد بقيمة ${_money(x.amount)}',
        paymentMethod: 'نقدي/تحويل',
      ));
    }

    for (final x in expenses) {
      result.add(_Operation(
        kind: OperationKind.expense,
        id: x.id,
        date: x.expenseDate,
        amount: x.amount,
        title: 'مصروفات',
        subtitle: categoryNames[x.categoryId] ?? 'مصروف #${x.categoryId}',
        reference: 'سند مصروف #${x.id}',
        details: [
          if (x.description?.trim().isNotEmpty == true) x.description!,
          if (x.notes?.trim().isNotEmpty == true) x.notes!,
        ].join(' • ').isEmpty
            ? 'مصروف مسجل بقيمة ${_money(x.amount)}'
            : [
                if (x.description?.trim().isNotEmpty == true) x.description!,
                if (x.notes?.trim().isNotEmpty == true) x.notes!,
              ].join(' • '),
        paymentMethod: _paymentName(x.paymentMethod),
      ));
    }

    for (final x in employeeRows) {
      final type=x.read<String>('type');
      result.add(_Operation(kind:OperationKind.employee,id:x.read<int>('id'),date:DateTime.tryParse(x.read<String>('transaction_date'))??DateTime.now(),amount:x.read<double>('amount'),title:'موظف • ${_employeeType(type)}',subtitle:x.read<String>('employee_name'),reference:'حركة موظف #${x.read<int>('id')}',details:x.read<String>('description').trim().isEmpty?'عملية مالية للموظف':x.read<String>('description'),paymentMethod:'مصروف موظفين'));
    }

    for (final x in returns) {
      final saleReturn = x.type == 'sale_return';
      result.add(_Operation(
        kind: OperationKind.returnOperation,
        id: x.id,
        date: x.returnDate,
        amount: x.total,
        title: saleReturn ? 'مرتجع مبيعات' : 'مرتجع مشتريات',
        subtitle: saleReturn ? 'إرجاع من عميل' : 'إرجاع إلى مورد',
        reference: 'مرتجع #${x.id}',
        details: x.notes?.trim().isNotEmpty == true
            ? x.notes!
            : 'قيمة المرتجع ${_money(x.total)}',
        paymentMethod: 'مرتجع',
      ));
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result;
  }

  String _money(double yer) {
    final code = _currency.displayCurrency;
    return _currency.format(_currency.fromYer(yer, currency: code), currency: code);
  }

  static String _paymentName(String value) => switch (value) {
    'cash' => 'نقداً',
    'credit' => 'آجل',
    'bank' => 'تحويل بنكي',
    _ => value,
  };

  List<_Operation> _filterRows(List<_Operation> rows) {
    final q = _query.trim().toLowerCase();
    return rows.where((x) {
      final kindOk = _filter == OperationKind.all || x.kind == _filter;
      final fromOk = _from == null || !x.date.isBefore(_from!);
      final toOk = _to == null || x.date.isBefore(_to!.add(const Duration(days: 1)));
      final text = '${x.title} ${x.subtitle} ${x.reference} ${x.details}'.toLowerCase();
      return kindOk && fromOk && toOk && (q.isEmpty || text.contains(q));
    }).toList();
  }

  String _employeeType(String t)=>switch(t){'salary'=>'راتب','advance'=>'سلفة','withdrawal'=>'سحب','payment'=>'صرف',_=>'حركة'};

  String _filterName(OperationKind kind) => switch (kind) {
    OperationKind.all => 'كل العمليات',
    OperationKind.sale => 'المبيعات',
    OperationKind.purchase => 'المشتريات',
    OperationKind.customerDebt => 'دين عميل',
    OperationKind.customerPayment => 'سداد عميل',
    OperationKind.supplierDebt => 'دين للمورد',
    OperationKind.supplierPayment => 'سداد للمورد',
    OperationKind.expense => 'المصروفات',
    OperationKind.returnOperation => 'المرتجعات',
    OperationKind.employee => 'الموظفون',
  };

  IconData _icon(OperationKind kind) => switch (kind) {
    OperationKind.sale => Icons.point_of_sale_rounded,
    OperationKind.purchase => Icons.shopping_cart_rounded,
    OperationKind.customerDebt => Icons.person_add_alt_1_rounded,
    OperationKind.customerPayment => Icons.payments_rounded,
    OperationKind.supplierDebt => Icons.request_quote_rounded,
    OperationKind.supplierPayment => Icons.local_shipping_rounded,
    OperationKind.expense => Icons.money_off_rounded,
    OperationKind.returnOperation => Icons.assignment_return_rounded,
    OperationKind.employee => Icons.badge_rounded,
    OperationKind.all => Icons.auto_awesome_rounded,
  };

  Color _accent(BuildContext context, OperationKind kind) {
    final cs = Theme.of(context).colorScheme;
    return switch (kind) {
      OperationKind.sale => cs.primary,
      OperationKind.purchase => cs.secondary,
      OperationKind.customerDebt => Colors.orange,
      OperationKind.customerPayment => Colors.green,
      OperationKind.supplierDebt => Colors.deepPurple,
      OperationKind.supplierPayment => Colors.teal,
      OperationKind.expense => Colors.redAccent,
      OperationKind.returnOperation => Colors.blueGrey,
      OperationKind.employee => Colors.deepOrange,
      OperationKind.all => cs.primary,
    };
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _from == null
          ? null
          : DateTimeRange(start: _from!, end: _to ?? _from!),
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day);
    });
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (mounted) setState(() => _currencyReady = true);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_currencyReady) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('سجل العمليات'),
        actions: [
          IconButton(
            tooltip: 'تحديد فترة',
            onPressed: _pickDateRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<_Operation>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر تحميل سجل العمليات: ${snapshot.error}'));
          }

          final rows = _filterRows(snapshot.data ?? const []);
          final total = rows.fold<double>(0, (sum, x) => sum + x.amount);

          return Column(
            children: [
              _heroHeader(context, rows.length, total),
              _filters(context),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.inbox_rounded, size: 56),
                            SizedBox(height: 12),
                            Text('لا توجد عمليات مطابقة للفلاتر الحالية'),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                        itemCount: rows.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) => _operationTile(context, rows[index]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _heroHeader(BuildContext context, int count, double total) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 18, 20, 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.surfaceContainerHigh],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(Icons.history_rounded, color: cs.onPrimary, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('مركز العمليات', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('سجل موحّد لكل حركة مالية وتشغيلية داخل النظام'),
              ],
            ),
          ),
          _summaryPill(context, 'العمليات', '$count'),
          const SizedBox(width: 10),
          _summaryPill(context, 'إجمالي القيم', _money(total)),
        ],
      ),
    );
  }

  Widget _summaryPill(BuildContext context, String label, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(210),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Column(
        children: [
          TextField(
            decoration: InputDecoration(
              hintText: 'ابحث بالعميل، المورد، الفاتورة، الوصف أو رقم السند...',
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: cs.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: OperationKind.values.map((kind) {
                final selected = _filter == kind;
                return Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: ChoiceChip(
                    selected: selected,
                    avatar: Icon(_icon(kind), size: 17),
                    label: Text(_filterName(kind)),
                    onSelected: (_) => setState(() => _filter = kind),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _operationTile(BuildContext context, _Operation x) {
    final accent = _accent(context, x.kind);
    return Card(
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showDetails(context, x),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withAlpha(24),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Icon(_icon(x.kind), color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(x.title, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(x.subtitle, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 4),
                    Text('${x.reference} • ${_date(x.date)}', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(_money(x.amount), style: TextStyle(fontWeight: FontWeight.w900, color: accent, fontSize: 16)),
                  const SizedBox(height: 5),
                  Text(x.paymentMethod, style: Theme.of(context).textTheme.labelSmall),
                ],
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_left_rounded),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, _Operation x) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_icon(x.kind), color: _accent(context, x.kind)),
            const SizedBox(width: 10),
            Expanded(child: Text(x.title)),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detail('التاريخ', _date(x.date)),
              _detail('القيمة', _money(x.amount)),
              _detail('الطرف', x.subtitle),
              _detail('المرجع', x.reference),
              _detail('طريقة الدفع', x.paymentMethod),
              _detail('التفاصيل', x.details),
            ],
          ),
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
        ],
      ),
    );
  }

  Widget _detail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 95, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w800))),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')} '
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}
