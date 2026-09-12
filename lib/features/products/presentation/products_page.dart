import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../products_provider.dart';
import 'product_form_page.dart';

class ProductsPage extends ConsumerStatefulWidget {
  const ProductsPage({super.key});

  @override
  ConsumerState<ProductsPage> createState() =>
      _ProductsPageState();
}

class _ProductsPageState
    extends ConsumerState<ProductsPage> {
  final TextEditingController _searchController =
      TextEditingController();

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
    final result =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => const ProductFormPage(),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _openEditProduct(
    Product product,
  ) async {
    final result =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ProductFormPage(
          product: product,
        ),
      ),
    );

    if (result == true && mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteProduct(
    Product product,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('حذف المنتج'),
          content: Text(
            'هل أنت متأكد من حذف المنتج "${product.name}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor:
                    Theme.of(context)
                        .colorScheme
                        .error,
              ),
              child: const Text('حذف'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final repository =
          ref.read(productsRepositoryProvider);

      await repository.delete(product.id);

      if (!mounted) return;

      setState(() {});

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text('تم حذف المنتج بنجاح'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'حدث خطأ أثناء حذف المنتج: $e',
          ),
        ),
      );
    }
  }

  Future<void> _refresh() async {
    if (!mounted) return;

    setState(() {});
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return '—';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
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

    final end = today.add(
      const Duration(days: 30),
    );

    return !date.isBefore(today) &&
        !date.isAfter(end);
  }

  @override
  Widget build(BuildContext context) {
    final repository =
        ref.watch(productsRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('المنتجات'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildToolbar(),
            const SizedBox(height: 20),
            Expanded(
              child: FutureBuilder<List<Product>>(
                future:
                    repository.search(_searchQuery),
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                      child:
                          CircularProgressIndicator(),
                    );
                  }

                  if (snapshot.hasError) {
                    return _buildError(
                      snapshot.error,
                    );
                  }

                  final products =
                      snapshot.data ?? [];

                  if (products.isEmpty) {
                    return _buildEmptyState();
                  }

                  return _buildProductsTable(
                    products,
                  );
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
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText:
                  'ابحث باسم المنتج أو الباركود...',
              prefixIcon:
                  const Icon(Icons.search),
              suffixIcon:
                  _searchController.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'مسح البحث',
                          onPressed: () {
                            _searchController
                                .clear();

                            setState(() {
                              _searchQuery = '';
                            });
                          },
                          icon: const Icon(
                            Icons.clear,
                          ),
                        ),
              border:
                  const OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          onPressed: _openAddProduct,
          icon: const Icon(Icons.add),
          label: const Text('إضافة منتج'),
        ),
      ],
    );
  }

  Widget _buildProductsTable(
    List<Product> products,
  ) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 28,
            headingRowHeight: 56,
            dataRowMinHeight: 60,
            dataRowMaxHeight: 80,
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
              final isLowStock =
                  product.stockQuantity <=
                      product.minimumStock;

              final expired =
                  _isExpired(
                product.expiryDate,
              );

              final expiringSoon =
                  _isExpiringSoon(
                product.expiryDate,
              );

              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      product.id.toString(),
                    ),
                  ),

                  DataCell(
                    Text(product.barcode),
                  ),

                  DataCell(
                    ConstrainedBox(
                      constraints:
                          const BoxConstraints(
                        maxWidth: 220,
                      ),
                      child: Text(
                        product.name,
                        overflow:
                            TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      _formatNumber(
                        product.purchasePrice,
                      ),
                    ),
                  ),

                  DataCell(
                    Text(
                      _formatNumber(
                        product.sellingPrice,
                      ),
                    ),
                  ),

                  DataCell(
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        Text(
                          _formatNumber(
                            product.stockQuantity,
                          ),
                        ),
                        if (isLowStock)
                          const Padding(
                            padding:
                                EdgeInsets.only(
                              right: 6,
                            ),
                            child: Tooltip(
                              message:
                                  'المخزون منخفض',
                              child: Icon(
                                Icons
                                    .warning_amber,
                                size: 20,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  DataCell(
                    _ExpiryBadge(
                      date: product.expiryDate,
                      expired: expired,
                      expiringSoon:
                          expiringSoon,
                      formattedDate:
                          _formatDate(
                        product.expiryDate,
                      ),
                    ),
                  ),

                  DataCell(
                    Text(product.unit),
                  ),

                  DataCell(
                    _StatusBadge(
                      active:
                          product.isActive,
                    ),
                  ),

                  DataCell(
                    Row(
                      mainAxisSize:
                          MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'تعديل',
                          onPressed: () =>
                              _openEditProduct(
                            product,
                          ),
                          icon: const Icon(
                            Icons.edit,
                          ),
                        ),
                        IconButton(
                          tooltip: 'حذف',
                          onPressed: () =>
                              _deleteProduct(
                            product,
                          ),
                          icon: Icon(
                            Icons.delete,
                            color:
                                Theme.of(context)
                                    .colorScheme
                                    .error,
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            _searchQuery.isEmpty
                ? Icons.inventory_2_outlined
                : Icons.search_off,
            size: 72,
            color: Theme.of(context)
                .colorScheme
                .onSurfaceVariant,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isEmpty
                ? 'لا توجد منتجات'
                : 'لم يتم العثور على منتجات',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isEmpty
                ? 'ابدأ بإضافة أول منتج إلى النظام'
                : 'جرّب البحث باسم أو باركود مختلف',
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _openAddProduct,
              icon: const Icon(Icons.add),
              label:
                  const Text('إضافة أول منتج'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildError(Object? error) {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: Theme.of(context)
                .colorScheme
                .error,
          ),
          const SizedBox(height: 16),
          const Text(
            'حدث خطأ أثناء تحميل المنتجات',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '$error',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
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
    if (date == null) {
      return const Text('—');
    }

    if (expired) {
      return const _Badge(
        text: 'منتهي',
        color: Colors.red,
      );
    }

    if (expiringSoon) {
      return _Badge(
        text: formattedDate,
        color: Colors.orange,
      );
    }

    return Text(formattedDate);
  }
}

class _Badge extends StatelessWidget {
  final String text;
  final Color color;

  const _Badge({
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool active;

  const _StatusBadge({
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        active ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        active ? 'نشط' : 'غير نشط',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}