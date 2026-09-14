import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
import '../../../services/audit_service.dart';
import '../../auth/auth_providers.dart';

class ExpensesPage extends ConsumerStatefulWidget {
  const ExpensesPage({super.key});

  @override
  ConsumerState<ExpensesPage> createState() => _ExpensesPageState();
}

class _ExpensesPageState extends ConsumerState<ExpensesPage> {
  String _search = '';
  late final CurrencyService _currency;
  bool _currencyReady = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (mounted) setState(() => _currencyReady = true);
  }

  double _toYer(double amount) => _currency.toYer(amount, currency: _currency.displayCurrency);
  String _money(double yer) => _currency.format(
    _currency.fromYer(yer, currency: _currency.displayCurrency),
    currency: _currency.displayCurrency,
  );

  Future<void> _addCategory() async {
    final name = TextEditingController();
    final description = TextEditingController();
    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('تصنيف مصروف جديد'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'الاسم'),
              ),
              TextField(
                controller: description,
                decoration: const InputDecoration(labelText: 'الوصف'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  await ref
                      .read(expenseServiceProvider)
                      .addCategory(name.text, description.text);
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) setState(() {});
                } catch (error) {
                  if (dialogContext.mounted)
                    ScaffoldMessenger.of(
                      dialogContext,
                    ).showSnackBar(SnackBar(content: Text(error.toString())));
                }
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally {
      name.dispose();
      description.dispose();
    }
  }

  Future<void> _addExpense() async {
    final categories = await ref.read(expenseCategoriesDaoProvider).getAll();
    if (categories.isEmpty) {
      await _addCategory();
      return;
    }
    final amount = TextEditingController();
    final description = TextEditingController();
    final notes = TextEditingController();
    final formKey = GlobalKey<FormState>();
    int categoryId = categories.first.id;
    String payment = 'cash';
    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('إضافة مصروف'),
            content: SizedBox(
              width: 440,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      value: categoryId,
                      decoration: const InputDecoration(labelText: 'التصنيف'),
                      items: categories
                          .map(
                            (category) => DropdownMenuItem(
                              value: category.id,
                              child: Text(category.name),
                            ),
                          )
                          .toList(),
                      onChanged: (value) => setDialogState(
                        () => categoryId = value ?? categoryId,
                      ),
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'القيمة (${_currency.displayCurrency == 'SAR' ? 'ر.س' : 'ر.ي'})'),
                      validator: (value) => double.tryParse(value ?? '') == null
                          ? 'أدخل قيمة صحيحة'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      value: payment,
                      decoration: const InputDecoration(
                        labelText: 'طريقة الدفع',
                      ),
                      items: const [
                        DropdownMenuItem(value: 'cash', child: Text('نقدي')),
                        DropdownMenuItem(
                          value: 'bank',
                          child: Text('تحويل بنكي'),
                        ),
                        DropdownMenuItem(value: 'credit', child: Text('آجل')),
                      ],
                      onChanged: (value) =>
                          setDialogState(() => payment = value ?? 'cash'),
                    ),
                    TextField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'الوصف'),
                    ),
                    TextField(
                      controller: notes,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    await ref
                        .read(expenseServiceProvider)
                        .addExpense(
                          categoryId: categoryId,
                          amount: _toYer(double.parse(amount.text)),
                          paymentMethod: payment,
                          date: DateTime.now(),
                          description: description.text.trim().isEmpty
                              ? null
                              : description.text.trim(),
                          notes: notes.text.trim().isEmpty
                              ? null
                              : notes.text.trim(),
                        );
                    await AuditService().log(
                      user: ref.read(authSessionProvider).currentUser?.username ?? 'غير معروف',
                      action: 'تسجيل مصروف',
                      details: 'القيمة ${amount.text.trim()} ${_currency.symbol()} • ${description.text.trim()}',
                    );
                    if (dialogContext.mounted) Navigator.pop(dialogContext);
                    if (mounted) setState(() {});
                  } catch (error) {
                    if (dialogContext.mounted)
                      ScaffoldMessenger.of(
                        dialogContext,
                      ).showSnackBar(SnackBar(content: Text(error.toString())));
                  }
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      );
    } finally {
      amount.dispose();
      description.dispose();
      notes.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(expensesDaoProvider);
    if (!_currencyReady) return const Center(child: CircularProgressIndicator());
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المصروفات'),
          actions: [
            IconButton(
              onPressed: _addCategory,
              icon: const Icon(Icons.category_outlined),
            ),
            IconButton(onPressed: _addExpense, icon: const Icon(Icons.add)),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              TextField(
                onChanged: (value) => setState(() => _search = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  labelText: 'بحث في المصروفات',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<Expense>>(
                  future: dao.search(_search),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting)
                      return const Center(child: CircularProgressIndicator());
                    if (snapshot.hasError)
                      return Center(
                        child: Text('تعذر تحميل المصروفات: ${snapshot.error}'),
                      );
                    final expenses = snapshot.data ?? [];
                    return ListView.separated(
                      itemCount: expenses.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final expense = expenses[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.money_off),
                          ),
                          title: Text(
                            expense.description?.isNotEmpty == true
                                ? expense.description!
                                : 'مصروف #${expense.id}',
                          ),
                          subtitle: Text(
                            '${expense.expenseDate.toLocal()}\nطريقة الدفع: ${expense.paymentMethod}',
                          ),
                          isThreeLine: true,
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _money(expense.amount),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  try {
                                    await ref
                                        .read(expenseServiceProvider)
                                        .deleteExpense(expense.id);
                                    if (mounted) setState(() {});
                                  } catch (error) {
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(error.toString())),
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
