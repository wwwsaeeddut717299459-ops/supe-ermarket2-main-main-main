import 'dart:async';
import 'package:flutter/foundation.dart';
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

// كلاس لتأخير البحث ومنع تنفيذه مع كل حرف (Debouncer)
class Debouncer {
  final Duration delay;
  Timer? _timer;

  Debouncer({this.delay = const Duration(milliseconds: 250)});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}

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

// هيكل لحفظ بيانات الفاتورة المعلقة
class _HeldInvoice {
  final String id;
  final String title;
  final DateTime time;
  final List<_CartItem> cart;
  final Customer? customer;
  final String paymentMethod;
  final String discount;
  final String paid;
  final String notes;
  final String currencyCode;

  _HeldInvoice({
    required this.id,
    required this.title,
    required this.time,
    required this.cart,
    required this.customer,
    required this.paymentMethod,
    required this.discount,
    required this.paid,
    required this.notes,
    required this.currencyCode,
  });
}

class _SalesPageState extends ConsumerState<SalesPage> {
  final _barcodeController = TextEditingController();
  final _searchController = TextEditingController();
  final _customerSearchController = TextEditingController();
  final _discountController = TextEditingController(text: '0');
  final _paidController = TextEditingController(text: '0');
  final _notesController = TextEditingController();

  final _barcodeFocusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  final _customerFocusNode = FocusNode();

  final List<_CartItem> _cart = [];
  final List<_HeldInvoice> _heldInvoices = []; // قائمة الفواتير المعلقة
  final StringBuffer _barcodeBuffer = StringBuffer();

  // أدوات البحث السريع والـ Debouncers
  final _productDebouncer = Debouncer(delay: const Duration(milliseconds: 250));
  final _customerDebouncer = Debouncer(delay: const Duration(milliseconds: 250));

  List<Product> _cachedProducts = [];
  List<Customer> _cachedCustomers = [];
  bool _isSearchingProducts = false;
  bool _isSearchingCustomers = false;

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
    
