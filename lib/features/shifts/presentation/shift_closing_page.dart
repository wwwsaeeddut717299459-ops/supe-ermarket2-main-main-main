import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../providers/currency_providers.dart';
import '../../../providers/database_providers.dart';
import '../../../services/currency_service.dart';

class ShiftClosingPage extends ConsumerStatefulWidget {
  const ShiftClosingPage({super.key});

  @override
  ConsumerState<ShiftClosingPage> createState() => _ShiftClosingPageState();
}

class _ShiftClosingPageState extends ConsumerState<ShiftClosingPage> {
  late final CurrencyService _currency;
  bool _ready = false;
  bool _loading = true;
  double _sales = 0;
  double _customerPayments = 0;
  double _purchases = 0;
  double _supplierPayments = 0;
  double _expenses = 0;
  double _returns = 0;
  double _expected = 0;
  double? _actual;
  double? _difference;
  late DateTime _day;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _day = DateTime.now();
    _loadCurrencyAndDay();
  }

  Future<void> _loadCurrencyAndDay() async {
    await _currency.load();
    if (mounted) setState(() => _ready = true);
    await _loadDay();
  }

  bool _sameDay(DateTime date) =>
      date.year == _day.year && date.month == _day.month && date.day == _day.day;

  Future<void> _loadDay() async {
    setState(() => _loading = true);
    final db = ref.read(databaseProvider);
    final sales = await db.salesDao.getAll();
    final purchases = await db.purchasesDao.getAll();
    final expenses = await db.expensesDao.getAll();
    final customerTx = await db.customerTransactionsDao.getAll();
    final supplierTx = await db.supplierTransactionsDao.getAll();
    final returns = await db.returnsDao.getAll();

    double salesCash = 0;
    double customerPayments = 0;
    double purchaseCash = 0;
    double supplierPayments = 0;
    double expenseCash = 0;
    double returnsCash = 0;

    for (final x in sales) {
      if (_sameDay(x.saleDate)) salesCash += x.paid;
    }
    for (final x in customerTx) {
      if (_sameDay(x.createdAt) && x.type == 'payment') customerPayments += x.amount;
    }
    for (final x in purchases) {
      if (_sameDay(x.purchaseDate)) purchaseCash += x.paid;
    }
    for (final x in supplierTx) {
      if (_sameDay(x.date) && x.type == 'payment') supplierPayments += x.amount;
    }
    for (final x in expenses) {
      if (_sameDay(x.expenseDate) && x.paymentMethod == 'cash') expenseCash += x.amount;
    }
    for (final x in returns) {
      if (_sameDay(x.returnDate) && x.type == 'sale_return') returnsCash += x.total;
    }

    if (!mounted) return;
    setState(() {
      _sales = salesCash;
      _customerPayments = customerPayments;
      _purchases = purchaseCash;
      _supplierPayments = supplierPayments;
      _expenses = expenseCash;
      _returns = returnsCash;
      _expected = salesCash + customerPayments - purchaseCash - supplierPayments - expenseCash - returnsCash;
      _loading = false;
    });
  }

  Future<File> _closingFile() async {
    final dir = await getApplicationSupportDirectory();
    await dir.create(recursive: true);
    return File(p.join(dir.path, 'shift_closings.json'));
  }

  Future<void> _closeShift() async {
    final controller = TextEditingController();
    final actualDisplay = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('إغلاق الوردية / اليوم'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'النقد الفعلي (${_currency.symbol()})'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null || value < 0) return;
              Navigator.pop(context, value);
            },
            child: const Text('إغلاق اليوم'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (actualDisplay == null) return;

    final actualYer = _currency.toYer(actualDisplay, currency: _currency.displayCurrency);
    final file = await _closingFile();
    List<dynamic> rows = [];
    if (await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        if (raw is List) rows = raw;
      } catch (_) {}
    }
    rows.add({
      'date': _day.toIso8601String(),
      'expectedYer': _expected,
      'actualYer': actualYer,
      'differenceYer': actualYer - _expected,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
    });
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(rows), flush: true);

    if (!mounted) return;
    setState(() {
      _actual = actualYer;
      _difference = actualYer - _expected;
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم إغلاق اليوم وتسجيل الفرق')));
  }

  String _money(double yer) {
    final code = _currency.displayCurrency;
    return _currency.format(_currency.fromYer(yer, currency: code), currency: code);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready || _loading) return const Center(child: CircularProgressIndicator());
    return Scaffold(
      appBar: AppBar(
        title: const Text('إغلاق الوردية / اليوم'),
        actions: [IconButton(onPressed: _loadDay, icon: const Icon(Icons.refresh))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Card(child: ListTile(leading: const Icon(Icons.today), title: const Text('تاريخ اليوم'), subtitle: Text('${_day.day}/${_day.month}/${_day.year}'))),
          const SizedBox(height: 12),
          _row('المبيعات المدفوعة', _sales),
          _row('سداد العملاء', _customerPayments),
          _row('المشتريات المدفوعة', -_purchases),
          _row('سداد الموردين', -_supplierPayments),
          _row('المصروفات النقدية', -_expenses),
          _row('مرتجعات المبيعات', -_returns),
          const Divider(height: 32),
          _row('النقد المتوقع في الصندوق', _expected, strong: true),
          if (_actual != null) ...[
            const SizedBox(height: 12),
            _row('النقد الفعلي', _actual!, strong: true),
            _row('فرق الصندوق', _difference!, strong: true),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _closeShift,
            icon: const Icon(Icons.lock_clock),
            label: const Text('إغلاق اليوم وتسجيل النقد الفعلي'),
          ),
          const SizedBox(height: 12),
          const Text('ملاحظة: الأرقام مبنية على الحركات المسجلة في قاعدة البيانات بالعملة الأساسية YER، ثم تُعرض بعملة النظام الحالية.'),
        ],
      ),
    );
  }

  Widget _row(String label, double value, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
            Text(_money(value.abs()), style: TextStyle(fontWeight: strong ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );
}
