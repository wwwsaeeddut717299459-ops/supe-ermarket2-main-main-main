import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' hide Column;

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
import '../../../services/audit_service.dart';
import '../../../services/invoice_print_service.dart';
import '../../auth/auth_providers.dart' as auth;

class SalesPage extends ConsumerStatefulWidget {
  const SalesPage({super.key});

  @override
  ConsumerState<SalesPage> createState() => _SalesPageState();
}

class _CartItem {
  final Product product;
  double quantity;
  double discount;

  _CartItem({required this.product}) : quantity = 1, discount = 0;

  double get total {
    final value = (product.sellingPrice * quantity) - discount;
    return value < 0 ? 0 : value;
  }
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _barcodeController = TextEditingController();
  final _searchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final _barcodeFocusNode = FocusNode();

  final List<_CartItem> _cart = [];

  bool _saving = false;
  bool _currencyReady = false;
  late final CurrencyService _currency;
  String _currencyCode = 'YER';

  String _paymentMethod = 'cash';
  bool _showPaymentPanel = true;

  Customer? _selectedCustomer;

  @override
  void initState() {
    super.initState();

    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
    _barcodeFocusNode.requestFocus();

    _paidController.addListener(_refresh);
    _discountController.addListener(_refresh);
    _customerSearchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _searchController.dispose();
    _customerSearchController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _barcodeFocusNode.dispose();

    super.dispose();
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (!mounted) return;
    setState(() {
      _currencyCode = _currency.displayCurrency;
      _currencyReady = true;
    });
  }

  String get _currencySymbol => _currency.symbol(_currencyCode);
  double _toYer(double amount) => _currency.toYer(amount, currency: _currencyCode);
  double _fromYer(double amount) => _currency.fromYer(amount, currency: _currencyCode);
  String _money(double amount) => _currency.format(amount, currency: _currencyCode);
  String _moneyBoth(double yerAmount) => _currency.formatBothFromYer(yerAmount);

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  double _parseDouble(String value) {
    return double.tryParse(value.trim()) ?? 0;
  }

  double get subtotal {
    return _cart.fold<double>(
      0,
      (sum, item) => sum + _fromYer(item.total),
    );
  }

  double get discount {
    final value = _parseDouble(_discountController.text);

    if (value < 0) {
      return 0;
    }

    return value;
  }

  double get total {
    final value = subtotal - discount;
    return value < 0 ? 0 : value;
  }

  double get paid {
    final value = _parseDouble(_paidController.text);

    if (value < 0) {
      return 0;
    }

    return value;
  }

  double get remaining {
    final value = total - paid;

    return value < 0 ? 0 : value;
  }

  double get change {
    final value = paid - total;

    return value < 0 ? 0 : value;
  }

  Future<List<Product>> _searchProducts(String query) {
    final repository = ref.read(productsRepositoryProvider);

    return repository.search(query);
  }

  Future<List<Customer>> _searchCustomers(String query) {
    final database = ref.read(databaseProvider);

    return database.customersDao.search(query.trim());
  }

  Future<void> _addByBarcode() async {
    final barcode = _barcodeController.text.trim();

    if (barcode.isEmpty) {
      return;
    }

    try {
      final repository = ref.read(productsRepositoryProvider);

      final product = await repository.getByBarcode(barcode);

      if (!mounted) return;

      if (product == null) {
        _showMessage('المنتج غير موجود');
        return;
      }

      if (!product.isActive) {
        _showMessage('هذا المنتج غير نشط');
        return;
      }

      _addProduct(product);

      _barcodeController.clear();
      _barcodeFocusNode.requestFocus();
    } catch (e) {
      if (!mounted) return;

      _showMessage('حدث خطأ: $e');
    }
  }

  void _addProduct(Product product) {
    final existingIndex = _cart.indexWhere(
      (item) => item.product.id == product.id,
    );

    if (existingIndex >= 0) {
      final item = _cart[existingIndex];

      if (item.quantity + 1 > product.stockQuantity) {
        _showMessage('الكمية المطلوبة أكبر من المخزون');
        return;
      }

      setState(() {
        item.quantity++;
      });

      return;
    }

    if (product.stockQuantity <= 0) {
      _showMessage('المنتج غير متوفر في المخزون');
      return;
    }

    setState(() {
      _cart.add(_CartItem(product: product));
    });
  }

