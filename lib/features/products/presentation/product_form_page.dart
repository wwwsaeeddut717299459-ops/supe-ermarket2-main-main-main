import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/inventory_service.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
import '../products_provider.dart' as feature_provider;

class ProductFormPage extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormPage({
    super.key,
    this.product,
  });

  @override
  ConsumerState<ProductFormPage> createState() =>
      _ProductFormPageState();
}

class _ProductFormPageState
    extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _unitController;

  DateTime? _expiryDate;

  bool _isSaving = false;
  bool _isActive = true;
  late final CurrencyService _currency;
  String _currencyCode = 'YER';
  bool _currencyReady = false;
  List<Category> _categories = [];
  int? _categoryId;

  bool get isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();

    final product = widget.product;

    _barcodeController = TextEditingController(
      text: product?.barcode ?? '',
    );

    _nameController = TextEditingController(
      text: product?.name ?? '',
    );

    _purchasePriceController =
        TextEditingController(
      text: product == null
          ? ''
          : _currency.fromYer(product.purchasePrice, currency: _currencyCode).toStringAsFixed(2),
    );

    _sellingPriceController =
        TextEditingController(
      text: product == null
          ? ''
          : _currency.fromYer(product.sellingPrice, currency: _currencyCode).toStringAsFixed(2),
    );

    _stockController = TextEditingController(
      text: product == null
          ? '0'
          : product.stockQuantity.toString(),
    );

    _minimumStockController =
        TextEditingController(
      text: product == null
          ? '0'
          : product.minimumStock.toString(),
    );

    _unitController = TextEditingController(
      text: product?.unit ?? 'piece',
    );

    _expiryDate = product?.expiryDate;
    _isActive = product?.isActive ?? true;
    _categoryId = product?.categoryId;
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await ref.read(categoriesRepositoryProvider).getAll();
      if (mounted) setState(() => _categories = categories);
    } catch (_) {}
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (!mounted) return;
    final product = widget.product;
    setState(() {
      _currencyCode = _currency.displayCurrency;
      _currencyReady = true;
      if (product != null) {
        _purchasePriceController.text =
            _currency.fromYer(product.purchasePrice, currency: _currencyCode).toStringAsFixed(2);
        _sellingPriceController.text =
            _currency.fromYer(product.sellingPrice, currency: _currencyCode).toStringAsFixed(2);
      }
    });
  }

  double _toYer(double value) => _currency.toYer(value, currency: _currencyCode);
  String get _currencySymbol => _currency.symbol(_currencyCode);

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    _unitController.dispose();

    super.dispose();
  }

  Future<void> _selectExpiryDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _expiryDate ?? now,
      firstDate: DateTime(now.year - 10),
      lastDate: DateTime(now.year + 20),
      helpText: 'اختر تاريخ انتهاء الصلاحية',
      cancelText: 'إلغاء',
      confirmText: 'اختيار',
    );

    if (picked == null) return;

    setState(() {
      _expiryDate = picked;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (!_currencyReady) {
      _showError('انتظر تحميل إعدادات العملة');
      return;
    }

    final purchasePriceDisplay = double.tryParse(_purchasePriceController.text.trim()) ?? 0;

    final sellingPriceDisplay = double.tryParse(_sellingPriceController.text.trim()) ?? 0;
    final purchasePrice = _toYer(purchasePriceDisplay);
    final sellingPrice = _toYer(sellingPriceDisplay);

    final stock =
        double.tryParse(
          _stockController.text.trim(),
        ) ??
        0;

    final minimumStock =
        double.tryParse(
          _minimumStockController.text.trim(),
        ) ??
        0;

    if (purchasePrice < 0 ||
        sellingPrice < 0 ||
        stock < 0 ||
        minimumStock < 0) {
      _showError('لا يمكن إدخال قيم سالبة');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository =
          ref.read(productsRepositoryProvider);

      final db = ref.read(databaseProvider);
      final inventory = InventoryService(db);

      await db.transaction(() async {
        if (isEditing) {
          final oldStock = widget.product!.stockQuantity;

          // تحديث بيانات المنتج دون تعديل رصيد المخزون مباشرة.
          await repository.update(
            id: widget.product!.id,
            barcode:
                _barcodeController.text.trim(),
            name: _nameController.text.trim(),
            categoryId: _categoryId,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            stockQuantity: oldStock,
            minimumStock: minimumStock,
            unit: _unitController.text.trim(),
            expiryDate: _expiryDate,
            isActive: _isActive,
          );

          if ((stock - oldStock).abs() > 0.000001) {
            await inventory.adjustStock(
              productId: widget.product!.id,
              actualQuantity: stock,
              type: 'adjustment',
              notes: 'تسوية مخزون من تعديل المنتج',
            );
          }
        } else {
          // الرصيد الافتتاحي يجب أن يمر عبر حركة مخزون محاسبية.
          final productId = await repository.create(
            barcode:
                _barcodeController.text.trim(),
            name: _nameController.text.trim(),
            categoryId: _categoryId,
            purchasePrice: purchasePrice,
            sellingPrice: sellingPrice,
            stockQuantity: 0,
            minimumStock: minimumStock,
            unit: _unitController.text.trim(),
            expiryDate: _expiryDate,
          );

          if (stock > 0) {
            await inventory.adjustStock(
              productId: productId,
              actualQuantity: stock,
              type: 'opening',
              notes: 'رصيد مخزون افتتاحي للمنتج',
            );
          }
        }
      });

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showError(
        'حدث خطأ أثناء حفظ المنتج:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEditing
              ? 'تعديل المنتج'
              : 'إضافة منتج',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'اسم المنتج',
                prefixIcon:
                    Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'اسم المنتج مطلوب';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _barcodeController,
              decoration: const InputDecoration(
                labelText: 'الباركود',
                prefixIcon:
                    Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'الباركود مطلوب';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            DropdownButtonFormField<int?>(
              value: _categoryId,
              decoration: const InputDecoration(
                labelText: 'التصنيف',
                prefixIcon: Icon(Icons.category_outlined),
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('بدون تصنيف')),
                ..._categories.map((category) => DropdownMenuItem<int?>(
                  value: category.id, child: Text(category.name),
                )),
              ],
              onChanged: _isSaving ? null : (value) => setState(() => _categoryId = value),
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller:
                        _purchasePriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        InputDecoration(
                      labelText: 'سعر الشراء ($_currencySymbol)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'مطلوب';
                      }

                      if (double.tryParse(
                            value,
                          ) ==
                          null) {
                        return 'رقم غير صحيح';
                      }

                      return null;
                    },
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller:
                        _sellingPriceController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        InputDecoration(
                      labelText: 'سعر البيع ($_currencySymbol)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null ||
                          value.trim().isEmpty) {
                        return 'مطلوب';
                      }

                      if (double.tryParse(
                            value,
                          ) ==
                          null) {
                        return 'رقم غير صحيح';
                      }

                      return null;
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(
                      labelText: 'الكمية الحالية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: TextFormField(
                    controller:
                        _minimumStockController,
                    keyboardType:
                        const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration:
                        const InputDecoration(
                      labelText: 'الحد الأدنى للمخزون',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _unitController,
              decoration: const InputDecoration(
                labelText: 'الوحدة',
                hintText: 'piece / box / kg ...',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'الوحدة مطلوبة';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.event_available,
                ),
                title: const Text(
                  'تاريخ انتهاء الصلاحية',
                ),
                subtitle: Text(
                  _expiryDate == null
                      ? 'بدون تاريخ انتهاء'
                      : _formatDate(
                          _expiryDate!,
                        ),
                ),
                trailing: Wrap(
                  children: [
                    if (_expiryDate != null)
                      IconButton(
                        tooltip: 'مسح التاريخ',
                        onPressed: () {
                          setState(() {
                            _expiryDate = null;
                          });
                        },
                        icon: const Icon(
                          Icons.clear,
                        ),
                      ),
                    IconButton(
                      tooltip: 'اختيار التاريخ',
                      onPressed: _selectExpiryDate,
                      icon: const Icon(
                        Icons.calendar_month,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            SwitchListTile(
              value: _isActive,
              onChanged: (value) {
                setState(() {
                  _isActive = value;
                });
              },
              title: const Text('المنتج نشط'),
            ),

            const SizedBox(height: 24),

            SizedBox(
              height: 52,
              child: FilledButton.icon(
                onPressed:
                    _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'جاري الحفظ...'
                      : 'حفظ المنتج',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
