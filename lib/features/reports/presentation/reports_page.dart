import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:file_selector/file_selector.dart';
import 'package:excel/excel.dart' as ex;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/database_providers.dart';
import '../../../services/detailed_reports_service.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';

class ReportsPage extends ConsumerStatefulWidget {
  const ReportsPage({super.key});

  @override
  ConsumerState<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends ConsumerState<ReportsPage> {
  ReportPeriod _period = ReportPeriod.daily;
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  DateTime _to = DateTime.now().add(const Duration(days: 1));
  late Future<DetailedReport> _report;
  late final CurrencyService _currency;
  bool _currencyReady = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrencyAndReport();
  }

  Future<void> _loadCurrencyAndReport() async {
    await _currency.load();
    if (!mounted) return;
    setState(() {
      _currencyReady = true;
      _load();
    });
  }

  void _load() {
    _report = ref.read(detailedReportsServiceProvider).build(
      from: _from,
      to: _to,
      period: _period,
    );
  }

  void _refresh() => setState(_load);

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

  String _periodName(ReportPeriod period) => switch (period) {
    ReportPeriod.daily => 'اليومي',
    ReportPeriod.weekly => 'الأسبوعي',
    ReportPeriod.monthly => 'الشهري',
    ReportPeriod.yearly => 'السنوي',
  };

  String _money(double value) => _currency.format(value, currency: 'YER');
  String _sar(double value) => _currency.format(
        _currency.fromYer(value, currency: 'SAR'),
        currency: 'SAR',
      );


  String _fileDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _exportExcel(DetailedReport report) async {
    try {
      final excel = ex.Excel.createExcel();
      final sheet = excel['التقرير'];
      excel.delete('Sheet1');

      sheet.appendRow([
        ex.TextCellValue('مركز التقارير والتحليل'),
      ]);
      sheet.appendRow([
        ex.TextCellValue('من'),
        ex.TextCellValue(_fileDate(report.from)),
        ex.TextCellValue('إلى'),
        ex.TextCellValue(_fileDate(report.to.subtract(const Duration(days: 1)))),
      ]);
      sheet.appendRow([]);

      final summary = report.summary;
      final netSales = summary.sales - summary.saleReturns;
      sheet.appendRow([ex.TextCellValue('المؤشر'), ex.TextCellValue('القيمة')]);
      for (final row in [
        ['إجمالي المبيعات', summary.sales],
        ['مرتجعات المبيعات', summary.saleReturns],
        ['صافي المبيعات', netSales],
        ['إجمالي المشتريات', summary.purchases],
        ['مرتجعات المشتريات', summary.purchaseReturns],
        ['تكلفة البضاعة', summary.cogs],
        ['المصروفات', summary.expenses],
        ['صافي الربح', summary.netProfit],
      ]) {
        sheet.appendRow([
          ex.TextCellValue(row[0] as String),
          ex.DoubleCellValue((row[1] as num).toDouble()),
        ]);
      }

      sheet.appendRow([]);
      sheet.appendRow([
        ex.TextCellValue('التفصيل الزمني'),
      ]);
      sheet.appendRow([
        ex.TextCellValue('الفترة'),
        ex.TextCellValue('المبيعات'),
        ex.TextCellValue('المرتجعات'),
        ex.TextCellValue('المشتريات'),
        ex.TextCellValue('التكلفة'),
        ex.TextCellValue('المصروفات'),
        ex.TextCellValue('الربح'),
      ]);
      for (final r in report.rows) {
        sheet.appendRow([
          ex.TextCellValue(r.label),
          ex.DoubleCellValue(r.sales),
          ex.DoubleCellValue(r.saleReturns),
          ex.DoubleCellValue(r.purchases),
          ex.DoubleCellValue(r.cogs),
          ex.DoubleCellValue(r.expenses),
          ex.DoubleCellValue(r.netProfit),
        ]);
      }

      final products = excel['أفضل المنتجات'];
      products.appendRow([
        ex.TextCellValue('المنتج'),
        ex.TextCellValue('الكمية'),
        ex.TextCellValue('الإيراد'),
        ex.TextCellValue('التكلفة'),
        ex.TextCellValue('الربح'),
        ex.TextCellValue('الهامش %'),
      ]);
      for (final p in report.topProducts) {
        products.appendRow([
          ex.TextCellValue(p.name),
          ex.DoubleCellValue(p.quantity),
          ex.DoubleCellValue(p.revenue),
          ex.DoubleCellValue(p.cost),
          ex.DoubleCellValue(p.profit),
          ex.DoubleCellValue(p.margin),
        ]);
      }

      final bytes = excel.save();
      if (bytes == null || bytes.isEmpty) {
        throw Exception('تعذر إنشاء ملف ex.Excel');
      }

      final location = await getSaveLocation(
        suggestedName: 'تقرير_${_fileDate(report.from)}_${_fileDate(report.to.subtract(const Duration(days: 1)))}.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(
            label: 'ex.Excel',
            extensions: ['xlsx'],
          ),
        ],
      );
      if (location == null) return;

