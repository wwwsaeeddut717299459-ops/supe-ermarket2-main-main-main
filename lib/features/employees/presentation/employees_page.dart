import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
import '../../../services/employee_service.dart';
import '../../auth/auth_providers.dart';

class EmployeesPage extends ConsumerStatefulWidget {
  const EmployeesPage({super.key});
  @override
  ConsumerState<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends ConsumerState<EmployeesPage> {
  String q = '';
  late CurrencyService currency;
  bool ready = false;

  @override
  void initState() {
    super.initState();
    currency = ref.read(currencyServiceProvider);
    _init();
  }

  Future<void> _init() async {
    await currency.load();
    if (mounted) setState(() => ready = true);
  }

  String money(double v) => currency.format(
        currency.fromYer(v),
        currency: currency.displayCurrency,
      );

  Future<void> _edit([EmployeeRecord? e]) async {
    final name = TextEditingController(text: e?.name ?? '');
    final job = TextEditingController(text: e?.jobTitle ?? '');
    final phone = TextEditingController(text: e?.phone ?? '');
    final salary = TextEditingController(
      text: e == null ? '' : currency.fromYer(e.salary).toStringAsFixed(2),
    );
    final notes = TextEditingController(text: e?.notes ?? '');
    bool active = e?.isActive ?? true;
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(e == null ? 'موظف جديد' : 'تعديل الموظف'),
          content: SizedBox(
            width: 460,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(labelText: 'اسم الموظف'),
                      validator: (v) => v!.trim().isEmpty ? 'الاسم مطلوب' : null,
                    ),
                    TextFormField(
                      controller: job,
                      decoration: const InputDecoration(labelText: 'الوظيفة'),
                    ),
                    TextFormField(
                      controller: phone,
                      decoration: const InputDecoration(labelText: 'الهاتف'),
                    ),
                    TextFormField(
                      controller: salary,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'الراتب (${currency.symbol()})'),
                      validator: (v) => double.tryParse(v ?? '') == null
                          ? 'قيمة غير صحيحة'
                          : null,
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'ملاحظات'),
                    ),
                    if (e != null)
                      SwitchListTile(
                        value: active,
                        onChanged: (value) => setDialogState(() => active = value),
                        title: const Text('الموظف نشط'),
                      ),
                  ],
                ),
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
                final service = ref.read(employeeServiceProvider);
                final salaryYer = currency.toYer(double.parse(salary.text));
                if (e == null) {
                  await service.add(
                    name: name.text,
                    jobTitle: job.text,
                    phone: phone.text,
                    salary: salaryYer,
                    notes: notes.text,
                  );
                } else {
                  await service.update(
                    e.id,
                    name: name.text,
                    jobTitle: job.text,
                    phone: phone.text,
                    salary: salaryYer,
                    hireDate: e.hireDate,
                    isActive: active,
                    notes: notes.text,
                  );
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );

    for (final controller in [name, job, phone, salary, notes]) {
      controller.dispose();
    }
  }

  Future<void> _move(EmployeeRecord e) async {
    String type = 'salary';
    final amount = TextEditingController(
      text: currency.fromYer(e.salary).toStringAsFixed(2),
    );
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('حركة مالية • ${e.name}'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: type,
                  items: const [
                    DropdownMenuItem(value: 'salary', child: Text('راتب')),
                    DropdownMenuItem(value: 'advance', child: Text('سلفة')),
                    DropdownMenuItem(value: 'withdrawal', child: Text('سحب')),
                    DropdownMenuItem(value: 'payment', child: Text('صرف')),
                  ],
                  onChanged: (value) => setDialogState(() => type = value ?? type),
                ),
                TextFormField(
                  controller: amount,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(labelText: 'المبلغ (${currency.symbol()})'),
                  validator: (v) {
                    final value = double.tryParse(v ?? '');
                    return value == null || value <= 0 ? 'المبلغ غير صحيح' : null;
                  },
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'الوصف'),
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
                if (!formKey.currentState!.validate()) return;
                await ref.read(employeeServiceProvider).addTransaction(
                      employeeId: e.id,
                      type: type,
                      amount: currency.toYer(double.parse(amount.text)),
                      date: DateTime.now(),
                      description: description.text,
                      username: ref.read(authSessionProvider).currentUser?.username ?? 'النظام',
                    );
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              },
              child: const Text('تسجيل'),
            ),
          ],
        ),
      ),
    );
    amount.dispose();
    description.dispose();
  }

  Future<void> _history(EmployeeRecord e) async {
    final rows = await ref.read(employeeServiceProvider).transactions(e.id);
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              ListTile(
                title: Text('سجل ${e.name}'),
                subtitle: Text('الراتب ${money(e.salary)}'),
              ),
              const Divider(),
              Expanded(
                child: rows.isEmpty
                    ? const Center(child: Text('لا توجد حركات'))
                    : ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (_, i) {
                          final x = rows[i];
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.payments)),
                            title: Text(_transactionName(x.type)),
                            subtitle: Text('${x.date.toLocal()} • ${x.description}'),
                            trailing: Text(
                              money(x.amount),
                              style: const TextStyle(fontWeight: FontWeight.bold),
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

  String _transactionName(String type) => switch (type) {
        'salary' => 'راتب',
        'advance' => 'سلفة',
        'withdrawal' => 'سحب',
        'payment' => 'صرف',
        _ => 'حركة',
      };

  @override
  Widget build(BuildContext context) {
    if (!ready) return const Center(child: CircularProgressIndicator());
    final service = ref.watch(employeeServiceProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة الموظفين'),
          actions: [
            IconButton(
              onPressed: () => _edit(),
              icon: const Icon(Icons.person_add_alt_1_rounded),
            ),
            IconButton(
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: TextField(
                onChanged: (value) => setState(() => q = value),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search),
                  hintText: 'بحث بالاسم أو الوظيفة أو الهاتف',
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<EmployeeRecord>>(
                future: service.getAll(query: q),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final rows = snapshot.data ?? [];
                  if (rows.isEmpty) return const Center(child: Text('لا يوجد موظفون'));
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                    itemCount: rows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final e = rows[i];
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text(e.name.isEmpty ? '?' : e.name[0])),
                          title: Text(e.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            '${e.jobTitle.isEmpty ? 'بدون وظيفة' : e.jobTitle} • '
                            '${e.phone.isEmpty ? 'بدون هاتف' : e.phone}\n'
                            'الراتب: ${money(e.salary)}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'حركة مالية',
                                onPressed: () => _move(e),
                                icon: const Icon(Icons.payments_outlined),
                              ),
                              IconButton(
                                tooltip: 'السجل',
                                onPressed: () => _history(e),
                                icon: const Icon(Icons.history),
                              ),
                              IconButton(
                                tooltip: 'تعديل',
                                onPressed: () => _edit(e),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'تفعيل/تعطيل',
                                onPressed: () => service
                                    .setActive(e.id, !e.isActive)
                                    .then((_) => setState(() {})),
                                icon: Icon(e.isActive ? Icons.toggle_on : Icons.toggle_off),
                              ),
                            ],
                          ),
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
    );
  }
}