    HardwareKeyboard.instance.addHandler(_handleGlobalKeyInput);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _barcodeFocusNode.requestFocus();
    });

    _paidController.addListener(_refresh);
    _discountController.addListener(_refresh);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_handleGlobalKeyInput);

    _productDebouncer.dispose();
    _customerDebouncer.dispose();

    _barcodeController.dispose();
    _searchController.dispose();
    _customerSearchController.dispose();
    _discountController.dispose();
    _paidController.dispose();
    _notesController.dispose();
    _barcodeFocusNode.dispose();
    _searchFocusNode.dispose();
    _customerFocusNode.dispose();

    super.dispose();
  }

  bool _handleGlobalKeyInput(KeyEvent event) {
    if (event is KeyDownEvent) {
      final primaryFocus = FocusManager.instance.primaryFocus;
      final isFocusedOnOtherTextfield = primaryFocus != null &&
          primaryFocus != _barcodeFocusNode &&
          primaryFocus.context?.widget is EditableText;

      if (isFocusedOnOtherTextfield) {
        return false;
      }

      if (event.logicalKey == LogicalKeyboardKey.enter) {
        if (_barcodeBuffer.isNotEmpty) {
          _barcodeController.text = _barcodeBuffer.toString();
          _barcodeBuffer.clear();
          _addByBarcode();
          return true;
        }
      } else if (event.character != null && event.character!.isNotEmpty) {
        if (!event.logicalKey.keyLabel.startsWith('F') && 
            event.logicalKey != LogicalKeyboardKey.tab &&
            event.logicalKey != LogicalKeyboardKey.escape) {
          _barcodeBuffer.write(event.character);
        }
      }
    }
    return false;
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
    return value < 0 ? 0 : value;
  }

  double get total {
    final value = subtotal - discount;
    return value < 0 ? 0 : value;
  }

  double get paid {
    final value = _parseDouble(_paidController.text);
    return value < 0 ? 0 : value;
  }

  double get remaining {
    final value = total - paid;
    return value < 0 ? 0 : value;
  }

  double get change {
    final value = paid - total;
    return value < 0 ? 0 : value;
  }

  // تنفيذ بحث المنتجات بسرعة عالية بدون تحميل مستمر
  Future<void> _performProductSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _cachedProducts = [];
          _isSearchingProducts = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearchingProducts = true);

    try {
      final repository = ref.read(productsRepositoryProvider);
      final results = await repository.search(query.trim());

      if (!mounted) return;
      setState(() {
        _cachedProducts = results;
        _isSearchingProducts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingProducts = false);
    }
  }

  // تنفيذ بحث العملاء بسرعة فائقة
  Future<void> _performCustomerSearch(String query) async {
    if (query.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _cachedCustomers = [];
          _isSearchingCustomers = false;
        });
      }
      return;
    }

    if (mounted) setState(() => _isSearchingCustomers = true);

    try {
      final database = ref.read(databaseProvider);
      final results = await database.customersDao.search(query.trim());

      if (!mounted) return;
      setState(() {
        _cachedCustomers = results;
        _isSearchingCustomers = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSearchingCustomers = false);
    }
  }

  Future<void> _addByBarcode() async {
    final barcode = _barcodeController.text.trim();
    if (barcode.isEmpty) return;

    try {
      final repository = ref.read(productsRepositoryProvider);
      final product = await repository.getByBarcode(barcode);

      if (!mounted) return;

      if (product == null) {
        _showMessage('المنتج غير موجود');
        _barcodeController.clear();
        return;
      }

      if (!product.isActive) {
        _showMessage('هذا المنتج غير نشط');
        _barcodeController.clear();
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
    final existingIndex = _cart.indexWhere((item) => item.product.id == product.id);

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
      _cachedCustomers = [];
    });
  }

  void _clearCustomer() {
    setState(() {
      _selectedCustomer = null;
      _customerSearchController.clear();
      _cachedCustomers = [];
    });
  }

  // ميزة تعليق الفاتورة (F10)
  void _holdCurrentInvoice() {
    if (_cart.isEmpty) {
      _showMessage('السلة فارغة، لا يمكن تعليق فاتورة فارغة');
      return;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final customerName = _selectedCustomer?.name ?? 'بدون عميل';
    final title = 'فاتورة رقم #${_heldInvoices.length + 1} ($customerName)';

    _heldInvoices.add(_HeldInvoice(
      id: id,
      title: title,
      time: DateTime.now(),
      cart: List.from(_cart),
      customer: _selectedCustomer,
      paymentMethod: _paymentMethod,
      discount: _discountController.text,
      paid: _paidController.text,
      notes: _notesController.text,
      currencyCode: _currencyCode,
    ));

    _clearSale();
    _showMessage('تم تعليق الفاتورة بنجاح (معلقة: ${_heldInvoices.length})');
  }

  // ميزة نافذة استعادة الفواتير المعلقة (F11)
  Future<void> _showHeldInvoicesDialog() async {
    if (_heldInvoices.isEmpty) {
      _showMessage('لا توجد فواتير معلقة حالياً');
      return;
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.pause_circle_outline, color: Colors.orange),
              SizedBox(width: 8),
              Text('الفواتير المعلقة'),
            ],
          ),
          content: SizedBox(
            width: 400,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _heldInvoices.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final held = _heldInvoices[index];
                return ListTile(
                  dense: true,
                  title: Text(held.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('الأصناف: ${held.cart.length} • الوقت: ${held.time.hour}:${held.time.minute.toString().padLeft(2, '0')}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: () {
                          _restoreInvoice(held);
                          Navigator.pop(dialogContext);
                        },
                        child: const Text('استعادة', style: TextStyle(fontSize: 11)),
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                        onPressed: () {
                          setState(() {
                            _heldInvoices.removeAt(index);
                          });
                          Navigator.pop(dialogContext);
                          _showHeldInvoicesDialog();
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  void _restoreInvoice(_HeldInvoice held) {
    if (_cart.isNotEmpty) {
      _showMessage('يرجى تفريغ السلة الحالية أو تعليقها قبل استعادة فاتورة أخرى');
      return;
    }

    setState(() {
      _cart.clear();
      _cart.addAll(held.cart);
      _selectedCustomer = held.customer;
      if (held.customer != null) {
        _customerSearchController.text = held.customer!.name;
      } else {
        _customerSearchController.clear();
      }
      _paymentMethod = held.paymentMethod;
      _discountController.text = held.discount;
      _paidController.text = held.paid;
      _notesController.text = held.notes;
      _currencyCode = held.currencyCode;
      _heldInvoices.removeWhere((item) => item.id == held.id);
    });

    _showMessage('تمت استعادة الفاتورة بنجاح');
  }

  Future<void> _saveSale() async {
    if (_cart.isEmpty) {
      _showMessage('أضف منتجات إلى الفاتورة أولاً');
      return;
    }

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
        customerId: _paymentMethod == 'credit' ? _selectedCustomer!.id : null,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
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
        try {
          await InvoicePrintService.printSale(
            sale: savedSale!,
            items: savedItems,
            settings: invoiceSettings,
          );
        } catch (printError) {
          if (mounted) {
            _showMessage('⚠️ تم حفظ الفاتورة بنجاح، ولكن تعذرت الطباعة.\nتحقق من اتصال الطابعة وحاول إعادة الطباعة.');
          }
        }
      }

      if (!mounted) return;
      
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }

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
      _cachedProducts.clear();
      _searchController.clear();
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
              onPressed: () => Navigator.pop(context),
              child: const Text('موافق'),
            ),
          ],
        );
      },
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openPaymentDialog() async {
    if (_cart.isEmpty) {
      _showMessage('أضف منتجات إلى الفاتورة أولاً');
      return;
    }
    if (_paymentMethod == 'cash') {
      _paidController.text = total.toStringAsFixed(2);
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (dialogContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.85,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(10, 2, 10, 12),
              child: _buildSummary(),
            ),
          ),
        );
      },
    );
  }

  void _showShortcutsHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard),
            SizedBox(width: 8),
            Text('اختصارات لوحة المفاتيح'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: Chip(label: Text('F1')), title: Text('فتح نافذة الدفع والإنهاء')),
            ListTile(leading: Chip(label: Text('F2')), title: Text('تحويل طريقة الدفع إلى آجل')),
            ListTile(leading: Chip(label: Text('F3')), title: Text('التركيز على حقل البحث عن العميل')),
            ListTile(leading: Chip(label: Text('F4')), title: Text('إلغاء الفاتورة وبدء فاتورة جديدة')),
            ListTile(leading: Chip(label: Text('F5')), title: Text('حفظ وإتمام عملية البيع مباشرة')),
            ListTile(leading: Chip(label: Text('F6')), title: Text('التركيز على حقل الباركود')),
            ListTile(leading: Chip(label: Text('F7')), title: Text('التركيز على حقل البحث عن منتج')),
            ListTile(leading: Chip(label: Text('F10')), title: Text('تعليق الفاتورة الحالية')),
            ListTile(leading: Chip(label: Text('F11')), title: Text('استعادة الفواتير المعلقة')),
            ListTile(leading: Chip(label: Text('F12')), title: Text('عرض نافذة الاختصارات')),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductSearch() {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          children: [
            TextField(
              controller: _barcodeController,
              focusNode: _barcodeFocusNode,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _addByBarcode(),
              decoration: InputDecoration(
                labelText: 'الباركود (F6)',
                hintText: 'امسح الباركود أو اكتبه',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: const Icon(Icons.qr_code_scanner, size: 18),
                suffixIcon: IconButton(
                  onPressed: _addByBarcode,
                  icon: const Icon(Icons.add, size: 18),
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              decoration: const InputDecoration(
                labelText: 'بحث عن منتج (F7)',
                hintText: 'اكتب اسم المنتج أو الباركود',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                prefixIcon: Icon(Icons.search, size: 18),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                _productDebouncer.run(() {
                  _performProductSearch(value);
                });
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
            Icon(Icons.search, size: 40, color: Colors.grey),
            SizedBox(height: 6),
            Text(
              'ابحث عن منتج لإضافته إلى الفاتورة',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isSearchingProducts) {
      return const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)));
    }

    if (_cachedProducts.isEmpty) {
      return const Center(child: Text('لم يتم العثور على المنتج'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(6),
      itemCount: _cachedProducts.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final product = _cachedProducts[index];

        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            dense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
            leading: CircleAvatar(
              radius: 14,
              child: Text(product.name.isNotEmpty ? product.name[0] : '?', style: const TextStyle(fontSize: 11)),
            ),
            title: Text(product.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            subtitle: Text(
              'الباركود: ${product.barcode} • المخزون: ${product.stockQuantity}',
              style: const TextStyle(fontSize: 10),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(_fromYer(product.sellingPrice)),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                ),
                const Icon(Icons.add_shopping_cart, size: 14, color: Colors.indigo),
              ],
            ),
            onTap: () {
              _addProduct(product);
              _searchController.clear();
              setState(() => _cachedProducts.clear());
              _searchFocusNode.requestFocus();
            },
          ),
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
          focusNode: _customerFocusNode,
          decoration: InputDecoration(
            labelText: 'العميل (F3)',
            hintText: 'ابحث باسم العميل أو رقم الهاتف',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            prefixIcon: const Icon(Icons.person_search, size: 18),
            suffixIcon: _selectedCustomer != null
                ? IconButton(
                    onPressed: _clearCustomer,
                    icon: const Icon(Icons.clear, size: 16),
                  )
                : null,
            border: const OutlineInputBorder(),
          ),
          onChanged: (value) {
            if (_selectedCustomer != null) {
              setState(() => _selectedCustomer = null);
            }
            _customerDebouncer.run(() {
              _performCustomerSearch(value);
            });
          },
        ),

        if (_selectedCustomer != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'العميل: ${_selectedCustomer!.name}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                  ),
                ],
              ),
            ),
          ),

        if (query.isNotEmpty && _selectedCustomer == null) const SizedBox(height: 4),

        if (query.isNotEmpty && _selectedCustomer == null) ...[
          if (_isSearchingCustomers)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            )
          else if (_cachedCustomers.isEmpty)
            const Padding(
              padding: EdgeInsets.all(6),
              child: Text('لم يتم العثور على العميل', style: TextStyle(fontSize: 11)),
            )
          else
            Card(
              margin: EdgeInsets.zero,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _cachedCustomers.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final customer = _cachedCustomers[index];

                    return ListTile(
                      dense: true,
                      leading: Icon(
                        customer.isActive ? Icons.person : Icons.person_off,
                        color: customer.isActive ? Colors.green : Colors.red,
                        size: 16,
                      ),
                      title: Text(customer.name, style: const TextStyle(fontSize: 11)),
                      subtitle: Text(customer.phone ?? 'بدون هاتف', style: const TextStyle(fontSize: 9)),
                      onTap: () => _selectCustomer(customer),
                    );
                  },
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildCart() {
    if (_cart.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.shopping_cart_outlined, size: 40, color: Colors.grey),
            SizedBox(height: 6),
            Text('السلة فارغة', style: TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(6),
      itemCount: _cart.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final item = _cart[index];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Row(
              children: [
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'حذف المنتج',
                  onPressed: () => _removeItem(index),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.product.name,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'سعر: ${_money(_fromYer(item.product.sellingPrice))} • مجموع: ${_money(_fromYer(item.total))}',
                        style: const TextStyle(fontSize: 10, color: Colors.indigo),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _decreaseQuantity(index),
                      icon: const Icon(Icons.remove_circle_outline, size: 20),
                    ),
                    InkWell(
                      borderRadius: BorderRadius.circular(4),
                      onTap: () => _editQuantity(index),
                      child: Container(
                        width: 34,
                        alignment: Alignment.center,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.black26),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.quantity.toStringAsFixed(
                            item.quantity == item.quantity.roundToDouble() ? 0 : 2,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
                        ),
                      ),
                    ),
                    IconButton(
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => _increaseQuantity(index),
                      icon: const Icon(Icons.add_circle_outline, size: 20),
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
      margin: EdgeInsets.zero,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _summaryRow('المجموع الفرعي', subtotal),
            const SizedBox(height: 2),
            _summaryRow('الخصم', discount),
            const Divider(height: 10),
            _summaryRow('الإجمالي', total, bold: true, large: true),
            if (_currencyReady)
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'ما يعادل ${_moneyBoth(_toYer(total))}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 10),
                ),
              ),
            const SizedBox(height: 6),

            TextField(
              controller: _discountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                labelText: 'الخصم ($_currencySymbol)',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                prefixIcon: const Icon(Icons.discount, size: 16),
                border: const OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 6),

            if (_paymentMethod == 'credit') ...[
              TextField(
                controller: _paidController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'المبلغ المدفوع ($_currencySymbol)',
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  prefixIcon: const Icon(Icons.payments, size: 16),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 6),
            ],

            DropdownButtonFormField<String>(
              value: _currencyCode,
              decoration: const InputDecoration(
                labelText: 'عملة الفاتورة',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                prefixIcon: Icon(Icons.currency_exchange_rounded, size: 16),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'YER', child: Text('الريال اليمني (ر.ي)', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'SAR', child: Text('الريال السعودي (ر.س)', style: TextStyle(fontSize: 11))),
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

            const SizedBox(height: 6),

            DropdownButtonFormField<String>(
              value: _paymentMethod,
              decoration: const InputDecoration(
                labelText: 'طريقة الدفع',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                prefixIcon: Icon(Icons.payment, size: 16),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'cash', child: Text('نقداً', style: TextStyle(fontSize: 11))),
                DropdownMenuItem(value: 'credit', child: Text('آجل (F2)', style: TextStyle(fontSize: 11))),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _paymentMethod = value;
                  if (value == 'cash') {
                    _selectedCustomer = null;
                    _customerSearchController.clear();
                    _cachedCustomers.clear();
                    _paidController.text = _fromYer(total).toStringAsFixed(2);
                  }
                });
              },
            ),

            if (_paymentMethod == 'credit') ...[
              const SizedBox(height: 6),
              _buildCustomerSelector(),
            ],

            const SizedBox(height: 6),

            TextField(
              controller: _notesController,
              maxLines: 1,
              decoration: const InputDecoration(
                labelText: 'ملاحظات',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                prefixIcon: Icon(Icons.notes, size: 16),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 6),

            if (remaining > 0) _summaryRow('المتبقي', remaining),
            if (change > 0) _summaryRow('الباقي للعميل', change),

            const SizedBox(height: 8),

            SizedBox(
              width: double.infinity,
              height: 38,
              child: FilledButton.icon(
                onPressed: _saving ? null : _saveSale,
                icon: _saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.point_of_sale, size: 16),
                label: Text(_saving ? 'جاري الحفظ...' : 'إتمام البيع (F5)', style: const TextStyle(fontSize: 12)),
              ),
            ),

            const SizedBox(height: 4),

            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _holdCurrentInvoice,
                      icon: const Icon(Icons.pause, size: 14),
                      label: const Text('تعليق (F10)', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SizedBox(
                    height: 32,
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _showHeldInvoicesDialog,
                      icon: Badge(
                        isLabelVisible: _heldInvoices.isNotEmpty,
                        label: Text('${_heldInvoices.length}'),
                        child: const Icon(Icons.unarchive, size: 14),
                      ),
                      label: const Text('المعلقة (F11)', style: TextStyle(fontSize: 10)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 4),

            SizedBox(
              width: double.infinity,
              height: 32,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _clearSale,
                icon: const Icon(Icons.clear, size: 14),
                label: const Text('إلغاء الفاتورة (F4)', style: TextStyle(fontSize: 11)),
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
            fontSize: large ? 14 : 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: large ? 15 : 11,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [scheme.primaryContainer, scheme.surfaceContainerHighest],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: scheme.primary,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.receipt_long_rounded, color: scheme.onPrimary, size: 16),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('الفاتورة الحالية', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                Text('${_cart.length} أصناف • ${_money(total)}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 10)),
              ],
            ),
          ),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'تعليق الفاتورة (F10)',
            onPressed: _saving || _cart.isEmpty ? null : _holdCurrentInvoice,
            icon: const Icon(Icons.pause_circle_outline, size: 18),
          ),
          const SizedBox(width: 4),
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'مسح الفاتورة (F4)',
            onPressed: _saving || _cart.isEmpty ? null : _clearSale,
            icon: const Icon(Icons.delete_sweep_outlined, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(BoxConstraints constraints) {
    final scheme = Theme.of(context).colorScheme;

    final productPanel = Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(padding: const EdgeInsets.all(4), child: _buildProductSearch()),
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
          const SizedBox(height: 2),
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
            padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
            child: Row(
              children: [
                Icon(Icons.payments_outlined, color: scheme.primary, size: 16),
                const SizedBox(width: 4),
                const Expanded(child: Text('الدفع والإتمام', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'إخفاء لوحة الدفع',
                  onPressed: () => setState(() => _showPaymentPanel = false),
                  icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 18),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(6),
              child: _buildSummary(),
            ),
          ),
        ],
      ),
    );

    if (!_showPaymentPanel) {
      return Column(
        children: [
          Expanded(flex: 4, child: productPanel),
          const SizedBox(height: 6),
          Expanded(flex: 7, child: invoicePanel),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  onPressed: () => setState(() => _showPaymentPanel = true),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('إظهار الدفع وإتمام البيع'),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 3, child: productPanel),
        const SizedBox(width: 6),
        Expanded(flex: 4, child: invoicePanel),
        const SizedBox(width: 6),
        Expanded(flex: 3, child: paymentPanel),
      ],
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
              Padding(padding: const EdgeInsets.all(4), child: _buildProductSearch()),
              const Divider(height: 1),
              Expanded(child: _buildProducts()),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          flex: 5,
          child: Card(
            elevation: 1,
            clipBehavior: Clip.antiAlias,
            child: Column(children: [
              _buildInvoiceHeader(),
              Expanded(child: _buildCart()),
            ]),
          ),
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 46,
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('إجمالي الفاتورة', style: TextStyle(fontSize: 9)),
                        Text(_money(total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: _cart.isEmpty || _saving ? null : _openPaymentDialog,
                    icon: const Icon(Icons.payments_outlined, size: 16),
                    label: const Text('الدفع والإنهاء (F1)', style: TextStyle(fontSize: 11)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShortcutsBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Text('F1: دفع', style: TextStyle(fontSize: 10)),
          Text('F2: آجل', style: TextStyle(fontSize: 10)),
          Text('F3: عميل', style: TextStyle(fontSize: 10)),
          Text('F4: جديد', style: TextStyle(fontSize: 10)),
          Text('F5: حفظ', style: TextStyle(fontSize: 10)),
          Text('F6: باركود', style: TextStyle(fontSize: 10)),
          Text('F7: بحث', style: TextStyle(fontSize: 10)),
          Text('F10: تعليق', style: TextStyle(fontSize: 10)),
          Text('F11: معلقة', style: TextStyle(fontSize: 10)),
          Text('F12: مساعدة', style: TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FocusScope(
      autofocus: true,
      child: Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          const SingleActivator(LogicalKeyboardKey.f1): const _OpenPaymentIntent(),
          const SingleActivator(LogicalKeyboardKey.f2): const _CreditSaleIntent(),
          const SingleActivator(LogicalKeyboardKey.f3): const _FocusCustomerIntent(),
          const SingleActivator(LogicalKeyboardKey.f4): const _NewSaleIntent(),
          const SingleActivator(LogicalKeyboardKey.f5): const _CompleteSaleIntent(),
          const SingleActivator(LogicalKeyboardKey.f6): const _FocusBarcodeSearchIntent(),
          const SingleActivator(LogicalKeyboardKey.f7): const _FocusProductSearchIntent(),
          const SingleActivator(LogicalKeyboardKey.f10): const _HoldInvoiceIntent(),
          const SingleActivator(LogicalKeyboardKey.f11): const _RestoreInvoiceIntent(),
          const SingleActivator(LogicalKeyboardKey.f12): const _ShowHelpIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            _OpenPaymentIntent: CallbackAction<_OpenPaymentIntent>(
              onInvoke: (_) {
                if (!_saving) _openPaymentDialog();
                return null;
              },
            ),
            _CreditSaleIntent: CallbackAction<_CreditSaleIntent>(
              onInvoke: (_) {
                if (_saving) return null;
                setState(() {
                  _paymentMethod = 'credit';
                  _paidController.text = '0';
                });
                return null;
              },
            ),
            _FocusCustomerIntent: CallbackAction<_FocusCustomerIntent>(
              onInvoke: (_) {
                if (_saving) return null;
                if (_paymentMethod != 'credit') {
                  setState(() => _paymentMethod = 'credit');
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) _customerFocusNode.requestFocus();
                });
                return null;
              },
            ),
            _NewSaleIntent: CallbackAction<_NewSaleIntent>(
              onInvoke: (_) {
                if (!_saving) _clearSale();
                return null;
              },
            ),
            _CompleteSaleIntent: CallbackAction<_CompleteSaleIntent>(
              onInvoke: (_) {
                if (!_saving) _saveSale();
                return null;
              },
            ),
            _FocusBarcodeSearchIntent: CallbackAction<_FocusBarcodeSearchIntent>(
              onInvoke: (_) {
                _barcodeFocusNode.requestFocus();
                return null;
              },
            ),
            _FocusProductSearchIntent: CallbackAction<_FocusProductSearchIntent>(
              onInvoke: (_) {
                _searchFocusNode.requestFocus();
                return null;
              },
            ),
            _HoldInvoiceIntent: CallbackAction<_HoldInvoiceIntent>(
              onInvoke: (_) {
                if (!_saving) _holdCurrentInvoice();
                return null;
              },
            ),
            _RestoreInvoiceIntent: CallbackAction<_RestoreInvoiceIntent>(
              onInvoke: (_) {
                if (!_saving) _showHeldInvoicesDialog();
                return null;
              },
            ),
            _ShowHelpIntent: CallbackAction<_ShowHelpIntent>(
              onInvoke: (_) {
                _showShortcutsHelpDialog();
                return null;
              },
            ),
          },
          child: Scaffold(
            appBar: AppBar(
              toolbarHeight: 44,
              titleSpacing: 0,
              title: const Row(
                children: [
                  SizedBox(width: 8),
                  Icon(Icons.point_of_sale_rounded, size: 18),
                  SizedBox(width: 6),
                  Text('نقطة البيع', style: TextStyle(fontSize: 14)),
                ],
              ),
              actions: [
                IconButton(
                  tooltip: 'الفواتير المعلقة (F11)',
                  icon: Badge(
                    isLabelVisible: _heldInvoices.isNotEmpty,
                    label: Text('${_heldInvoices.length}'),
                    child: const Icon(Icons.pause_circle_outline, size: 18),
                  ),
                  onPressed: _showHeldInvoicesDialog,
                ),
                IconButton(
                  tooltip: 'اختصارات لوحة المفاتيح (F12)',
                  icon: const Icon(Icons.keyboard_outlined, size: 18),
                  onPressed: _showShortcutsHelpDialog,
                ),
                if (_currencyReady)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Center(
                      child: Chip(
                        visualDensity: VisualDensity.compact,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 2),
                        avatar: const Icon(Icons.currency_exchange_rounded, size: 12),
                        label: Text(_currency.name(_currencyCode), style: const TextStyle(fontSize: 10)),
                      ),
                    ),
                  ),
                if (!_showPaymentPanel)
                  IconButton(
                    tooltip: 'إظهار لوحة الدفع',
                    onPressed: () => setState(() => _showPaymentPanel = true),
                    icon: const Icon(Icons.payments_outlined, size: 18),
                  ),
                IconButton(
                  tooltip: 'فاتورة جديدة (F4)',
                  onPressed: _saving ? null : _clearSale,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                ),
              ],
            ),
            body: !_currencyReady
                ? const Center(child: CircularProgressIndicator())
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isCompact = constraints.maxWidth < 1150 || constraints.maxHeight < 720;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(6, 4, 6, 4),
                        child: Column(
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.storefront_rounded, color: Theme.of(context).colorScheme.primary, size: 16),
                                  const SizedBox(width: 6),
                                  const Expanded(
                                    child: Text('almajedPRO • مبيعات سريعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                                  ),
                                  if (_heldInvoices.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(left: 8),
                                      child: Text('معلقة: ${_heldInvoices.length} (F11)', style: const TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                                    ),
                                  Text(_paymentMethod == 'cash' ? 'نقدي' : 'آجل', style: const TextStyle(fontSize: 11)),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Expanded(child: isCompact ? _buildLaptopLayout() : _buildDesktopLayout(constraints)),
                            const SizedBox(height: 4),
                            _buildShortcutsBar(),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }
}

class _OpenPaymentIntent extends Intent { const _OpenPaymentIntent(); }
class _CreditSaleIntent extends Intent { const _CreditSaleIntent(); }
class _FocusCustomerIntent extends Intent { const _FocusCustomerIntent(); }
class _NewSaleIntent extends Intent { const _NewSaleIntent(); }
class _CompleteSaleIntent extends Intent { const _CompleteSaleIntent(); }
class _FocusBarcodeSearchIntent extends Intent { const _FocusBarcodeSearchIntent(); }
class _FocusProductSearchIntent extends Intent { const _FocusProductSearchIntent(); }
class _HoldInvoiceIntent extends Intent { const _HoldInvoiceIntent(); }
class _RestoreInvoiceIntent extends Intent { const _RestoreInvoiceIntent(); }
class _ShowHelpIntent extends Intent { const _ShowHelpIntent(); }
