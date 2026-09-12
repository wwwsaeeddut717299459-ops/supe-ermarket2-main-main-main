import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../products/products_provider.dart';

class InventoryPage extends ConsumerStatefulWidget {
  const InventoryPage({super.key});

  @override
  ConsumerState<InventoryPage> createState() =>
      _InventoryPageState();
}

class _InventoryPageState
    extends ConsumerState<InventoryPage> {
  bool _loading = true;

  List<Product> _products = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
    });

    try {
      final repository =
          ref.read(productsRepositoryProvider);

      final products =
          await repository.getAll();

      if (!mounted) return;

      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'حدث خطأ: $e',
      );
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  int _daysUntil(DateTime date) {
    final now = DateTime.now();

    final today = DateTime(
      now.year,
      now.month,
      now.day,
    );

    final expiry = DateTime(
      date.year,
      date.month,
      date.day,
    );

    return expiry
        .difference(today)
        .inDays;
  }

  bool _isLowStock(Product product) {
    return product.stockQuantity <=
        product.minimumStock;
  }

  bool _isExpired(Product product) {
    if (product.expiryDate == null) {
      return false;
    }

    return _daysUntil(
          product.expiryDate!,
        ) <
        0;
  }

  bool _isExpiringSoon(Product product) {
    if (product.expiryDate == null) {
      return false;
    }

    final days =
        _daysUntil(product.expiryDate!);

    return days >= 0 && days <= 30;
  }

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'غير محدد';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }

  @override
  Widget build(BuildContext context) {
    final lowStock = _products
        .where(_isLowStock)
        .toList();

    final expired = _products
        .where(_isExpired)
        .toList();

    final expiring = _products
        .where(_isExpiringSoon)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إدارة المخزون',
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _loading
                ? null
                : _load,
            icon:
                const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding:
                    const EdgeInsets.all(20),
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        title:
                            'إجمالي المنتجات',
                        value:
                            '${_products.length}',
                        icon:
                            Icons.inventory_2,
                      ),
                      _StatCard(
                        title:
                            'مخزون منخفض',
                        value:
                            '${lowStock.length}',
                        icon:
                            Icons.warning,
                      ),
                      _StatCard(
                        title:
                            'منتهي الصلاحية',
                        value:
                            '${expired.length}',
                        icon:
                            Icons
                                .dangerous,
                      ),
                      _StatCard(
                        title:
                            'ينتهي خلال 30 يوم',
                        value:
                            '${expiring.length}',
                        icon:
                            Icons
                                .event_busy,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  if (lowStock.isNotEmpty)
                    _buildSection(
                      title:
                          '⚠️ المنتجات التي أوشكت على النفاد',
                      products:
                          lowStock,
                      type:
                          _InventoryType.lowStock,
                    ),

                  if (expired.isNotEmpty)
                    _buildSection(
                      title:
                          '🔴 المنتجات منتهية الصلاحية',
                      products:
                          expired,
                      type:
                          _InventoryType.expired,
                    ),

                  if (expiring.isNotEmpty)
                    _buildSection(
                      title:
                          '🟠 المنتجات القريبة من انتهاء الصلاحية',
                      products:
                          expiring,
                      type:
                          _InventoryType.expiring,
                    ),

                  if (lowStock.isEmpty &&
                      expired.isEmpty &&
                      expiring.isEmpty)
                    const Padding(
                      padding:
                          EdgeInsets.all(50),
                      child: Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons
                                  .check_circle,
                              size: 70,
                              color:
                                  Colors.green,
                            ),
                            SizedBox(
                              height: 16,
                            ),
                            Text(
                              'المخزون بحالة جيدة',
                              style:
                                  TextStyle(
                                fontSize:
                                    20,
                                fontWeight:
                                    FontWeight.bold,
                              ),
                            ),
                            SizedBox(
                              height: 8,
                            ),
                            Text(
                              'لا توجد منتجات منخفضة أو قريبة من انتهاء الصلاحية',
                              textAlign:
                                  TextAlign
                                      .center,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Product> products,
    required _InventoryType type,
  }) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 20,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Padding(
            padding:
                const EdgeInsets.all(16),
            child: Text(
              title,
              style:
                  const TextStyle(
                fontSize: 18,
                fontWeight:
                    FontWeight.bold,
              ),
            ),
          ),
          const Divider(height: 1),
          ...products.map(
            (product) {
              return ListTile(
                leading:
                    CircleAvatar(
                  child: Text(
                    product.name
                            .isNotEmpty
                        ? product
                            .name[0]
                        : '?',
                  ),
                ),
                title: Text(
                  product.name,
                ),
                subtitle: Text(
                  'المخزون: ${_formatNumber(product.stockQuantity)} '
                  '${product.unit}\n'
                  'الحد الأدنى: ${_formatNumber(product.minimumStock)}\n'
                  'الانتهاء: ${_formatDate(product.expiryDate)}',
                ),
                isThreeLine: true,
                trailing:
                    _buildStatus(
                  product,
                  type,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatus(
    Product product,
    _InventoryType type,
  ) {
    if (type ==
        _InventoryType.lowStock) {
      return const Icon(
        Icons.warning,
        color: Colors.red,
      );
    }

    if (product.expiryDate ==
        null) {
      return const SizedBox();
    }

    final days =
        _daysUntil(
      product.expiryDate!,
    );

    if (days < 0) {
      return const Text(
        'منتهي',
        style: TextStyle(
          color: Colors.red,
          fontWeight:
              FontWeight.bold,
        ),
      );
    }

    return Text(
      '$days يوم',
      style: TextStyle(
        color: days <= 7
            ? Colors.red
            : Colors.orange,
        fontWeight:
            FontWeight.bold,
      ),
    );
  }
}

enum _InventoryType {
  lowStock,
  expired,
  expiring,
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SizedBox(
        width: 220,
        child: Padding(
          padding:
              const EdgeInsets.all(18),
          child: Row(
            children: [
              Icon(
                icon,
                size: 36,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      value,
                      style:
                          const TextStyle(
                        fontSize: 25,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}