      await XFile.fromData(
        Uint8List.fromList(bytes),
        name: 'report.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      ).saveTo(location.path);

      if (mounted) {
        _showExportMessage('تم حفظ تقرير ex.Excel بنجاح');
      }
    } catch (e) {
      if (mounted) _showExportMessage('تعذر تصدير ex.Excel: $e', error: true);
    }
  }

  Future<void> _exportPdf(DetailedReport report) async {
    try {
      final fontData = await rootBundle.load('assets/fonts/DejaVuSans.ttf');
      final boldData = await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf');
      final font = pw.Font.ttf(fontData);
      final bold = pw.Font.ttf(boldData);

      final pdf = pw.Document();
      final s = report.summary;
      final netSales = s.sales - s.saleReturns;

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          theme: pw.ThemeData.withFont(base: font, bold: bold),
          textDirection: pw.TextDirection.rtl,
          header: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(bottom: 12),
            child: pw.Text(
              'تقرير المبيعات والتحليل المالي',
              style: pw.TextStyle(font: bold, fontSize: 18),
            ),
          ),
          build: (context) => [
            pw.Text(
              'الفترة: ${_fileDate(report.from)} إلى ${_fileDate(report.to.subtract(const Duration(days: 1)))}',
              style: pw.TextStyle(font: bold, fontSize: 11),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['المؤشر', 'القيمة'],
              data: [
                ['إجمالي المبيعات', _money(s.sales)],
                ['مرتجعات المبيعات', _money(s.saleReturns)],
                ['صافي المبيعات', _money(netSales)],
                ['إجمالي المشتريات', _money(s.purchases)],
                ['مرتجعات المشتريات', _money(s.purchaseReturns)],
                ['تكلفة البضاعة', _money(s.cogs)],
                ['المصروفات', _money(s.expenses)],
                ['صافي الربح', _money(s.netProfit)],
              ],
              headerStyle: pw.TextStyle(font: bold, fontSize: 9),
              cellStyle: pw.TextStyle(font: font, fontSize: 8),
              cellAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 18),
            pw.Text('التفصيل الزمني', style: pw.TextStyle(font: bold, fontSize: 14)),
            pw.SizedBox(height: 7),
            pw.Table.fromTextArray(
              headers: ['الفترة', 'المبيعات', 'المرتجعات', 'المشتريات', 'التكلفة', 'المصروفات', 'الربح'],
              data: report.rows.map((r) => [
                r.label,
                _money(r.sales),
                _money(r.saleReturns),
                _money(r.purchases),
                _money(r.cogs),
                _money(r.expenses),
                _money(r.netProfit),
              ]).toList(),
              headerStyle: pw.TextStyle(font: bold, fontSize: 7),
              cellStyle: pw.TextStyle(font: font, fontSize: 6.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.2),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.2),
                3: const pw.FlexColumnWidth(1.2),
                4: const pw.FlexColumnWidth(1.2),
                5: const pw.FlexColumnWidth(1.2),
                6: const pw.FlexColumnWidth(1.2),
              },
              cellAlignment: pw.Alignment.centerRight,
            ),
            pw.SizedBox(height: 18),
            pw.Text('أفضل المنتجات أداءً', style: pw.TextStyle(font: bold, fontSize: 14)),
            pw.SizedBox(height: 7),
            pw.Table.fromTextArray(
              headers: ['المنتج', 'الكمية', 'الإيراد', 'التكلفة', 'الربح', 'الهامش'],
              data: report.topProducts.map((p) => [
                p.name,
                p.quantity.toStringAsFixed(p.quantity % 1 == 0 ? 0 : 2),
                _money(p.revenue),
                _money(p.cost),
                _money(p.profit),
                '${p.margin.toStringAsFixed(1)}%',
              ]).toList(),
              headerStyle: pw.TextStyle(font: bold, fontSize: 7),
              cellStyle: pw.TextStyle(font: font, fontSize: 6.5),
              cellAlignment: pw.Alignment.centerRight,
              columnWidths: {
                0: const pw.FlexColumnWidth(2.5),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.3),
                3: const pw.FlexColumnWidth(1.3),
                4: const pw.FlexColumnWidth(1.3),
                5: const pw.FlexColumnWidth(1),
              },
            ),
          ],
        ),
      );

      final bytes = await pdf.save();
      final location = await getSaveLocation(
        suggestedName: 'تقرير_${_fileDate(report.from)}_${_fileDate(report.to.subtract(const Duration(days: 1)))}.pdf',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'PDF', extensions: ['pdf']),
        ],
      );
      if (location == null) return;

      await XFile.fromData(
        bytes,
        name: 'report.pdf',
        mimeType: 'application/pdf',
      ).saveTo(location.path);

      if (mounted) _showExportMessage('تم حفظ تقرير PDF بنجاح');
    } catch (e) {
      if (mounted) _showExportMessage('تعذر تصدير PDF: $e', error: true);
    }
  }

  void _showExportMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('مركز التقارير والتحليل'),
        actions: [
          IconButton(
            tooltip: 'اختيار الفترة',
            onPressed: _pickRange,
            icon: const Icon(Icons.date_range_rounded),
          ),
          IconButton(
            tooltip: 'تحديث البيانات',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          FutureBuilder<DetailedReport>(
            future: _report,
            builder: (context, snapshot) {
              final ready = snapshot.hasData && !snapshot.hasError;
              return Row(
                children: [
                  IconButton(
                    tooltip: 'تصدير PDF',
                    onPressed: ready ? () => _exportPdf(snapshot.data!) : null,
                    icon: const Icon(Icons.picture_as_pdf_rounded),
                  ),
                  IconButton(
                    tooltip: 'تصدير ex.Excel',
                    onPressed: ready ? () => _exportExcel(snapshot.data!) : null,
                    icon: const Icon(Icons.table_view_rounded),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: !_currencyReady
          ? const Center(child: CircularProgressIndicator())
          : FutureBuilder<DetailedReport>(
        future: _report,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('تعذر إعداد التقرير: ${snapshot.error}'));
          }
          final report = snapshot.data;
          if (report == null) return const Center(child: Text('لا توجد بيانات'));

          final s = report.summary;
          final netSales = s.sales - s.saleReturns;
          final gross = s.grossProfit;
          final margin = netSales == 0 ? 0.0 : (gross / netSales) * 100;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _hero(context, report, netSales, margin),
                const SizedBox(height: 18),
                _periodSelector(context),
                const SizedBox(height: 18),
                _summaryGrid(context, s, netSales, margin),
                const SizedBox(height: 12),
                _currencyReportCard(context, s, netSales),
                const SizedBox(height: 18),
                _profitCard(context, s, netSales),
                const SizedBox(height: 18),
                _trendCard(context, report.rows),
                const SizedBox(height: 18),
                _topProductsCard(context, report.topProducts),
                const SizedBox(height: 18),
                _expenseCard(context, report.expensesByCategory),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(BuildContext context, DetailedReport report, double netSales, double margin) {
    final cs = Theme.of(context).colorScheme;
    final start = report.from.toLocal().toString().split(' ').first;
    final end = report.to.subtract(const Duration(days: 1)).toLocal().toString().split(' ').first;
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer, cs.surfaceContainerHigh],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 66,
            height: 66,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.analytics_rounded, color: cs.onPrimary, size: 34),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة التحليل المالي',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text('تقرير ${_periodName(_period)} من $start إلى $end'),
              ],
            ),
          ),
          _miniStat(context, 'صافي المبيعات', _money(netSales)),
          const SizedBox(width: 10),
          _miniStat(context, 'هامش الربح', '${margin.toStringAsFixed(1)}%'),
        ],
      ),
    );
  }

  Widget _miniStat(BuildContext context, String title, String value) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surface.withAlpha(220),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          Text(title, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _periodSelector(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SegmentedButton<ReportPeriod>(
          segments: const [
            ButtonSegment(value: ReportPeriod.daily, label: Text('يومي'), icon: Icon(Icons.today_rounded)),
            ButtonSegment(value: ReportPeriod.weekly, label: Text('أسبوعي'), icon: Icon(Icons.view_week_rounded)),
            ButtonSegment(value: ReportPeriod.monthly, label: Text('شهري'), icon: Icon(Icons.calendar_month_rounded)),
            ButtonSegment(value: ReportPeriod.yearly, label: Text('سنوي'), icon: Icon(Icons.calendar_today_rounded)),
          ],
          selected: {_period},
          onSelectionChanged: (value) => setState(() {
            _period = value.first;
            _load();
          }),
        ),
      ),
    );
  }

  Widget _summaryGrid(BuildContext context, dynamic s, double netSales, double margin) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width > 1350 ? 4 : width > 850 ? 3 : 2;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: columns,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.15,
      children: [
        _metric(context, 'إجمالي المبيعات', s.sales, Icons.point_of_sale_rounded),
        _metric(context, 'مرتجعات المبيعات', s.saleReturns, Icons.assignment_return_rounded),
        _metric(context, 'صافي المبيعات', netSales, Icons.trending_up_rounded),
        _metric(context, 'إجمالي المشتريات', s.purchases, Icons.shopping_cart_rounded),
        _metric(context, 'مرتجعات المشتريات', s.purchaseReturns, Icons.undo_rounded),
        _metric(context, 'تكلفة البضاعة', s.cogs, Icons.inventory_2_rounded),
        _metric(context, 'إجمالي المصروفات', s.expenses, Icons.money_off_rounded),
        _metric(context, 'صافي الربح', s.netProfit, Icons.account_balance_rounded),
      ],
    );
  }

  Widget _metric(BuildContext context, String title, double value, IconData icon) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: cs.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 5),
                  Text(
                    _money(value),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(
                    _sar(value),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
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

  Widget _currencyReportCard(BuildContext context, dynamic s, double netSales) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Icon(Icons.currency_exchange_rounded, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'سعر الصرف الحالي: 1 ر.س = ${_currency.sarToYer.toStringAsFixed(2)} ر.ي',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              'صافي المبيعات: ${_money(netSales)} / ${_sar(netSales)}',
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _profitCard(BuildContext context, dynamic s, double netSales) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.insights_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Text('ملخص الأداء والربحية', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 18),
            _line('صافي المبيعات', netSales),
            _line('تكلفة البضاعة المباعة', -s.cogs),
            _line('مجمل الربح', s.grossProfit),
            _line('المصروفات التشغيلية', -s.expenses),
            const Divider(height: 28),
            _line('صافي الربح', s.netProfit, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _line(String title, double value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(title, style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w500))),
          Text(_money(value), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _trendCard(BuildContext context, List<PeriodicReportRow> rows) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.table_chart_rounded),
                const SizedBox(width: 10),
                Text('التفصيل الزمني', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 15),
            if (rows.isEmpty)
              const Text('لا توجد بيانات للفترة المحددة.')
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الفترة')),
                    DataColumn(label: Text('المبيعات')),
                    DataColumn(label: Text('المرتجعات')),
                    DataColumn(label: Text('المشتريات')),
                    DataColumn(label: Text('التكلفة')),
                    DataColumn(label: Text('المصروفات')),
                    DataColumn(label: Text('الربح')),
                  ],
                  rows: rows.map((r) => DataRow(cells: [
                    DataCell(Text(r.label)),
                    DataCell(Text(_money(r.sales))),
                    DataCell(Text(_money(r.saleReturns))),
                    DataCell(Text(_money(r.purchases))),
                    DataCell(Text(_money(r.cogs))),
                    DataCell(Text(_money(r.expenses))),
                    DataCell(Text(_money(r.netProfit), style: const TextStyle(fontWeight: FontWeight.w800))),
                  ])).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _topProductsCard(BuildContext context, List<TopProductReportRow> products) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events_rounded),
                const SizedBox(width: 10),
                Text('أفضل المنتجات أداءً', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 15),
            if (products.isEmpty)
              const Text('لا توجد مبيعات في الفترة المحددة.')
            else
              ...products.asMap().entries.map((entry) {
                final index = entry.key + 1;
                final product = entry.value;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 15, child: Text('$index')),
                      const SizedBox(width: 12),
                      Expanded(child: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('كمية ${product.quantity.toStringAsFixed(product.quantity % 1 == 0 ? 0 : 2)}'),
                      const SizedBox(width: 18),
                      Text(_money(product.revenue)),
                      const SizedBox(width: 18),
                      Text('${product.margin.toStringAsFixed(1)}% هامش', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _expenseCard(BuildContext context, Map<String, double> values) {
    final max = values.isEmpty ? 1.0 : values.values.reduce((a, b) => a > b ? a : b);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_rounded),
                const SizedBox(width: 10),
                Text('تحليل المصروفات حسب التصنيف', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
              ],
            ),
            const SizedBox(height: 14),
            if (values.isEmpty)
              const Text('لا توجد مصروفات في الفترة المحددة.')
            else
              ...values.entries.map((entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(entry.key)),
                        Text(_money(entry.value), style: const TextStyle(fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(value: max == 0 ? 0 : entry.value / max, minHeight: 7),
                  ],
                ),
              )),
          ],
        ),
      ),
    );
  }
}
