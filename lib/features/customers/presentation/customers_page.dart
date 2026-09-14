import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';

class CustomersPage extends ConsumerStatefulWidget {
  const CustomersPage({super.key});

  @override
  ConsumerState<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends ConsumerState<CustomersPage> {
  final _searchController = TextEditingController();
  late final CurrencyService _currency;
  bool _currencyReady = false;
  late Future<List<Customer>> _customers;
  Map<int, double> _debts = {};

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    _customers = ref.read(customersDaoProvider).search(_searchController.text);
    _loadDebts();
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (mounted) setState(() => _currencyReady = true);
  }

  String _money(double yer) {
    final code = _currency.displayCurrency;
    return _currency.format(_currency.fromYer(yer, currency: code), currency: code);
  }

  Future<void> _loadDebts() async {
    final debts = await ref
        .read(customerTransactionsDaoProvider)
        .getAllCustomerDebts();
    if (mounted) setState(() => _debts = debts);
  }

  double get _totalCustomerDebts =>
      _debts.values.fold<double>(0, (sum, value) => sum + value);

  Future<void> _editCustomer([Customer? customer]) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: customer?.name ?? '');
    final phone = TextEditingController(text: customer?.phone ?? '');
    final address = TextEditingController(text: customer?.address ?? '');
    final notes = TextEditingController(text: customer?.notes ?? '');
    final creditLimit = TextEditingController(
      text: customer == null
          ? '0'
          : _currency.fromYer(customer.creditLimit, currency: _currency.displayCurrency).toStringAsFixed(2),
    );

    try {
      final saved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(customer == null ? 'إضافة عميل' : 'تعديل العميل'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم العميل',
                      ),
                      validator: (value) => value == null || value.trim().isEmpty
                          ? 'الاسم مطلوب'
                          : null,
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'الهاتف'),
                    ),
                    TextFormField(
                      controller: address,
                      decoration: const InputDecoration(labelText: 'العنوان'),
                    ),
                    TextFormField(
                      controller: creditLimit,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: 'سقف المديونية (${_currency.symbol()})',
                        helperText: 'اكتب 0 إذا أردت بدون سقف',
                      ),
                      validator: (value) {
                        final limit = double.tryParse(value?.trim() ?? '');
                        if (limit == null || limit < 0) {
                          return 'السقف يجب أن يكون صفرًا أو أكبر';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (saved != true) return;

      final limit = _currency.toYer(double.parse(creditLimit.text.trim()), currency: _currency.displayCurrency);
      final companion = CustomersCompanion(
        id: customer == null
            ? const drift.Value.absent()
            : drift.Value(customer.id),
        name: drift.Value(name.text.trim()),
        phone: drift.Value(
          phone.text.trim().isEmpty ? null : phone.text.trim(),
        ),
        address: drift.Value(
          address.text.trim().isEmpty ? null : address.text.trim(),
        ),
        notes: drift.Value(
          notes.text.trim().isEmpty ? null : notes.text.trim(),
        ),
        creditLimit: drift.Value(limit),
        isActive: drift.Value(customer?.isActive ?? true),
        createdAt: customer == null
            ? const drift.Value.absent()
            : drift.Value(customer.createdAt),
        updatedAt: drift.Value(DateTime.now()),
      );

      if (customer == null) {
        await ref.read(customersDaoProvider).insertCustomer(companion);
      } else {
        await ref.read(customersDaoProvider).updateCustomer(companion);
      }

      if (mounted) setState(_load);
    } finally {
      name.dispose();
      phone.dispose();
      address.dispose();
      notes.dispose();
      creditLimit.dispose();
    }
  }

  Future<void> _recordPayment(Customer customer) async {
    final debt = _debts[customer.id] ?? 0;
    if (debt <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا توجد مديونية مستحقة على هذا العميل')),
      );
      return;
    }

    final controller = TextEditingController();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سداد من ${customer.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'المبلغ (${_currency.symbol()})',
            helperText: 'المتبقي على العميل: ${_money(debt)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text);
              final displayDebt = _currency.fromYer(debt, currency: _currency.displayCurrency);
              if (value == null || value <= 0 || value > displayDebt) return;
              Navigator.pop(context, _currency.toYer(value, currency: _currency.displayCurrency));
            },
            child: const Text('تسجيل السداد'),
          ),
        ],
      ),
    );

    controller.dispose();
    if (amount == null) return;

    await ref.read(customerTransactionsDaoProvider).insertTransaction(
          CustomerTransactionsCompanion.insert(
            customerId: customer.id,
            type: 'payment',
            amount: drift.Value(amount),
            notes: const drift.Value('سداد من صفحة العملاء'),
          ),
        );

    if (mounted) {
      setState(_load);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل السداد')),
      );
    }
  }

  Future<void> _showTransactions(Customer customer) async {
    final transactions = await ref
        .read(customerTransactionsDaoProvider)
        .getByCustomerId(customer.id);

    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('حركات ${customer.name}'),
        content: SizedBox(
          width: 620,
          child: transactions.isEmpty
              ? const Text('لا توجد حركات')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final transaction = transactions[index];
                    final reduction =
                        transaction.type == 'payment' ||
                        transaction.type == 'sale_return';

                    return ListTile(
                      leading: Icon(
                        reduction
                            ? Icons.arrow_downward
                            : Icons.arrow_upward,
                        color: reduction ? Colors.green : Colors.red,
                      ),
                      title: Text(_typeLabel(transaction.type)),
                      subtitle: Text(
                        transaction.createdAt
                            .toLocal()
                            .toString()
                            .split('.')
                            .first,
                      ),
                      trailing: Text(
                        _money(transaction.amount),
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  String _typeLabel(String type) => switch (type) {
        'credit_sale' => 'بيع آجل',
        'payment' => 'سداد',
        'sale_return' => 'مرتجع بيع',
        _ => type,
      };

  Future<void> _deactivate(Customer customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعطيل العميل'),
        content: Text(
          'سيتم إخفاء ${customer.name} دون حذف حركاته المالية. هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('تعطيل'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(customersDaoProvider).updateCustomer(
          CustomersCompanion(
            id: drift.Value(customer.id),
            name: drift.Value(customer.name),
            phone: drift.Value(customer.phone),
            address: drift.Value(customer.address),
            notes: drift.Value(customer.notes),
            creditLimit: drift.Value(customer.creditLimit),
            isActive: const drift.Value(false),
            createdAt: drift.Value(customer.createdAt),
            updatedAt: drift.Value(DateTime.now()),
          ),
        );

    if (mounted) setState(_load);
  }

  DataRow _row(Customer customer) {
    final debt = _debts[customer.id] ?? 0;
    final hasLimit = customer.creditLimit > 0;
    final exceeded = hasLimit && debt > customer.creditLimit + 0.01;

    return DataRow(
      cells: [
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (exceeded)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.red,
                  ),
                ),
              Text(customer.name),
            ],
          ),
        ),
        DataCell(Text(customer.phone ?? '-')),
        DataCell(
          Text(
            _money(debt),
            style: TextStyle(
              color: exceeded
                  ? Colors.red
                  : debt > 0
                      ? Colors.orange
                      : Colors.green,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        DataCell(
          Text(
            hasLimit
                ? _money(customer.creditLimit)
                : 'بدون سقف',
          ),
        ),
        DataCell(
          exceeded
              ? const Text(
                  'تجاوز السقف',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                )
              : const Text('ضمن السقف'),
        ),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'تعديل',
                onPressed: () => _editCustomer(customer),
                icon: const Icon(Icons.edit),
              ),
              IconButton(
                tooltip: 'سداد',
                onPressed: () => _recordPayment(customer),
                icon: const Icon(Icons.payments),
              ),
              IconButton(
                tooltip: 'الحركات',
                onPressed: () => _showTransactions(customer),
                icon: const Icon(Icons.history),
              ),
              IconButton(
                tooltip: 'تعطيل',
                onPressed: () => _deactivate(customer),
                icon: const Icon(Icons.person_off),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة العملاء والذمم'),
          actions: [
            IconButton(
              onPressed: () => _editCustomer(),
              icon: const Icon(Icons.person_add),
            ),
            IconButton(
              onPressed: () => setState(_load),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Icon(Icons.account_balance_wallet_outlined),
                      const SizedBox(width: 10),
                      const Text(
                        'إجمالي المبالغ المتبقية عند العملاء:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _money(_totalCustomerDebts),
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _searchController,
                onChanged: (_) => setState(_load),
                decoration: const InputDecoration(
                  labelText: 'بحث بالاسم أو الهاتف',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Customer>>(
                  future: _customers,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'تعذر تحميل العملاء: ${snapshot.error}',
                        ),
                      );
                    }

                    final customers = snapshot.data ?? [];

                    if (customers.isEmpty) {
                      return const Center(child: Text('لا يوجد عملاء'));
                    }

                    return Card(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('الاسم')),
                            DataColumn(label: Text('الهاتف')),
                            DataColumn(label: Text('المتبقي عند العميل')),
                            DataColumn(label: Text('سقف المديونية')),
                            DataColumn(label: Text('الحالة')),
                            DataColumn(label: Text('الإجراءات')),
                          ],
                          rows: customers.map(_row).toList(),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
