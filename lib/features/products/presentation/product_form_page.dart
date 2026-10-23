import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/inventory_service.dart';
import '../../../providers/currency_providers.dart';
import '../../../services/currency_service.dart';
import '../products_provider.dart' as feature_provider;
import '../../../core/utils/product_packaging.dart';

class ProductFormPage extends ConsumerStatefulWidget {
  final Product? product;

  const ProductFormPage({
    super.key,
    this.product,
  });

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _barcodeController;
  late final TextEditingController _cartonBarcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _purchasePriceController;
  late final TextEditingController _sellingPriceController;
  late final TextEditingController _stockController;
  late final TextEditingController _minimumStockController;
  late final TextEditingController _unitController;
  late final TextEditingController _cartonPriceController;

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

    _barcodeController = TextEditingController(text: product?.barcode ?? '');
    _cartonBarcodeController = TextEditingController(
      text: product == null ? '' : ProductPackaging.fromUnit(product.unit, piecePrice: product.sellingPrice).cartonBarcode,
    );

    _nameController = TextEditingController(
      text: product?.name ?? '',
    );

    _purchasePriceController = TextEditingController(
      text: product == null
          ? ''
          : _currency.fromYer(product.purchasePrice, currency: _currencyCode).toStringAsFixed(2),
    );

    _sellingPriceController = TextEditingController(
      text: product == null
          ? ''
          : _currency.fromYer(product.sellingPrice, currency: _currencyCode).toStringAsFixed(2),
    );

    _stockController = TextEditingController(
      text: product == null ? '0' : product.stockQuantity.toString(),
    );

    _minimumStockController = TextEditingController(
      text: product == null ? '0' : product.minimumStock.toString(),
    );

    _unitController = TextEditingController(
      text: product == null ? '12' : ProductPackaging.fromUnit(product.unit, piecePrice: product.sellingPrice).piecesPerCarton.toString(),
    );

