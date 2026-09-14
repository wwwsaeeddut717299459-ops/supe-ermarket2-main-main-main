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
  late Future<List<Product>> _productsFuture;
  late Future<List<InventoryInsight>> _insightsFuture;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final repository = ref.read(productsRepositoryProvider);
    _productsFuture = repository.getAll();
    _insightsFuture =
        ref.read(businessAnalyticsServiceProvider).inventoryInsights();
  }

  Future<void> _refresh() async {
    if (!mounted) return;
    setState(() {
      _loadData();
    });
  }

  @override
  Widget build(BuildContext context) {
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
        future: _productsFuture,
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
    final lowStock =
        products.where((p) => p.stockQuantity <= p.minimumStock).toList();
    final expired = products.where((p) => _isExpired(p.expiryDate)).toList();
    final expiringSoon =
        products.where((p) => _isExpiringSoon(p.expiryDate)).toList();

    final visible = switch (_filter) {
      1 => lowStock,
      2 => expiringSoon,
      3 => expired,
      _ => products,
    };

    final scheme = Theme.of(context).colorScheme;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.primaryContainer],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: scheme.onPrimary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.inventory_2_rounded,
                  color: scheme.onPrimary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مركز المخزون',
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'نظرة سريعة على الكميات والصلاحية وحركة المنتجات',
                      style: TextStyle(
                        color: scheme.onPrimary.withValues(alpha: 0.82),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (products.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${products.length} منتج',
                    style: TextStyle(
                      color: scheme.onPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _buildSummary(
          products.length,
          lowStock.length,
          expiringSoon.length,
          expired.length,
        ),
        const SizedBox(height: 10),
        _buildFilters(),
        const SizedBox(height: 10),
        _buildInsights(),
        const SizedBox(height: 10),
        visible.isEmpty ? _buildEmpty() : _buildTable(visible),
      ],
    );
  }

  Widget _buildSummary(int total, int lowStock, int expiring, int expired) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = width >= 900 ? 4 : width >= 600 ? 2 : 1;
        final gap = 8.0;
        final cardWidth =
            columns == 1 ? width : (width - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'إجمالي المنتجات',
                value: '$total',
                icon: Icons.inventory_2_rounded,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'مخزون منخفض',
                value: '$lowStock',
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'قرب الانتهاء',
                value: '$expiring',
                icon: Icons.event_rounded,
                color: Colors.amber,
              ),
            ),
            SizedBox(
              width: cardWidth,
              child: _SummaryCard(
                title: 'منتهي الصلاحية',
                value: '$expired',
                icon: Icons.dangerous_rounded,
                color: Colors.red,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInsights() {
    return FutureBuilder<List<InventoryInsight>>(
      future: _insightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Center(
                child: Text('تعذر تحميل تحليل حركة المنتجات: ${snapshot.error}'),
              ),
            ),
          );
        }
        final insights = snapshot.data ?? [];
        final best =
            insights.where((item) => item.soldQuantity > 0).take(8).toList();
        final dormant =
            insights.where((item) => item.state == 'راكد').take(8).toList();
        final advice = ref
            .read(businessAnalyticsServiceProvider)
            .categoryAdvice(insights);

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'تحليل حركة المخزون والنصائح',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isCompact = constraints.maxWidth < 850;
                    if (isCompact) {
                      return Column(
                        children: [
                          SizedBox(
                            height: 180,
                            child: _insightList('الأكثر مبيعًا', best, Colors.green),
                          ),
                          const Divider(),
                          SizedBox(
                            height: 180,
                            child: _insightList('المنتجات الراكدة', dormant, Colors.red),
                          ),
                          const Divider(),
                          SizedBox(
                            height: 180,
                            child: _adviceList(advice),
                          ),
                        ],
                      );
                    }
                    return SizedBox(
                      height: 200,
                      child: Row(
                        children: [
                          Expanded(
                            child: _insightList('الأكثر مبيعًا', best, Colors.green),
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
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _insightList(
    String title,
    List<InventoryInsight> items,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: items.isEmpty
              ? const Text('لا توجد بيانات كافية', style: TextStyle(fontSize: 11))
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(item.productName, style: const TextStyle(fontSize: 12)),
                      subtitle: Text(
                        '${item.category} — مباع: ${item.soldQuantity.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: Text(item.profit.toStringAsFixed(2), style: const TextStyle(fontSize: 11)),
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
          style: TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold, fontSize: 13),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: advice.isEmpty
              ? const Text('لا توجد فئات', style: TextStyle(fontSize: 11))
              : ListView(
                  shrinkWrap: true,
                  children: advice.entries
                      .map(
                        (entry) => ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(entry.key, style: const TextStyle(fontSize: 12)),
                          subtitle: Text(entry.value, style: const TextStyle(fontSize: 10)),
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            Icon(Icons.filter_list_rounded, color: scheme.primary, size: 20),
            const SizedBox(width: 6),
            const Text('عرض:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(width: 8),
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
      padding: const EdgeInsetsDirectional.only(end: 6),
      child: ChoiceChip(
        visualDensity: VisualDensity.compact,
        avatar: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: 12)),
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
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 44,
          dataRowMinHeight: 48,
          dataRowMaxHeight: 60,
          columnSpacing: 20,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          columns: const [
            DataColumn(label: Text('المنتج')),
            DataColumn(label: Text('الباركود')),
            DataColumn(label: Text('المخزون')),
            DataColumn(label: Text('الحد الأدنى')),
            DataColumn(label: Text('الصلاحية')),
            DataColumn(label: Text('الحالة')),
          ],
          rows: products.map((product) {
            final lowStock =
                product.stockQuantity <= product.minimumStock;
            final expired = _isExpired(product.expiryDate);
            final expiring = _isExpiringSoon(product.expiryDate);

            return DataRow(
              cells: [
                DataCell(
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 180),
                    child: Text(
                      product.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                DataCell(Text(product.barcode, style: const TextStyle(fontSize: 12))),
                DataCell(
                  Text(
                    '${_format(product.stockQuantity)} ${product.unit}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                DataCell(Text(_format(product.minimumStock), style: const TextStyle(fontSize: 12))),
                DataCell(_expiryWidget(product.expiryDate)),
                DataCell(
                  Wrap(
                    spacing: 4,
                    children: [
                      if (lowStock)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('مخزون منخفض', style: TextStyle(fontSize: 10)),
                          avatar: Icon(Icons.warning, size: 14),
                        ),
                      if (expired)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('منتهي', style: TextStyle(fontSize: 10)),
                          avatar: Icon(Icons.dangerous, size: 14),
                        )
                      else if (expiring)
                        const Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text('قرب الانتهاء', style: TextStyle(fontSize: 10)),
                          avatar: Icon(Icons.event, size: 14),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _expiryWidget(DateTime? date) {
    if (date == null) {
      return const Text('بدون تاريخ', style: TextStyle(fontSize: 12));
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
        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
      );
    }

    if (soon) {
      return Text(
        text,
        style: const TextStyle(
          color: Colors.orange,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      );
    }

    return Text(text, style: const TextStyle(fontSize: 12));
  }

  Widget _buildEmpty() {
    return const Padding(
      padding: EdgeInsets.all(20),
      child: Center(
        child: Text(
          'لا توجد منتجات في هذا القسم',
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
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
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: effectiveColor.withValues(alpha: 0.12),
              child: Icon(icon, color: effectiveColor, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 18,
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
