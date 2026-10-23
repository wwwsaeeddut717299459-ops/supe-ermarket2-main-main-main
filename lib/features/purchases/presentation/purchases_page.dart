import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/currency_providers.dart';
import '../../../providers/database_providers.dart';
import '../../../services/audit_service.dart';
import '../../../services/currency_service.dart';
import '../../../services/purchase_service.dart';
import '../../auth/auth_providers.dart';

class PurchasesPage extends ConsumerStatefulWidget {
  const PurchasesPage({super.key});

  @override
  ConsumerState<PurchasesPage> createState() => _PurchasesPageState();
}

class _PurchasesPageState extends ConsumerState<PurchasesPage> {
  String _search = '';
  late final CurrencyService _currency;
  bool _currencyReady = false;

  @override
  void initState() {
    super.initState();
    _currency = ref.read(currencyServiceProvider);
    _loadCurrency();
  }

  Future<void> _loadCurrency() async {
    await _currency.load();
    if (mounted) setState(() => _currencyReady = true);
  }

  String _money(double yer) => _currency.format(
        _currency.fromYer(yer, currency: _currency.displayCurrency),
        currency: _currency.displayCurrency,
      );

  double _toYer(double value) => _currency.toYer(
        value,
        currency: _currency.displayCurrency,
      );