  void _increaseQuantity(int index) {
    final item = _cart[index];

    if (item.quantity + 1 > item.product.stockQuantity) {
      _showMessage('لا توجد كمية كافية في المخزون');
      return;
    }

    setState(() {
      item.quantity++;
    });
  }

  void _decreaseQuantity(int index) {
    final item = _cart[index];

    if (item.quantity <= 1) {
      setState(() {
        _cart.removeAt(index);
      });

      return;
    }

    setState(() {
      item.quantity--;
    });
  }

  Future<void> _editQuantity(int index) async {
    final item = _cart[index];
    final controller = TextEditingController(
      text: item.quantity.toStringAsFixed(
        item.quantity == item.quantity.roundToDouble() ? 0 : 2,
      ),
    );

    try {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('تعديل كمية ${item.product.name}'),
          content: TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
            ],
            decoration: InputDecoration(
              labelText: 'الكمية',
              helperText: 'المتاح في المخزون: ${item.product.stockQuantity}',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final quantity = double.tryParse(controller.text.trim());
                if (quantity == null || quantity <= 0) {
                  _showMessage('أدخل كمية صحيحة أكبر من صفر');
                  return;
                }
                if (quantity > item.product.stockQuantity) {
                  _showMessage('الكمية المطلوبة أكبر من المخزون');
                  return;
                }
                setState(() {
                  item.quantity = quantity;
                });
                Navigator.pop(dialogContext);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  void _removeItem(int index) {
    setState(() {
      _cart.removeAt(index);
    });
  }

  void _selectCustomer(Customer customer) {
    if (!customer.isActive) {
      _showMessage('العميل غير نشط');

      setState(() {
        _selectedCustomer = null;
      });

      return;
    }

    setState(() {
      _selectedCustomer = customer;
      _customerSearchController.text = customer.name;
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerSearchController.clear();
    });
  }

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      _showMessage('أضف منتجات إلى الفاتورة أولاً');
      return;
    }

    // في البيع النقدي يضبط النظام المدفوع تلقائياً على إجمالي الفاتورة
    // لتجنب رفض الفاتورة بسبب ترك حقل المدفوع صفراً.
    if (_paymentMethod == 'cash') {
      _paidController.text = total.toStringAsFixed(2);
    }

    if (discount > subtotal) {
      _showMessage('الخصم أكبر من إجمالي الفاتورة');
      return;
    }

    if (paid > total) {
      _showMessage('المبلغ المدفوع أكبر من إجمالي الفاتورة');
      return;
    }

    // ==========================================================
    // التحقق من العميل عند البيع الآجل
    // ==========================================================

    if (_paymentMethod == 'credit') {
      if (_selectedCustomer == null) {
        _showMessage('يجب اختيار العميل عند البيع الآجل');
        return;
      }

      if (!_selectedCustomer!.isActive) {
        _showMessage('العميل غير نشط');
        return;
      }
    }

    setState(() {
      _saving = true;
    });

    try {
      final repository = ref.read(salesRepositoryProvider);

      final items = _cart.map((item) {
        final itemTotal = item.total;

        return SaleItemsCompanion(
          saleId: const Value.absent(),
          productId: Value(item.product.id),
          productName: Value(item.product.name),
          barcode: Value(item.product.barcode),
          quantity: Value(item.quantity),
          unitPrice: Value(item.product.sellingPrice),
          discount: Value(_toYer(item.discount)),
          total: Value(_toYer(itemTotal)),
        );
      }).toList();

      final saleId = await repository.create(
        invoiceNumber: null,
        items: items,
        discount: _toYer(discount),
        paid: _toYer(paid),
        paymentMethod: _paymentMethod,

        // العميل يُرسل فقط عند البيع الآجل.
        customerId: _paymentMethod == 'credit' ? _selectedCustomer!.id : null,

        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );

      final savedSale = await repository.getById(saleId);
      final invoiceNumber = savedSale?.invoiceNumber ?? saleId.toString();

      await AuditService().log(
        user: ref.read(auth.authSessionProvider).currentUser?.username ?? 'غير معروف',
        action: 'تسجيل بيع',
        details: 'الفاتورة $invoiceNumber • الإجمالي ${_money(total)}',
      );

      final invoiceSettings = await ref.read(invoiceSettingsRepositoryProvider).getOrCreate();
      final savedItems = await repository.getItems(saleId);
      final currency = ref.read(currencyServiceProvider);
      await currency.load();
      if (currency.printingEnabled) {
        await InvoicePrintService.printSale(sale: savedSale!, items: savedItems, settings: invoiceSettings);
      }

      if (!mounted) return;

      await _showSuccessDialog(invoiceNumber: invoiceNumber, saleId: saleId);

      if (!mounted) return;

      _clearSale();
    } catch (e) {
      if (!mounted) return;

      _showMessage('تعذر حفظ الفاتورة:\n$e');
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _clearSale() {
    setState(() {
      _cart.clear();

      _discountController.text = '0';
      _paidController.text = '0';
      _notesController.clear();

      _paymentMethod = 'cash';

      _selectedCustomer = null;
      _customerSearchController.clear();
    });

    _barcodeController.clear();
    _barcodeFocusNode.requestFocus();
  }

  Future<void> _showSuccessDialog({
    required String invoiceNumber,
    required int saleId,
  }) {
    return showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('تم حفظ الفاتورة'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('رقم الفاتورة: $invoiceNumber'),
              const SizedBox(height: 8),
              Text('رقم العملية: $saleId'),
              const SizedBox(height: 8),
              Text('الإجمالي: ${_money(total)}'),
              const SizedBox(height: 8),
              Text('بالعملة الأساسية: ${_moneyBoth(_toYer(total))}'),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildProductSearch() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addByBarcode(),
              decoration: InputDecoration(
                labelText: 'الباركود',
                hintText: 'امسح الباركود أو اكتبه',
                prefixIcon: const Icon(Icons.qr_code_scanner),
                suffixIcon: IconButton(
                  onPressed: _addByBarcode,
                  icon: const Icon(Icons.add),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'بحث عن منتج',
                hintText: 'اكتب اسم المنتج أو الباركود',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProducts() {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 60),
            SizedBox(height: 12),
            Text(
              'ابحث عن منتج لإضافته إلى الفاتورة',
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Product>>(
      future: _searchProducts(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('حدث خطأ: ${snapshot.error}'));
        }

        final products = snapshot.data ?? [];

        if (products.isEmpty) {
          return const Center(child: Text('لم يتم العثور على المنتج'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: products.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final product = products[index];

            return Card(
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(product.name.isNotEmpty ? product.name[0] : '?'),
                ),
                title: Text(product.name),
                subtitle: Text(
                  'الباركود: ${product.barcode}\n'
                  'المخزون: ${product.stockQuantity}',
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _money(_fromYer(product.sellingPrice)),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    const Icon(Icons.add_shopping_cart),
                  ],
                ),
                onTap: () {
                  _addProduct(product);
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomerSelector() {
    if (_paymentMethod != 'credit') {
      return const SizedBox.shrink();
    }

    final query = _customerSearchController.text.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _customerSearchController,
          decoration: InputDecoration(
            labelText: 'العميل',
            hintText: 'ابحث باسم العميل أو رقم الهاتف',
            prefixIcon: const Icon(Icons.person_search),
            suffixIcon: _selectedCustomer != null
                ? IconButton(
                    onPressed: _clearCustomer,
                    icon: const Icon(Icons.clear),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (_) {
            setState(() {});
          },
        ),

        if (_selectedCustomer != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'العميل المحدد: ${_selectedCustomer!.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (query.isNotEmpty && _selectedCustomer == null)
          const SizedBox(height: 8),

        if (query.isNotEmpty && _selectedCustomer == null)
          FutureBuilder<List<Customer>>(
            future: _searchCustomers(query),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    'حدث خطأ أثناء البحث عن العميل: '
                    '${snapshot.error}',
                  ),
                );
              }

              final customers = snapshot.data ?? [];

              if (customers.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(12),
                  child: Text('لم يتم العثور على العميل'),
                );
              }

              return Card(
                margin: EdgeInsets.zero,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 220),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: customers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final customer = customers[index];

                      return ListTile(
                        leading: Icon(
                          customer.isActive ? Icons.person : Icons.person_off,
                          color: customer.isActive ? Colors.green : Colors.red,
                        ),
                        title: Text(customer.name),
                        subtitle: Text(customer.phone ?? 'بدون رقم هاتف'),
                        trailing: customer.isActive
                            ? const Icon(Icons.arrow_forward_ios, size: 16)
                            : const Text(
                                'غير نشط',
                                style: TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                        onTap: () {
                          _selectCustomer(customer);
                        },
                      );
                    },
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 70),
            SizedBox(height: 12),
            Text('السلة فارغة', style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'حذف المنتج من الفاتورة',
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        'سعر الوحدة: ${_money(_fromYer(item.product.sellingPrice))}',
                      ),
                      Text(
                        'الإجمالي: ${_money(_fromYer(item.total))}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      onPressed: () => _decreaseQuantity(index),
                      icon: const Icon(Icons.remove_circle_outline),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: () => _editQuantity(index),
                      child: Container(
                        width: 50,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          item.quantity.toStringAsFixed(
                            item.quantity == item.quantity.roundToDouble() ? 0 : 2,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => _increaseQuantity(index),
                      icon: const Icon(Icons.add_circle_outline),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _summaryRow('المجموع الفرعي', subtotal),
            const SizedBox(height: 8),
            _summaryRow('الخصم', discount),
            const Divider(height: 24),
            _summaryRow('الإجمالي', total, bold: true, large: true),
            if (_currencyReady)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ما يعادل ${_moneyBoth(_toYer(total))}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            const SizedBox(height: 12),

            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'الخصم ($_currencySymbol)',
                prefixIcon: Icon(Icons.discount),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            if (_paymentMethod == 'credit') ...[
              TextField(
                controller: _paidController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع ($_currencySymbol)',
                  prefixIcon: const Icon(Icons.payments),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],

            DropdownButtonFormField<String>(
              value: _currencyCode,
              decoration: const InputDecoration(
                labelText: 'عملة الفاتورة',
                prefixIcon: Icon(Icons.currency_exchange_rounded),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'YER', child: Text('الريال اليمني (ر.ي)')),
                DropdownMenuItem(value: 'SAR', child: Text('الريال السعودي (ر.س)')),
              ],
              onChanged: _currencyReady ? (value) {
                if (value == null || value == _currencyCode) return;
                final old = _currencyCode;
                setState(() {
                  _currencyCode = value;
                  _discountController.text = _currency.convert(
                    discount, from: old, to: value,
                  ).toStringAsFixed(2);
                  _paidController.text = _currency.convert(
                    paid, from: old, to: value,
                  ).toStringAsFixed(2);
                });
              } : null,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                prefixIcon: Icon(Icons.payment),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقداً')),
                DropdownMenuItem(value: 'credit', child: Text('آجل')),
              ],
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _paymentMethod = value;

                  if (value == 'cash') {
                    _selectedCustomer = null;
                    _customerSearchController.clear();
                    _paidController.text = _fromYer(total).toStringAsFixed(2);
                  }
                });
              },
            ),

            if (_paymentMethod == 'credit') ...[
              const SizedBox(height: 12),
              _buildCustomerSelector(),
            ],

            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                prefixIcon: Icon(Icons.notes),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            if (remaining > 0) _summaryRow('المتبقي', remaining),

            if (change > 0) _summaryRow('الباقي للعميل', change),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSale,
                icon: _saving
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale),
                label: Text(_saving ? 'جاري حفظ الفاتورة...' : 'إتمام البيع'),
              ),
            ),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _clearSale,
                icon: const Icon(Icons.clear),
                label: const Text('إلغاء الفاتورة'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String title,
    double value, {
    bool bold = false,
    bool large = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: large ? 19 : 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: large ? 22 : 15,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded, color: scheme.onPrimary),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الفاتورة الحالية', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                Text('${_cart.length} أصناف • ${_money(total)}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          IconButton(
            tooltip: 'مسح الفاتورة',
            onPressed: _saving || _cart.isEmpty ? null : _clearSale,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;
    final showPayment = _showPaymentPanel && constraints.maxWidth >= 1180;

    final productPanel = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(12), child: _buildProductSearch()),
          const Divider(height: 1),
          Expanded(child: _buildProducts()),
        ],
      ),
    );

    final invoicePanel = Card(
      elevation: 1,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _buildInvoiceHeader(),
          const SizedBox(height: 4),
          Expanded(child: _buildCart()),
        ],
      ),
    );

    final paymentPanel = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(child: Text('الدفع والإتمام', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17))),
                IconButton(
                  tooltip: 'إخفاء لوحة الدفع',
                  onPressed: () => setState(() => _showPaymentPanel = false),
                  icon: const Icon(Icons.keyboard_double_arrow_right_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(12), child: _buildSummary())),
        ],
      ),
    );

    if (!showPayment) {
      return Column(
        children: [
          Expanded(flex: 4, child: productPanel),
          const SizedBox(height: 12),
          Expanded(flex: 7, child: invoicePanel),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _showPaymentPanel = true),
                  icon: const Icon(Icons.payments_outlined),
                  label: const Text('إظهار الدفع وإتمام البيع'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 4, child: productPanel),
        const SizedBox(width: 12),
        Expanded(flex: 5, child: invoicePanel),
        const SizedBox(width: 12),
        Expanded(flex: 3, child: paymentPanel),
      ],
    );
  }

  Future<void> _openPaymentDialog() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.9,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: _buildSummary(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLaptopLayout() {
    return Column(
      children: [
        Expanded(
          flex: 4,
          child: Card(
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(10), child: _buildProductSearch()),
              const Divider(height: 1),
              Expanded(child: _buildProducts()),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          flex: 7,
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _buildInvoiceHeader(),
              Expanded(child: _buildCart()),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 62,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي الفاتورة', style: TextStyle(fontSize: 12)),
                        Text(_money(total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _cart.isEmpty || _saving ? null : _openPaymentDialog,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('الدفع وإتمام البيع'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Shortcuts(
      shortcuts: <ShortcutActivator, Intent>{
        const SingleActivator(LogicalKeyboardKey.f5): const _CompleteSaleIntent(),
        const SingleActivator(LogicalKeyboardKey.f1): const _FocusSearchIntent(),
        const SingleActivator(LogicalKeyboardKey.digit2): const _CreditSaleIntent(),
        const SingleActivator(LogicalKeyboardKey.digit1): const _CashSaleIntent(),
        const SingleActivator(LogicalKeyboardKey.escape): const _ClearSaleIntent(),
      },
      child: Actions(actions: <Type, Action<Intent>>{
        _CompleteSaleIntent: CallbackAction<_CompleteSaleIntent>(onInvoke: (_) { if (!_saving) _saveSale(); return null; }),
        _FocusSearchIntent: CallbackAction<_FocusSearchIntent>(onInvoke: (_) { FocusScope.of(context).requestFocus(_barcodeFocusNode); return null; }),
        _CreditSaleIntent: CallbackAction<_CreditSaleIntent>(onInvoke: (_) { setState(() => _paymentMethod = 'credit'); return null; }),
        _CashSaleIntent: CallbackAction<_CashSaleIntent>(onInvoke: (_) { setState(() => _paymentMethod = 'cash'); return null; }),
        _ClearSaleIntent: CallbackAction<_ClearSaleIntent>(onInvoke: (_) { if (!_saving) _clearSale(); return null; }),
      }, child: Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.point_of_sale_rounded), SizedBox(width: 10), Text('نقطة البيع')]),
        actions: [
          if (_currencyReady)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Center(child: Chip(avatar: const Icon(Icons.currency_exchange_rounded, size: 18), label: Text(_currency.name(_currencyCode)))),
            ),
          if (!_showPaymentPanel)
            IconButton(
              tooltip: 'إظهار لوحة الدفع',
              onPressed: () => setState(() => _showPaymentPanel = true),
              icon: const Icon(Icons.payments_outlined),
            ),
          IconButton(tooltip: 'فاتورة جديدة', onPressed: _saving ? null : _clearSale, icon: const Icon(Icons.add_circle_outline_rounded)),
        ],
      ),
      body: !_currencyReady
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(builder: (context, constraints) {
              final laptop = constraints.maxWidth < 1180;
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(children: [
                        Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 9),
                        const Expanded(child: Text('almajedPRO • مبيعات سريعة ومنظمة', style: TextStyle(fontWeight: FontWeight.bold))),
                        Text(_paymentMethod == 'cash' ? 'نقدي' : 'آجل'),
                      ]),
                    ),
                    const SizedBox(height: 10),
                    Expanded(child: laptop ? _buildLaptopLayout() : _buildDesktopLayout(constraints)),
                  ],
                ),
              );
            }),
      )),
    );
  }

}

class _CompleteSaleIntent extends Intent { const _CompleteSaleIntent(); }
class _FocusSearchIntent extends Intent { const _FocusSearchIntent(); }
class _CreditSaleIntent extends Intent { const _CreditSaleIntent(); }
class _CashSaleIntent extends Intent { const _CashSaleIntent(); }
class _ClearSaleIntent extends Intent { const _ClearSaleIntent(); }
