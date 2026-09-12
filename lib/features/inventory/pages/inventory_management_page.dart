import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart'
    hide productsRepositoryProvider;
import '../../../services/business_analytics_service.dart';
import '../../products/products_provider.dart';

class InventoryManagementPage extends ConsumerStatefulWidget {
  const InventoryManagementPage({super.key});

  @override
  ConsumerState<InventoryManagementPage> createState() =>
      _InventoryManagementPageState();
}

class _InventoryManagementPageState
    extends ConsumerState<InventoryManagementPage> {
  int _filter = 0;

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المخزون'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'تحديث',
          ),
        ],
      ),
      body: FutureBuilder<List<Product>>(
        future: repository.getAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('حدث خطأ: ${snapshot.error}'));
          }

          final products = snapshot.data ?? [];

          return _buildContent(products);
        },
      ),
    );
  }

  Widget _buildContent(List<Product> products) {
    final lowStock = products.where((p) => p.stockQuantity <= p.minimumStock).toList();
    final expired = products.where((p) => _isExpired(p.expiryDate)).toList();
    final expiringSoon = products.where((p) => _isExpiringSoon(p.expiryDate)).toList();

    final visible = switch (_filter) {
      1 => lowStock,
      2 => expiringSoon,
      3 => expired,
      _ => products,
    };

    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 18),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [scheme.primary, scheme.primaryContainer],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.circular(22),
              boxShadow: [BoxShadow(color: scheme.primary.withValues(alpha: 0.14), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(color: scheme.onPrimary.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
                  child: Icon(Icons.inventory_2_rounded, color: scheme.onPrimary, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('مركز المخزون', style: TextStyle(color: scheme.onPrimary, fontSize: 24, fontWeight: FontWeight.w900)),
                      Text('نظرة سريعة على الكميات والصلاحية وحركة المنتجات', style: TextStyle(color: scheme.onPrimary.withValues(alpha: 0.82))),
                    ],
                  ),
                ),
                if (products.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(color: scheme.surface.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(12)),
                    child: Text('${products.length} منتج', style: TextStyle(color: scheme.onPrimary, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          _buildSummary(products.length, lowStock.length, expiringSoon.length, expired.length),
          const SizedBox(height: 14),
          _buildFilters(),
          const SizedBox(height: 14),
          SizedBox(height: 245, child: _buildInsights()),
          const SizedBox(height: 14),
          Expanded(child: visible.isEmpty ? _buildEmpty() : _buildTable(visible)),
        ],
      ),
    );
  }

  Widget _buildSummary(int total, int lowStock, int expiring, int expired) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 1050 ? 4 : width >= 700 ? 2 : 1;
        final gap = 10.0;
        final cardWidth = columns == 1 ? width : (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(width: cardWidth, child: _SummaryCard(title: 'إجمالي المنتجات', value: '$total', icon: Icons.inventory_2_rounded)),
            SizedBox(width: cardWidth, child: _SummaryCard(title: 'مخزون منخفض', value: '$lowStock', icon: Icons.warning_amber_rounded, color: Colors.orange)),
            SizedBox(width: cardWidth, child: _SummaryCard(title: 'قرب الانتهاء', value: '$expiring', icon: Icons.event_rounded, color: Colors.amber)),
            SizedBox(width: cardWidth, child: _SummaryCard(title: 'منتهي الصلاحية', value: '$expired', icon: Icons.dangerous_rounded, color: Colors.red)),
          ],
        );
      },
    );
  }

  Widget _buildInsights() {
    return FutureBuilder<List<InventoryInsight>>(
      future: ref.read(businessAnalyticsServiceProvider).inventoryInsights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError)
          return Card(
            child: Center(
              child: Text('تعذر تحميل تحليل حركة المنتجات: ${snapshot.error}'),
            ),
          );
        final insights = snapshot.data ?? [];
        final best = insights
            .where((item) => item.soldQuantity > 0)
            .take(8)
            .toList();
        final dormant = insights
            .where((item) => item.state == 'راكد')
            .take(8)
            .toList();
        final advice = ref
            .read(businessAnalyticsServiceProvider)
            .categoryAdvice(insights);
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تحليل حركة المخزون والنصائح',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: _insightList(
                          'الأكثر مبيعًا',
                          best,
                          Colors.green,
                        ),
                      ),
                      const VerticalDivider(),
                      Expanded(
                        child: _insightList(
                          'المنتجات الراكدة',
                          dormant,
                          Colors.red,
                        ),
                      ),
                      const VerticalDivider(),
                      Expanded(child: _adviceList(advice)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _insightList(String title, List<InventoryInsight> items, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: items.isEmpty
              ? const Text('لا توجد بيانات كافية')
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      title: Text(item.productName),
                      subtitle: Text(
                        '${item.category} — مباع: ${item.soldQuantity.toStringAsFixed(0)}',
                      ),
                      trailing: Text(item.profit.toStringAsFixed(2)),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _adviceList(Map<String, String> advice) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'نصائح حسب الفئة',
          style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: advice.isEmpty
              ? const Text('لا توجد فئات')
              : ListView(
                  children: advice.entries
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          title: Text(entry.key),
                          subtitle: Text(entry.value),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded, color: scheme.primary),
            const SizedBox(width: 8),
            const Text('عرض:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _filterChip('الكل', 0, Icons.apps_rounded),
                    _filterChip('مخزون منخفض', 1, Icons.warning_amber_rounded),
                    _filterChip('قرب الانتهاء', 2, Icons.event_rounded),
                    _filterChip('منتهي', 3, Icons.dangerous_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, int value, IconData icon) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 7),
      child: ChoiceChip(
        avatar: Icon(icon, size: 17),
        label: Text(label),
        selected: _filter == value,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Widget _buildTable(List<Product> products) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 52,
            dataRowMinHeight: 58,
            dataRowMaxHeight: 72,
            columnSpacing: 28,
            headingTextStyle: const TextStyle(fontWeight: FontWeight.w800),
            columns: const [
              DataColumn(label: Text('المنتج')),
              DataColumn(label: Text('الباركود')),
              DataColumn(label: Text('المخزون')),
              DataColumn(label: Text('الحد الأدنى')),
              DataColumn(label: Text('الصلاحية')),
              DataColumn(label: Text('الحالة')),
            ],
            rows: products.map((product) {
              final lowStock = product.stockQuantity <= product.minimumStock;

              final expired = _isExpired(product.expiryDate);

              final expiring = _isExpiringSoon(product.expiryDate);

              return DataRow(
                cells: [
                  DataCell(Text(product.name)),
                  DataCell(Text(product.barcode)),
                  DataCell(
                    Text('${_format(product.stockQuantity)} ${product.unit}'),
                  ),
                  DataCell(Text(_format(product.minimumStock))),
                  DataCell(_expiryWidget(product.expiryDate)),
                  DataCell(
                    Wrap(
                      spacing: 5,
                      children: [
                        if (lowStock)
                          const Chip(
                            label: Text('مخزون منخفض'),
                            avatar: Icon(Icons.warning, size: 16),
                          ),
                        if (expired)
                          const Chip(
                            label: Text('منتهي'),
                            avatar: Icon(Icons.dangerous, size: 16),
                          )
                        else if (expiring)
                          const Chip(
                            label: Text('قرب الانتهاء'),
                            avatar: Icon(Icons.event, size: 16),
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

  Widget _expiryWidget(DateTime? date) {
    if (date == null) {
      return const Text('بدون تاريخ');
    }

    final expired = _isExpired(date);
    final soon = _isExpiringSoon(date);

    final text =
        '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';

    if (expired) {
      return Text(
        text,
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
      );
    }

    if (soon) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return Text(text);
  }

  Widget _buildEmpty() {
    return const Center(
      child: Text(
        'لا توجد منتجات في هذا القسم',
        style: TextStyle(fontSize: 18),
      ),
    );
  }

  bool _isExpired(DateTime? date) {
    if (date == null) return false;

    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );

    return date.isBefore(today);
  }

  bool _isExpiringSoon(DateTime? date) {
    if (date == null) return false;

    final today = DateTime.now();

    final end = today.add(const Duration(days: 30));

    return !date.isBefore(today) && !date.isAfter(end);
  }

  String _format(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: effectiveColor.withValues(alpha: 0.12),
              child: Icon(icon, color: effectiveColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
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
}
