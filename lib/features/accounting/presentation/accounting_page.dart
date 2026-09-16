import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/accounting_service.dart';

class AccountingPage extends ConsumerStatefulWidget {
  const AccountingPage({super.key});

  @override
  ConsumerState<AccountingPage> createState() => _AccountingPageState();
}

class _AccountingPageState extends ConsumerState<AccountingPage> {
  late Future<AccountingDashboardData> _dashboardFuture;
  bool _isRebuilding = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _dashboardFuture =
        ref.read(accountingServiceProvider).dashboard();
  }

  Future<void> _refresh() async {
    setState(_reload);
    await _dashboardFuture;
  }

  Future<void> _rebuild() async {
    setState(() => _isRebuilding = true);
    try {
      await ref.read(accountingServiceProvider).rebuild();
      if (!mounted) return;
      setState(_reload);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تمت إعادة بناء القيود بنجاح')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل إعادة البناء: $error')),
      );
    } finally {
      if (mounted) setState(() => _isRebuilding = false);
    }
  }

  Future<void> _manualEntry() async {
    final description = TextEditingController();
    final amount = TextEditingController();
    String? debitCode;
    String? creditCode;

    try {
      final accounts =
          await ref.read(accountingServiceProvider).db.accountsDao.getAll();
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('قيد محاسبي يدوي'),
              content: SizedBox(
                width: 520,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: description,
                      decoration:
                          const InputDecoration(labelText: 'الوصف'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: debitCode,
                      decoration:
                          const InputDecoration(labelText: 'الحساب المدين'),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.code,
                              child: Text('${a.code} - ${a.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => debitCode = value),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: creditCode,
                      decoration:
                          const InputDecoration(labelText: 'الحساب الدائن'),
                      items: accounts
                          .map(
                            (a) => DropdownMenuItem(
                              value: a.code,
                              child: Text('${a.code} - ${a.name}'),
                            ),
                          )
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => creditCode = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'المبلغ'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    final value = double.tryParse(amount.text.trim());
                    if (debitCode == null ||
                        creditCode == null ||
                        value == null ||
                        value <= 0) {
                      return;
                    }

                    try {
                      await ref.read(accountingServiceProvider).postManual(
                            description: description.text,
                            debitCode: debitCode!,
                            creditCode: creditCode!,
                            amount: value,
                          );
                      if (dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                      }
                    } catch (error) {
                      if (dialogContext.mounted) {
                        ScaffoldMessenger.of(dialogContext).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('ترحيل'),
                ),
              ],
            );
          },
        ),
      );

      if (mounted) setState(_reload);
    } finally {
      description.dispose();
      amount.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المحاسبة'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'قيد يدوي',
              onPressed: _manualEntry,
              icon: const Icon(Icons.post_add),
            ),
            _isRebuilding
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : IconButton(
                    tooltip: 'إعادة بناء المحاسبة',
                    onPressed: _rebuild,
                    icon: const Icon(Icons.sync),
                  ),
          ],
        ),
        body: FutureBuilder<AccountingDashboardData>(
          future: _dashboardFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _error(snapshot.error);
            }

            final data = snapshot.data;
            if (data == null) {
              return const Center(child: Text('لا توجد بيانات محاسبية'));
            }

            return _content(data);
          },
        ),
      ),
    );
  }

  Widget _error(Object? error) {
    return Center(
      child: Card(
        margin: const EdgeInsets.all(32),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text('تعذر تحميل المحاسبة\n$error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => setState(_reload),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _content(AccountingDashboardData data) {
    final s = data.summary;

    final cards = <_Metric>[
      _Metric('الصندوق', s.cash, Icons.payments_outlined),
      _Metric('البنك', s.bank, Icons.account_balance_outlined),
      _Metric('ذمم العملاء', s.receivables, Icons.people_outline),
      _Metric('ذمم الموردين', s.payables, Icons.local_shipping_outlined),
      _Metric('المخزون', s.inventory, Icons.inventory_2_outlined),
      _Metric('إيرادات المبيعات', s.revenue, Icons.trending_up),
      _Metric('مردودات المبيعات', s.salesReturns, Icons.assignment_return),
      _Metric('تكلفة البضاعة المباعة', s.costOfGoodsSold, Icons.shopping_cart_checkout),
      _Metric('المصروفات', s.expenses, Icons.money_off),
      _Metric(
        'صافي فروقات المخزون',
        s.inventoryAdjustmentGain - s.inventoryAdjustmentLoss,
        Icons.fact_check_outlined,
      ),
      _Metric('مجمل الربح', s.grossProfit, Icons.bar_chart),
      _Metric('صافي الربح', s.netProfit, Icons.account_balance_wallet_outlined),
    ];

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _accountingHero(s),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: cards
                .map((metric) => SizedBox(
                      width: 250,
                      child: _MetricCard(metric: metric),
                    ))
                .toList(),
          ),
          const SizedBox(height: 24),
          _profitabilityCard(s),
          const SizedBox(height: 24),
          _sectionTitle('ميزان المراجعة'),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Wrap(
                spacing: 36,
                runSpacing: 16,
                children: [
                  _valueItem('إجمالي المدين', s.totalDebits),
                  _valueItem('إجمالي الدائن', s.totalCredits),
                  _valueItem('الفرق', s.difference),
                  Chip(
                    avatar: Icon(
                      s.balanced ? Icons.check_circle : Icons.warning,
                      size: 18,
                    ),
                    label: Text(
                      s.balanced
                          ? 'القيد متوازن'
                          : 'يوجد فرق محاسبي',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('دليل الحسابات'),
          const SizedBox(height: 12),
          Card(
            clipBehavior: Clip.antiAlias,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('الكود')),
                  DataColumn(label: Text('الحساب')),
                  DataColumn(label: Text('النوع')),
                  DataColumn(label: Text('الرصيد')),
                ],
                rows: data.accounts.map((account) {
                  final raw = data.rawBalances[account.id] ?? 0;
                  final balance = _naturalBalance(account, raw);
                  return DataRow(
                    cells: [
                      DataCell(Text(account.code)),
                      DataCell(Text(account.name)),
                      DataCell(Text(_typeName(account.type))),
                      DataCell(Text(_money(balance))),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 28),
          _sectionTitle('آخر القيود'),
          const SizedBox(height: 12),
          Card(
            child: data.entries.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('لا توجد قيود حتى الآن'),
                  )
                : Column(
                    children: data.entries
                        .map(
                          (entry) => ListTile(
                            leading: const CircleAvatar(
                              child: Icon(Icons.receipt_long),
                            ),
                            title: Text(entry.description),
                            subtitle: Text(
                              '${entry.entryNumber} • '
                              '${_date(entry.entryDate)}'
                              '${entry.sourceType == null ? '' : ' • ${entry.sourceType}'}',
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _accountingHero(AccountingSummary s) {
    final cs = Theme.of(context).colorScheme;
    final status = s.balanced ? 'النظام المحاسبي متوازن' : 'يحتاج النظام إلى مراجعة القيود';
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.surfaceContainerHigh],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 62, height: 62,
            decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(18)),
            child: Icon(Icons.account_balance_rounded, color: cs.onPrimary, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('المركز المالي والمحاسبي', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(status),
              ],
            ),
          ),
          _heroValue('صافي الربح', s.netProfit),
          const SizedBox(width: 24),
          _heroValue('المخزون', s.inventory),
        ],
      ),
    );
  }

  Widget _heroValue(String title, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(_money(value), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _profitabilityCard(AccountingSummary s) {
    final netSales = s.revenue - s.salesReturns;
    final margin = netSales == 0 ? 0.0 : s.grossProfit / netSales * 100;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.insights_rounded),
              const SizedBox(width: 10),
              Text('تحليل الربحية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
            ]),
            const SizedBox(height: 18),
            Wrap(
              spacing: 32, runSpacing: 16,
              children: [
                _valueItem('صافي المبيعات', netSales),
                _valueItem('مجمل الربح', s.grossProfit),
                _percentItem('هامش الربح', margin),
                _valueItem('صافي الربح', s.netProfit),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _naturalBalance(Account account, double raw) {
    if (account.code == '4010') return raw;
    switch (account.type) {
      case 'asset':
      case 'expense':
        return raw;
      case 'liability':
      case 'equity':
      case 'revenue':
        return -raw;
      default:
        return raw;
    }
  }

  Widget _sectionTitle(String title) => Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      );

  Widget _percentItem(String title, double value) => SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text('${value.toStringAsFixed(1)}%', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _valueItem(String title, double value) => SizedBox(
        width: 190,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              _money(value),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      );

  String _typeName(String type) => switch (type) {
        'asset' => 'أصل',
        'liability' => 'التزام',
        'equity' => 'حقوق ملكية',
        'revenue' => 'إيراد',
        'expense' => 'مصروف',
        _ => type,
      };

  String _money(double value) {
    final rounded = value.abs() < 0.005 ? 0.0 : value;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2);
  }

  String _date(DateTime value) {
    final d = value.toLocal();
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }
}

class _Metric {
  final String title;
  final double value;
  final IconData icon;

  const _Metric(this.title, this.value, this.icon);
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;

  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(child: Icon(metric.icon)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(metric.title),
                  const SizedBox(height: 6),
                  Text(
                    _format(metric.value),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _format(double value) {
    final rounded = value.abs() < 0.005 ? 0.0 : value;
    return rounded == rounded.roundToDouble()
        ? rounded.toInt().toString()
        : rounded.toStringAsFixed(2);
  }
}