  Future<void> _newPurchase() async {
    final invoice = TextEditingController();
    final barcode = TextEditingController();
    final name = TextEditingController();
    final purchasePrice = TextEditingController(text: '0');
    final sellingPrice = TextEditingController(text: '0');
    final quantity = TextEditingController(text: '1');
    final discount = TextEditingController(text: '0');
    final paid = TextEditingController(text: '0');
    final notes = TextEditingController();
    final supplierSearchCtrl = TextEditingController();
    final productSearchCtrl = TextEditingController();

    final formKey = GlobalKey<FormState>();
    final lines = <PurchaseLineInput>[];
    final suppliers = await ref.read(suppliersDaoProvider).getAll();
    final products = await ref.read(productsDaoProvider).getAll();

    Supplier? selectedSupplier;
    Product? selectedProduct;
    String payment = 'cash';

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            final service = ref.read(purchaseServiceProvider);
            final subtotal = lines.fold<double>(
              0,
              (sum, line) => sum + service.lineTotal(line),
            );
            final invoiceDiscountDisplay = double.tryParse(discount.text) ?? 0;
            final invoiceDiscountYer = _toYer(invoiceDiscountDisplay);
            final totalYer = (subtotal - invoiceDiscountYer).clamp(
              0,
              double.infinity,
            ).toDouble();

            return AlertDialog(
              title: const Text('فاتورة شراء جديدة'),
              content: SizedBox(
                width: 760,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: invoice,
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'رقم الفاتورة',
                            hintText: 'يُنشأ تلقائياً عند الحفظ',
                            helperText: 'الترقيم موحّد ويبدأ من 1 ولا يتكرر',
                          ),
                        ),
                        const SizedBox(height: 10),
                        // اختيار المورد مع خاصية البحث
                        Autocomplete<Supplier>(
                          displayStringForOption: (Supplier option) => option.name,
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            if (textEditingValue.text.isEmpty) {
                              return suppliers;
                            }
                            return suppliers.where((Supplier option) {
                              return option.name.toLowerCase().contains(
                                    textEditingValue.text.toLowerCase(),
                                  );
                            });
                          },
                          onSelected: (Supplier selection) {
                            setDialogState(() {
                              selectedSupplier = selection;
                            });
                          },
                          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: fieldController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'المورد (ابحث باسم المورد)',
                                prefixIcon: const Icon(Icons.person_search_outlined),
                                suffixIcon: selectedSupplier != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          fieldController.clear();
                                          setDialogState(() {
                                            selectedSupplier = null;
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          value: payment,
                          decoration: const InputDecoration(
                            labelText: 'طريقة الدفع',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'cash',
                              child: Text('نقدي'),
                            ),
                            DropdownMenuItem(
                              value: 'credit',
                              child: Text('آجل'),
                            ),
                          ],
                          onChanged: (value) =>
                              setDialogState(() => payment = value ?? 'cash'),
                        ),
                        const SizedBox(height: 14),
                        // اختيار المنتج مع خاصية البحث بالاسم أو الباركود
                        Autocomplete<Product>(
                          displayStringForOption: (Product option) =>
                              '${option.name} • ${option.barcode}',
                          optionsBuilder: (TextEditingValue textEditingValue) {
                            final query = textEditingValue.text.toLowerCase();
                            if (query.isEmpty) {
                              return products;
                            }
                            return products.where((Product option) {
                              return option.name.toLowerCase().contains(query) ||
                                     option.barcode.toLowerCase().contains(query);
                            });
                          },
                          onSelected: (Product product) {
                            setDialogState(() {
                              selectedProduct = product;
                              barcode.text = product.barcode;
                              name.text = product.name;
                              purchasePrice.text = _currency
                                  .fromYer(
                                    product.purchasePrice,
                                    currency: _currency.displayCurrency,
                                  )
                                  .toStringAsFixed(2);
                              sellingPrice.text = _currency
                                  .fromYer(
                                    product.sellingPrice,
                                    currency: _currency.displayCurrency,
                                  )
                                  .toStringAsFixed(2);
                            });
                          },
                          fieldViewBuilder: (context, fieldController, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: fieldController,
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                labelText: 'البحث عن منتج بالاسم أو الباركود',
                                prefixIcon: const Icon(Icons.search),
                                helperText: 'اختر المنتج من القائمة لتعبئة البيانات تلقائياً',
                                suffixIcon: selectedProduct != null
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          fieldController.clear();
                                          setDialogState(() {
                                            selectedProduct = null;
                                            barcode.clear();
                                            name.clear();
                                            purchasePrice.text = '0';
                                            sellingPrice.text = '0';
                                          });
                                        },
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: barcode,
                                decoration: const InputDecoration(
                                    labelText: 'الباركود'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: name,
                                decoration: const InputDecoration(
                                    labelText: 'اسم المنتج'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: purchasePrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText:
                                      'سعر الشراء (${_currency.displayCurrency == 'SAR' ? 'ر.س' : 'ر.ي'})',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: sellingPrice,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: InputDecoration(
                                  labelText:
                                      'سعر البيع (${_currency.displayCurrency == 'SAR' ? 'ر.س' : 'ر.ي'})',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: quantity,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration:
                                    const InputDecoration(labelText: 'الكمية'),
                              ),
                            ),
                            IconButton(
                              tooltip: 'إضافة الصنف',
                              onPressed: () {
                                final line = PurchaseLineInput(
                                  productId: selectedProduct?.id,
                                  barcode: barcode.text.trim(),
                                  productName: name.text.trim(),
                                  unitPrice: _toYer(
                                      double.tryParse(purchasePrice.text) ??
                                          -1),
                                  sellingPrice: _toYer(
                                      double.tryParse(sellingPrice.text) ?? -1),
                                  quantity: double.tryParse(quantity.text) ?? 0,
                                );
                                if (line.barcode.isEmpty ||
                                    line.productName.isEmpty ||
                                    line.unitPrice < 0 ||
                                    line.sellingPrice < 0 ||
                                    line.quantity <= 0) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'أدخل المنتج وسعر الشراء وسعر البيع والكمية بشكل صحيح')),
                                  );
                                  return;
                                }
                                setDialogState(() {
                                  lines.add(line);
                                  selectedProduct = null;
                                  barcode.clear();
                                  name.clear();
                                  purchasePrice.text = '0';
                                  sellingPrice.text = '0';
                                  quantity.text = '1';
                                });
                              },
                              icon: const Icon(Icons.add_circle, size: 32),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (lines.isEmpty)
                          const Text('لم تتم إضافة أصناف بعد')
                        else
                          ...lines.asMap().entries.map(
                                (entry) => ListTile(
                                  dense: true,
                                  title: Text(entry.value.productName),
                                  subtitle: Text(
                                    '${entry.value.quantity} × شراء ${_money(entry.value.unitPrice)} • بيع ${_money(entry.value.sellingPrice)}',
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _money(service.lineTotal(entry.value)),
                                      ),
                                      IconButton(
                                        onPressed: () => setDialogState(
                                          () => lines.removeAt(entry.key),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        TextField(
                          controller: discount,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'خصم الفاتورة (${_currency.displayCurrency == 'SAR' ? 'ر.س' : 'ر.ي'})',
                          ),
                          onChanged: (_) => setDialogState(() {}),
                        ),
                        TextField(
                          controller: paid,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText:
                                'المدفوع (${_currency.displayCurrency == 'SAR' ? 'ر.س' : 'ر.ي'})',
                          ),
                        ),
                        TextField(
                          controller: notes,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات',
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'الإجمالي: ${_money(totalYer)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton(
                  onPressed: () async {
                    if (!formKey.currentState!.validate() || lines.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('أضف صنفًا واحدًا على الأقل'),
                        ),
                      );
                      return;
                    }
                    try {
                      final discountDisplay =
                          double.tryParse(discount.text) ?? 0;
                      final discountYer = _toYer(discountDisplay);
                      final subtotalYer = lines.fold<double>(
                        0,
                        (sum, line) => sum + service.lineTotal(line),
                      );
                      final totalYer = (subtotalYer - discountYer)
                          .clamp(0, double.infinity)
                          .toDouble();
                      if (discountYer > subtotalYer) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('الخصم أكبر من إجمالي الفاتورة')),
                        );
                        return;
                      }
                      if (payment == 'cash') {
                        paid.text = _currency
                            .fromYer(totalYer,
                                currency: _currency.displayCurrency)
                            .toStringAsFixed(2);
                      }
                      final paidDisplay = double.tryParse(paid.text) ?? 0;
                      final paidYer = _toYer(paidDisplay);
                      if (paidYer > totalYer) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content: Text('المبلغ المدفوع أكبر من الإجمالي')),
                        );
                        return;
                      }
                      final purchaseId = await ref
                          .read(purchaseServiceProvider)
                          .createPurchase(
                            invoiceNumber: null,
                            items: lines,
                            discount: discountYer,
                            paid: paidYer,
                            paymentMethod: payment,
                            supplierId: selectedSupplier?.id,
                            notes: notes.text.trim().isEmpty
                                ? null
                                : notes.text.trim(),
                          );
                      final savedPurchase = await ref
                          .read(purchasesDaoProvider)
                          .getById(purchaseId);
                      final savedInvoice =
                          savedPurchase?.invoiceNumber ?? purchaseId.toString();

                      await AuditService().log(
                        user: ref.read(authSessionProvider).currentUser?.username ??
                            'غير معروف',
                        action: 'تسجيل شراء',
                        details:
                            'الفاتورة $savedInvoice • الإجمالي ${_money(totalYer)}',
                      );
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                      if (mounted) setState(() {});
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(error.toString())),
                        );
                      }
                    }
                  },
                  child: const Text('حفظ الفاتورة'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      invoice.dispose();
      barcode.dispose();
      name.dispose();
      purchasePrice.dispose();
      sellingPrice.dispose();
      quantity.dispose();
      discount.dispose();
      paid.dispose();
      notes.dispose();
      supplierSearchCtrl.dispose();
      productSearchCtrl.dispose();
    }
  }

  Future<List<_PurchaseDisplayItem>> _fetchFilteredPurchases() async {
    final purchasesDao = ref.read(purchasesDaoProvider);
    final suppliersDao = ref.read(suppliersDaoProvider);
    final itemsDao = ref.read(purchaseItemsDaoProvider);

    final allPurchases = await purchasesDao.search('');
    final allSuppliers = await suppliersDao.getAll();
    final suppliersMap = {for (var s in allSuppliers) s.id: s.name};

    final query = _search.trim().toLowerCase();
    final List<_PurchaseDisplayItem> resultList = [];

    for (final purchase in allPurchases) {
      final supplierName = suppliersMap[purchase.supplierId] ?? 'بدون مورد';
      
final items = await itemsDao.byPurchase(purchase.id);

      final productNames = items.map((i) => i.productName).join(', ');
      final barcodes = items.map((i) => i.barcode).join(', ');

      final matchesQuery = query.isEmpty ||
          purchase.invoiceNumber.toLowerCase().contains(query) ||
          purchase.paymentMethod.toLowerCase().contains(query) ||
          supplierName.toLowerCase().contains(query) ||
          productNames.toLowerCase().contains(query) ||
          barcodes.toLowerCase().contains(query);

      if (matchesQuery) {
        resultList.add(_PurchaseDisplayItem(
          purchase: purchase,
          supplierName: supplierName,
          productSummary: productNames.isEmpty ? 'لا توجد أصناف' : productNames,
        ));
      }
    }

    return resultList;
  }

  @override
  Widget build(BuildContext context) {
    if (!_currencyReady) return const Center(child: CircularProgressIndicator());
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('إدارة المشتريات'),
          actions: [
            IconButton(
              tooltip: 'تحديث',
              onPressed: () => setState(() {}),
              icon: const Icon(Icons.refresh),
            ),
            IconButton(
              tooltip: 'إضافة شراء',
              onPressed: _newPurchase,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: TextField(
                  onChanged: (value) => setState(() => _search = value),
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    hintText: 'ابحث برقم الفاتورة، اسم المورد، أو اسم المنتج...',
                    suffixIcon: _search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'مسح البحث',
                            onPressed: () => setState(() => _search = ''),
                            icon: const Icon(Icons.clear, size: 18),
                          ),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<_PurchaseDisplayItem>>(
                  future: _fetchFilteredPurchases(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text('تعذر تحميل المشتريات: ${snapshot.error}'),
                      );
                    }
                    final items = snapshot.data ?? [];
                    if (items.isEmpty) {
                      return const Center(
                        child: Text(
                          'لا توجد فواتير شراء مطابقة للبحث',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final displayItem = items[index];
                        final purchase = displayItem.purchase;
                        return ListTile(
                          dense: true,
                          leading: const CircleAvatar(
                            radius: 18,
                            child: Icon(Icons.shopping_cart, size: 20),
                          ),
                          title: Text(
                            'فاتورة: ${purchase.invoiceNumber} • المورد: ${displayItem.supplierName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          subtitle: Text(
                            'المنتجات: ${displayItem.productSummary}\nالتاريخ: ${purchase.purchaseDate.toLocal().toString().split('.')[0]} | الحالة: ${purchase.status} | المتبقي: ${_money(purchase.remaining)}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          isThreeLine: true,
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _money(purchase.total),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: Colors.teal,
                                ),
                              ),
                              if (purchase.status != 'cancelled')
                                InkWell(
                                  onTap: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('إلغاء الفاتورة'),
                                        content: Text(
                                            'هل أنت متأكد من إلغاء الفاتورة ${purchase.invoiceNumber}؟'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, false),
                                            child: const Text('لا'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, true),
                                            child: const Text('نعم'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await ref
                                          .read(purchaseServiceProvider)
                                          .cancelPurchase(purchase.id);
                                      if (mounted) setState(() {});
                                    }
                                  },
                                  child: const Text(
                                    'إلغاء',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontSize: 11,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PurchaseDisplayItem {
  final Purchase purchase;
  final String supplierName;
  final String productSummary;

  _PurchaseDisplayItem({
    required this.purchase,
    required this.supplierName,
    required this.productSummary,
  });
}