    _cartonPriceController = TextEditingController(
      text: product == null ? '' : _currency.fromYer(ProductPackaging.fromUnit(product.unit, piecePrice: product.sellingPrice).cartonSellingPrice, currency: _currencyCode).toStringAsFixed(2),
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
        _cartonPriceController.text = _currency.fromYer(ProductPackaging.fromUnit(product.unit, piecePrice: product.sellingPrice).cartonSellingPrice, currency: _currencyCode).toStringAsFixed(2);
      }
    });
  }

  double _toYer(double value) => _currency.toYer(value, currency: _currencyCode);
  String get _currencySymbol => _currency.symbol(_currencyCode);

  @override
  void dispose() {
    _barcodeController.dispose();
    _cartonBarcodeController.dispose();
    _nameController.dispose();
    _purchasePriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _minimumStockController.dispose();
    _unitController.dispose();
    _cartonPriceController.dispose();

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
    final cartonPriceDisplay = double.tryParse(_cartonPriceController.text.trim()) ?? 0;
    final cartonSellingPrice = _toYer(cartonPriceDisplay);
    final piecesPerCarton = int.tryParse(_unitController.text.trim()) ?? 0;

    final stock = double.tryParse(_stockController.text.trim()) ?? 0;
    final minimumStock = double.tryParse(_minimumStockController.text.trim()) ?? 0;

    if (purchasePrice < 0 || sellingPrice < 0 || cartonSellingPrice < 0 || piecesPerCarton < 1 || stock < 0 || minimumStock < 0) {
      _showError('تحقق من الأسعار والكميات: يجب ألا تكون سالبة، وعدد الحبات بالكرتون لا يقل عن 1');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final repository = ref.read(productsRepositoryProvider);
      final db = ref.read(databaseProvider);
      final inventory = InventoryService(db);

      if (isEditing) {
        final oldStock = widget.product!.stockQuantity;

        // تحديث المنتج أولاً
        await repository.update(
          id: widget.product!.id,
          barcode: _barcodeController.text.trim(),
          name: _nameController.text.trim(),
          categoryId: _categoryId,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          stockQuantity: oldStock,
          minimumStock: minimumStock,
          unit: ProductPackaging.encode(piecesPerCarton: piecesPerCarton, cartonSellingPrice: cartonSellingPrice, cartonBarcode: _cartonBarcodeController.text.trim()),
          expiryDate: _expiryDate,
          isActive: _isActive,
        );

        // تعديل المخزون في حالة الاختلاف مع التأخير الزمني لتفادي تكرار مفتاح القيود
        if ((stock - oldStock).abs() > 0.000001) {
          await Future.delayed(const Duration(milliseconds: 10));
          await inventory.adjustStock(
            productId: widget.product!.id,
            actualQuantity: stock,
            type: 'adjustment',
            notes: 'تسوية مخزون من تعديل المنتج',
          );
        }
      } else {
        // إنشاء منتج جديد
        final productId = await repository.create(
          barcode: _barcodeController.text.trim(),
          name: _nameController.text.trim(),
          categoryId: _categoryId,
          purchasePrice: purchasePrice,
          sellingPrice: sellingPrice,
          stockQuantity: 0,
          minimumStock: minimumStock,
          unit: ProductPackaging.encode(piecesPerCarton: piecesPerCarton, cartonSellingPrice: cartonSellingPrice, cartonBarcode: _cartonBarcodeController.text.trim()),
          expiryDate: _expiryDate,
        );

        if (stock > 0) {
          await Future.delayed(const Duration(milliseconds: 10));
          await inventory.adjustStock(
            productId: productId,
            actualQuantity: stock,
            type: 'opening',
            notes: 'رصيد مخزون افتتاحي للمنتج',
          );
        }
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;

      _showError(_friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('unique') || lower.contains('constraint') || lower.contains('barcode')) {
      return 'تعذر حفظ المنتج: الباركود مستخدم لمنتج آخر. غيّر باركود الحبة أو الكرتون ثم حاول مجددًا.';
    }
    if (lower.contains('foreign key') || lower.contains('category')) {
      return 'تعذر حفظ المنتج: التصنيف المحدد غير موجود أو تم حذفه. اختر تصنيفًا آخر.';
    }
    if (lower.contains('database') || lower.contains('sqlite') || lower.contains('drift')) {
      return 'تعذر حفظ المنتج بسبب مشكلة في قاعدة البيانات. تأكد من عدم فتح قاعدة البيانات في برنامج آخر ثم أعد المحاولة. التفاصيل: $raw';
    }
    return 'تعذر ${isEditing ? 'تعديل' : 'إضافة'} المنتج. تحقق من البيانات واتصال قاعدة البيانات. السبب: $raw';
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
          isEditing ? 'تعديل المنتج' : 'إضافة منتج',
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
                prefixIcon: Icon(Icons.inventory_2_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
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
                prefixIcon: Icon(Icons.qr_code),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الباركود مطلوب';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cartonBarcodeController,
              decoration: const InputDecoration(
                labelText: 'باركود الكرتون',
                helperText: 'اختياري — يستخدم عند مسح الكرتون في البيع',
                prefixIcon: Icon(Icons.qr_code_2),
                border: OutlineInputBorder(),
              ),
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
                      value: category.id,
                      child: Text(category.name),
                    )),
              ],
              onChanged: _isSaving ? null : (value) => setState(() => _categoryId = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _purchasePriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'سعر الشراء ($_currencySymbol)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _sellingPriceController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'سعر البيع ($_currencySymbol)',
                      border: const OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'مطلوب';
                      }
                      if (double.tryParse(value) == null) {
                        return 'رقم غير صحيح';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cartonPriceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'سعر بيع الكرتون ($_currencySymbol)',
                helperText: 'سعر الحبة أعلاه، وهذا سعر الكرتون كاملًا',
                border: const OutlineInputBorder(),
              ),
              validator: (value) => value == null || double.tryParse(value) == null || double.parse(value) < 0 ? 'أدخل سعر كرتون صحيحًا' : null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _stockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'الكمية الحالية',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _minimumStockController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
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
                labelText: 'عدد الحبات داخل الكرتون',
                hintText: 'مثال: 12',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'أدخل عدد الحبات داخل الكرتون';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_available),
                title: const Text('تاريخ انتهاء الصلاحية'),
                subtitle: Text(
                  _expiryDate == null ? 'بدون تاريخ انتهاء' : _formatDate(_expiryDate!),
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
                        icon: const Icon(Icons.clear),
                      ),
                    IconButton(
                      tooltip: 'اختيار التاريخ',
                      onPressed: _selectExpiryDate,
                      icon: const Icon(Icons.calendar_month),
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
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving ? 'جاري الحفظ...' : 'حفظ المنتج',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
