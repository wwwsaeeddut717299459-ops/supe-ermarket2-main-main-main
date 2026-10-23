import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../database/app_database.dart';
import '../../../database/daos/customer_transactions_dao.dart';
import '../../../services/accounting_service.dart';

import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
class CustomersDebtsPage
    extends ConsumerStatefulWidget {
  const CustomersDebtsPage({
    super.key,
  });

  @override

  ConsumerState<CustomersDebtsPage>
      createState() =>
          _CustomersDebtsPageState();
}

class _CustomersDebtsPageState
    extends ConsumerState<CustomersDebtsPage> {
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

  String _money(double yer) {
    final code = _currency.displayCurrency;
    return _currency.format(_currency.fromYer(yer, currency: code), currency: code);
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final customersDao =
        ref.watch(customersDaoProvider);

    final transactionsDao =
        ref.watch(
          customerTransactionsDaoProvider,
        );

    return Scaffold(
      appBar: AppBar(
        title:
            const Text('إدارة العملاء والمدينين'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<
          List<Customer>>(
        future: customersDao.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'حدث خطأ: ${snapshot.error}',
              ),
            );
          }

          final customers =
              snapshot.data ?? [];

          return _buildPage(
            customers,
            transactionsDao,
          );
        },
      ),
    );
  }

  Widget _buildPage(
    List<Customer> customers,
    CustomerTransactionsDao transactionsDao,
  ) {
    final filtered = customers.where((customer) {
      final query =
          _search.trim().toLowerCase();

      if (query.isEmpty) {
        return true;
      }

      return customer.name
              .toLowerCase()
              .contains(query) ||
          (customer.phone ?? '')
              .contains(query);
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          TextField(
            onChanged: (value) {
              setState(() {
                _search = value;
              });
            },
            decoration: const InputDecoration(
              hintText:
                  'ابحث باسم العميل أو الهاتف...',
              prefixIcon:
                  Icon(Icons.search),
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 20),

          Expanded(
            child: FutureBuilder<
                Map<int, double>>(
              future:
                  transactionsDao
                      .getAllCustomerDebts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child:
                        CircularProgressIndicator(),
                  );
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'حدث خطأ: ${snapshot.error}',
                    ),
                  );
                }

                final debts =
                    snapshot.data ?? {};

                return _buildTable(
                  filtered,
                  debts,
                  transactionsDao,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTable(
    List<Customer> customers,
    Map<int, double> debts,
    CustomerTransactionsDao dao,
  ) {
    if (customers.isEmpty) {
      return const Center(
        child: Text(
          'لا يوجد عملاء',
          style: TextStyle(
            fontSize: 18,
          ),
        ),
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection:
              Axis.horizontal,
          child: DataTable(
            columnSpacing: 35,
            columns: const [
              DataColumn(
                label: Text('الرقم'),
              ),
              DataColumn(
                label: Text('العميل'),
              ),
              DataColumn(
                label: Text('الهاتف'),
              ),
              DataColumn(
                label: Text('العنوان'),
              ),
              DataColumn(
                label: Text('الدين'),
              ),
              DataColumn(
                label: Text('الإجراءات'),
              ),
            ],
            rows: customers.map((customer) {
              final debt =
                  debts[customer.id] ?? 0;

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      customer.id.toString(),
                    ),
                  ),

                  DataCell(
                    Text(customer.name),
                  ),

                  DataCell(
                    Text(
                      customer.phone ??
                          '—',
                    ),
                  ),

                  DataCell(
                    Text(
                      customer.address ??
                          '—',
                    ),
                  ),

                  DataCell(
                    Text(
                      debt > 0
                          ? _formatMoney(debt)
                          : 'لا يوجد دين',
                      style: TextStyle(
                        color: debt > 0
                            ? Colors.red
                            : Colors.green,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  DataCell(
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip:
                              'سجل الحركات',
                          onPressed: () =>
                              _showTransactions(
                            customer,
                            dao,
                          ),
                          icon: const Icon(
                            Icons.history,
                          ),
                        ),

                        if (debt > 0)
                          FilledButton.icon(
                            onPressed: () =>
                                _showPaymentDialog(
                              customer,
                              debt,
                              dao,
                            ),
                            icon: const Icon(
                              Icons
                                  .payments,
                            ),
                            label:
                                const Text(
                              'سداد',
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showPaymentDialog(
    Customer customer,
    double debt,
    CustomerTransactionsDao dao,
  ) async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'سداد دين ${customer.name}',
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(
              decimal: true,
            ),
            decoration:
                InputDecoration(
              labelText: 'المبلغ (${_currency.symbol()})',
              hintText:
                  'الدين الحالي: ${_formatMoney(debt)}',
              border:
                  const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final amount =
                    double.tryParse(
                  controller.text.trim(),
                );

                if (amount == null ||
                    amount <= 0) {
                  return;
                }

                final displayDebt = _currency.fromYer(
                  debt,
                  currency: _currency.displayCurrency,
                );

                if (amount > displayDebt) {
                  return;
                }

                Navigator.pop(
                  context,
                  _currency.toYer(
                    amount,
                    currency: _currency.displayCurrency,
                  ),
                );
              },
              child: const Text('سداد'),
            ),
          ],
        );
      },
    );

    controller.dispose();

    if (result == null) {
      return;
    }

    try {
      await ref.read(databaseProvider).transaction(() async {
        final currentDebt =
            await dao.getCustomerDebt(customer.id);

        if (result > currentDebt + 0.01) {
          throw Exception('المبلغ أكبر من الدين الحالي');
        }

        await dao.insertTransaction(
          CustomerTransactionsCompanion.insert(
            customerId: customer.id,
            type: 'payment',
            amount: Value(result),
            notes: Value('سداد دين العميل ${customer.name}'),
          ),
        );

        await AccountingService(
          ref.read(databaseProvider),
        ).rebuildInTransaction();
      });

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
              Text('تم تسجيل السداد بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content:
              Text('حدث خطأ: $e'),
        ),
      );
    }
  }

  Future<void> _showTransactions(
    Customer customer,
    CustomerTransactionsDao dao,
  ) async {
    final transactions =
        await dao.getByCustomerId(
      customer.id,
    );

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'سجل ${customer.name}',
          ),
          content: SizedBox(
            width: 600,
            height: 450,
            child: transactions.isEmpty
                ? const Center(
                    child: Text(
                      'لا توجد حركات',
                    ),
                  )
                : ListView.separated(
                    itemCount:
                        transactions.length,
                    separatorBuilder:
                        (_, __) =>
                            const Divider(),
                    itemBuilder:
                        (context, index) {
                      final item =
                          transactions[
                              index];

                      final isSale =
                          item.type ==
                              'credit_sale';

                      final isPayment =
                          item.type ==
                              'payment';

                      String title;

                      if (isSale) {
                        title =
                            'بيع آجل';
                      } else if (isPayment) {
                        title =
                            'سداد';
                      } else {
                        title =
                            'مرتجع بيع';
                      }

                      return ListTile(
                        leading: Icon(
                          isPayment
                              ? Icons
                                  .payments
                              : Icons
                                  .receipt_long,
                          color: isPayment
                              ? Colors.green
                              : Colors.red,
                        ),
                        title:
                            Text(title),
                        subtitle:
                            Text(
                          _formatDate(
                            item.createdAt,
                          ),
                        ),
                        trailing:
                            Text(
                          _formatMoney(
                            item.amount,
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(context),
              child:
                  const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  String _formatMoney(double value) {
    if (value == value.roundToDouble()) {
      return '${value.toInt()}';
    }

    return _money(value);
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}