import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../products_provider.dart';
import 'product_form_page.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends ConsumerState<ProductsPage> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchTimer;
  String _searchQuery = '';

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchTimer?.cancel();
    _searchTimer = Timer(
      const Duration(milliseconds: 300),
      () {
        if (!mounted) return;
        setState(() {
          _searchQuery = value.trim();
        });
      },
    );
  }

  Future<void> _openAddProduct() async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProductFormPage(),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openEditProduct(Product product) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(product: product),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteProduct(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المنتج'),
          content: Text('هل أنت متأكد من حذف المنتج "${product.name}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final repository = ref.read(productsRepositoryProvider);
      await repository.delete(product.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم حذف المنتج بنجاح')),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء حذف المنتج: $e')),
      );
    }
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  bool _isExpired(DateTime? date) {
    if (date == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return date.isBefore(today);
  }

  bool _isExpiringSoon(DateTime? date) {
    if (date == null) return false;
    final today = DateTime.now();
    final end = today.add(const Duration(days: 30));
    return !date.isBefore(today) && !date.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة المنتجات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            _buildToolbar(),
            const SizedBox(height: 12),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future: repository.search(_searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return _buildError(snapshot.error);
                  }

                  final products = snapshot.data ?? [];

                  if (products.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildProductsTable(products);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 44,
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                hintText: 'ابحث باسم المنتج أو الباركود...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                        icon: const Icon(Icons.clear, size: 18),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          height: 44,
          child: FilledButton.icon(
            onPressed: _openAddProduct,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('إضافة منتج'),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsTable(List<Product> products) {
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTable(
                  columnSpacing: 16,
                  headingRowHeight: 46,
                  dataRowMinHeight: 48,
                  dataRowMaxHeight: 56,
                  headingTextStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                  columns: const [
                    DataColumn(label: Text('الرقم')),
                    DataColumn(label: Text('الباركود')),
                    DataColumn(label: Text('المنتج')),
                    DataColumn(label: Text('سعر الشراء')),
                    DataColumn(label: Text('سعر البيع')),
                    DataColumn(label: Text('المخزون')),
                    DataColumn(label: Text('الصلاحية')),
                    DataColumn(label: Text('الوحدة')),
                    DataColumn(label: Text('الحالة')),
                    DataColumn(label: Text('الإجراءات')),
                  ],
                  rows: products.map((product) {
                    final isLowStock = product.stockQuantity <= product.minimumStock;
                    final expired = _isExpired(product.expiryDate);
                    final expiringSoon = _isExpiringSoon(product.expiryDate);

                    return DataRow(
                      cells: [
                        DataCell(Text(product.id.toString(), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(product.barcode, style: const TextStyle(fontSize: 12))),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 160),
                            child: Text(
                              product.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                            ),
                          ),
                        ),
                        DataCell(Text(_formatNumber(product.purchasePrice), style: const TextStyle(fontSize: 12))),
                        DataCell(Text(_formatNumber(product.sellingPrice), style: const TextStyle(fontSize: 12))),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_formatNumber(product.stockQuantity), style: const TextStyle(fontSize: 12)),
                              if (isLowStock)
                                const Padding(
                                  padding: EdgeInsets.only(right: 4),
                                  child: Tooltip(
                                    message: 'المخزون منخفض',
                                    child: Icon(Icons.warning_amber, size: 16, color: Colors.orange),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        DataCell(
                          _ExpiryBadge(
                            date: product.expiryDate,
                            expired: expired,
                            expiringSoon: expiringSoon,
                            formattedDate: _formatDate(product.expiryDate),
                          ),
                        ),
                        DataCell(Text(product.unit, style: const TextStyle(fontSize: 12))),
                        DataCell(_StatusBadge(active: product.isActive)),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'تعديل',
                                onPressed: () => _openEditProduct(product),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'حذف',
                                onPressed: () => _deleteProduct(product),
                                icon: Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: Theme.of(context).colorScheme.error,
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
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty ? Icons.inventory_2_outlined : Icons.search_off,
            size: 54,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isEmpty ? 'لا توجد منتجات' : 'لم يتم العثور على منتجات',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            _searchQuery.isEmpty ? 'ابدأ بإضافة أول منتج إلى النظام' : 'جرّب البحث باسم أو باركود مختلف',
            style: const TextStyle(fontSize: 13),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('إضافة أول منتج'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 50, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          const Text('حدث خطأ أثناء تحميل المنتجات', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('$error', textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: () => setState(() {}),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }
}

class _ExpiryBadge extends StatelessWidget {
  final DateTime? date;
  final bool expired;
  final bool expiringSoon;
  final String formattedDate;

  const _ExpiryBadge({
    required this.date,
    required this.expired,
    required this.expiringSoon,
    required this.formattedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (date == null) return const Text('—', style: TextStyle(fontSize: 12));
    if (expired) return const _Badge(text: 'منتهي', color: Colors.red);
    if (expiringSoon) return _Badge(text: formattedDate, color: Colors.orange);
    return Text(formattedDate, style: const TextStyle(fontSize: 12));
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        active ? 'نشط' : 'غير نشط',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 11),
      ),
    );
  }
}
