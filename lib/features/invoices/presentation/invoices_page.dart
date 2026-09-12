import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/database_providers.dart';
import '../../../services/business_analytics_service.dart';

class InvoicesPage extends ConsumerStatefulWidget {
  final String initialType;
  final String title;

  const InvoicesPage({
    super.key,
    this.initialType = 'all',
    this.title = 'جميع الفواتير',
  });
  @override
  ConsumerState<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends ConsumerState<InvoicesPage> {
  String _type = 'all';
  late DateTime _from;
  late DateTime _to;
  late Future<List<InvoiceSummaryRow>> _invoices;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _type = widget.initialType;
    _from = DateTime(now.year, now.month, 1);
    _to = now.add(const Duration(days: 1));
    _load();
  }

  void _load() => _invoices = ref
      .read(businessAnalyticsServiceProvider)
      .invoices(from: _from, to: _to, type: _type);

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _from,
        end: _to.subtract(const Duration(days: 1)),
      ),
    );
    if (picked == null) return;
    setState(() {
      _from = DateTime(picked.start.year, picked.start.month, picked.start.day);
      _to = DateTime(picked.end.year, picked.end.month, picked.end.day + 1);
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          actions: [
            IconButton(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
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
              _filters(),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<InvoiceSummaryRow>>(
                  future: _invoices,
                  builder: (context, snapshot) => _body(snapshot),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(AsyncSnapshot<List<InvoiceSummaryRow>> snapshot) {
    if (snapshot.connectionState == ConnectionState.waiting)
      return const Center(child: CircularProgressIndicator());
    if (snapshot.hasError)
      return Center(child: Text('تعذر تحميل الفواتير: ${snapshot.error}'));
    final rows = snapshot.data ?? [];
    if (rows.isEmpty)
      return const Center(child: Text('لا توجد فواتير للفترة المحددة'));
    final sales = rows
        .where((row) => row.type == 'sale')
        .fold<double>(0, (sum, row) => sum + row.total);
    final purchases = rows
        .where((row) => row.type == 'purchase')
        .fold<double>(0, (sum, row) => sum + row.total);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          children: [
            Chip(label: Text('العدد: ${rows.length}')),
            Chip(label: Text('المبيعات: ${sales.toStringAsFixed(2)}')),
            Chip(label: Text('المشتريات: ${purchases.toStringAsFixed(2)}')),
          ],
        ),
        const SizedBox(height: 12),
        Expanded(child: _table(rows)),
      ],
    );
  }

  Widget _table(List<InvoiceSummaryRow> rows) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('النوع')),
            DataColumn(label: Text('رقم الفاتورة')),
            DataColumn(label: Text('التاريخ')),
            DataColumn(label: Text('الطرف')),
            DataColumn(label: Text('الدفع')),
            DataColumn(label: Text('الحالة')),
            DataColumn(label: Text('الإجمالي')),
          ],
          rows: rows
              .map(
                (row) => DataRow(
                  cells: [
                    DataCell(Text(row.type == 'sale' ? 'بيع' : 'شراء')),
                    DataCell(Text(row.invoiceNumber)),
                    DataCell(
                      Text(row.date.toLocal().toString().split('.').first),
                    ),
                    DataCell(Text(row.party)),
                    DataCell(Text(row.paymentMethod)),
                    DataCell(Text(_status(row.status))),
                    DataCell(Text(row.total.toStringAsFixed(2))),
                  ],
                ),
              )
              .toList(),
        ),
      ),
    );
  }

  Widget _filters() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          const Text('نوع الفاتورة:'),
          const SizedBox(width: 12),
          DropdownButton<String>(
            value: _type,
            items: [
              if (widget.initialType == 'all')
                const DropdownMenuItem(value: 'all', child: Text('الكل')),
              if (widget.initialType == 'all' || widget.initialType == 'sale')
                const DropdownMenuItem(value: 'sale', child: Text('مبيعات')),
              if (widget.initialType == 'all' ||
                  widget.initialType == 'purchase')
                const DropdownMenuItem(
                  value: 'purchase',
                  child: Text('مشتريات'),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _type = value;
                _load();
              });
            },
          ),
          const Spacer(),
          Text(
            'من ${_from.toLocal().toString().split(' ').first} إلى ${_to.subtract(const Duration(days: 1)).toLocal().toString().split(' ').first}',
          ),
        ],
      ),
    ),
  );
  String _status(String value) => switch (value) {
    'completed' => 'مكتملة',
    'cancelled' => 'ملغاة',
    'pending' => 'معلقة',
    _ => value,
  };
}
