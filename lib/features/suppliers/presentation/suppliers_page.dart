import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';

class SuppliersPage extends ConsumerStatefulWidget {
  const SuppliersPage({super.key});

  @override
  ConsumerState<SuppliersPage> createState() => _SuppliersPageState();
}

class _SuppliersPageState extends ConsumerState<SuppliersPage> {
  late final CurrencyService _currency;
  bool _currencyReady = false;
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (mounted) setState(() => _currencyReady = true);
  }

  String _money(double yer) {
    final code = _currency.displayCurrency;
    return _currency.format(_currency.fromYer(yer, currency: code), currency: code);
  }

  Future<List<Supplier>> _loadSuppliers() {
    return ref.read(suppliersDaoProvider).search(_search);
  }

  double get _totalOwedToSuppliers =>
      0; // يحسب من بيانات الموردين داخل FutureBuilder

  Future<void> _showForm([Supplier? supplier]) async {
    final name = TextEditingController(text: supplier?.name ?? '');
    final phone = TextEditingController(text: supplier?.phone ?? '');
    final address = TextEditingController(text: supplier?.address ?? '');
    final email = TextEditingController(text: supplier?.email ?? '');
    final opening = TextEditingController(
      text: supplier == null
          ? '0'
          : _currency.fromYer(supplier.openingBalance, currency: _currency.displayCurrency).toStringAsFixed(2),
    );
    final formKey = GlobalKey<FormState>();

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(supplier == null ? 'إضافة مورد' : 'تعديل المورد'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'اسم المورد',
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
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
                      controller: email,
                      decoration: const InputDecoration(
                        labelText: 'البريد الإلكتروني',
                      ),
                    ),
                    if (supplier == null)
                      TextFormField(
                        controller: opening,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: 'رصيد افتتاحي مستحق للمورد (${_currency.symbol()})',
                          helperText: 'هذا المبلغ يمثل: في ذمتي للمورد',
                        ),
                        validator: (v) {
                          final value = double.tryParse(v?.trim() ?? '');
                          if (value == null || value < 0) {
                            return 'المبلغ يجب أن يكون صفرًا أو أكبر';
                          }
                          return null;
                        },
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
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;

                final service = ref.read(supplierServiceProvider);
                final openingValue = _currency.toYer(
                  double.tryParse(opening.text) ?? 0,
                  currency: _currency.displayCurrency,
                );

                if (supplier == null) {
                  await service.create(
                    name: name.text,
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    address: address.text.trim().isEmpty
                        ? null
                        : address.text.trim(),
                    email: email.text.trim().isEmpty
                        ? null
                        : email.text.trim(),
                    openingBalance: openingValue,
                  );
                } else {
                  await service.update(
                    supplier,
                    name: name.text,
                    phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                    address: address.text.trim().isEmpty
                        ? null
                        : address.text.trim(),
                    email: email.text.trim().isEmpty
                        ? null
                        : email.text.trim(),
                  );
                }

                if (context.mounted) Navigator.pop(context, true);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );

      if (result == true && mounted) setState(() {});
    } finally {
      name.dispose();
      phone.dispose();
      address.dispose();
      email.dispose();
      opening.dispose();
    }
  }

  Future<double> _paymentAmount(Supplier supplier) async {
    final controller = TextEditingController();

    final result = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سداد للمورد ${supplier.name}'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'قيمة الدفعة (${_currency.symbol()})',
            helperText:
                'المبلغ في ذمتي للمورد: ${_money(supplier.currentBalance)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
            final value = double.tryParse(controller.text) ?? 0;
            final displayBalance = _currency.fromYer(
              supplier.currentBalance,
              currency: _currency.displayCurrency,
            );
            if (value <= 0 || value > displayBalance) return;
            Navigator.pop(
              context,
              _currency.toYer(value, currency: _currency.displayCurrency),
            );
          },
            child: const Text('تسجيل'),
          ),
        ],
      ),
    );

    controller.dispose();
    return result ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الموردون — في ذمتي للموردين'),
          actions: [
            IconButton(
              onPressed: () => _showForm(),
              icon: const Icon(Icons.add),
              tooltip: 'إضافة مورد',
            ),
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: FutureBuilder<List<Supplier>>(
          future: _loadSuppliers(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('تعذر تحميل الموردين: ${snapshot.error}'),
              );
            }

            final suppliers = snapshot.data ?? [];
            final totalOwed = suppliers.fold<double>(
              0,
              (sum, supplier) => sum + supplier.currentBalance,
            );

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        children: [
                          const Icon(Icons.account_balance_outlined),
                          const SizedBox(width: 10),
                          const Text(
                            'إجمالي المبالغ في ذمتي للموردين:',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _money(totalOwed),
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
                  const SizedBox(height: 16),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _search = value),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'بحث بالاسم أو الهاتف أو البريد',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: suppliers.isEmpty
                        ? const Center(child: Text('لا يوجد موردون'))
                        : ListView.separated(
                            itemCount: suppliers.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, index) {
                              final supplier = suppliers[index];

                              return ListTile(
                                leading: const CircleAvatar(
                                  child: Icon(Icons.local_shipping),
                                ),
                                title: Text(supplier.name),
                                subtitle: Text(
                                  '${supplier.phone ?? 'بدون هاتف'}\n'
                                  'في ذمتي للمورد: '
                                  '${_money(supplier.currentBalance)}',
                                ),
                                isThreeLine: true,
                                trailing: Wrap(
                                  children: [
                                    IconButton(
                                      tooltip: 'تعديل',
                                      onPressed: () => _showForm(supplier),
                                      icon: const Icon(Icons.edit_outlined),
                                    ),
                                    IconButton(
                                      tooltip: 'سداد للمورد',
                                      onPressed: () async {
                                        final amount =
                                            await _paymentAmount(supplier);
                                        if (amount <= 0) return;

                                        try {
                                          await ref
                                              .read(supplierServiceProvider)
                                              .recordPayment(
                                                supplierId: supplier.id,
                                                amount: amount,
                                              );

                                          if (mounted) setState(() {});
                                        } catch (error) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  error.toString(),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(
                                        Icons.payments_outlined,
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'تعطيل',
                                      onPressed: () async {
                                        try {
                                          await ref
                                              .read(supplierServiceProvider)
                                              .deactivate(supplier.id);

                                          if (mounted) setState(() {});
                                        } catch (error) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  error.toString(),
                                                ),
                                              ),
                                            );
                                          }
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
