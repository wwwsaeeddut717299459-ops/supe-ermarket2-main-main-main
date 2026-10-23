import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:almajed_pro/features/invoices/data/services/invoice_print_service.dart';

import 'package:almajed_pro/core/providers/database_providers.dart';
import 'package:almajed_pro/core/providers/currency_providers.dart';

class InvoiceSettingsPage extends ConsumerStatefulWidget {
  const InvoiceSettingsPage({super.key});

  @override
  ConsumerState<InvoiceSettingsPage> createState() =>
      _InvoiceSettingsPageState();
}

class _InvoiceSettingsPageState
    extends ConsumerState<InvoiceSettingsPage> {
  final _formKey = GlobalKey<FormState>();

  final _shopNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _taxNumberController = TextEditingController();
  final _footerController = TextEditingController();
  final _sarToYerController = TextEditingController();

  String _paperSize = 'thermal80';
  String _displayCurrency = 'YER';

  bool _showInvoiceNumber = true;
  bool _showDate = true;
  bool _showBarcode = true;
  bool _showDiscount = true;
  bool _showPaid = true;
  bool _showRemaining = true;
  bool _showPaymentMethod = true;
  bool _showNotes = true;
  bool _printingEnabled = true;

  List<Printer> _printers = const [];
  String? _selectedPrinterName;
  bool _loadingPrinters = false;

  int? _settingsId;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadPrinters();
  }

  @override
  void dispose() {
    _shopNameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _taxNumberController.dispose();
    _footerController.dispose();
    _sarToYerController.dispose();

    super.dispose();
  }

  Future<void> _loadSettings() async {
    try {
      final repository =
          ref.read(invoiceSettingsRepositoryProvider);

      final currency = ref.read(currencyServiceProvider);
      await currency.load();

      final settings =
          await repository.getOrCreate();

      if (!mounted) return;

      setState(() {
        _settingsId = settings.id;

        _shopNameController.text =
            settings.shopName;

        _addressController.text =
            settings.address ?? '';

        _phoneController.text =
            settings.phone ?? '';

        _taxNumberController.text =
            settings.taxNumber ?? '';

        _footerController.text =
            settings.footerMessage ?? '';

        _paperSize = settings.paperSize;
        _sarToYerController.text = currency.sarToYer.toStringAsFixed(2);
        _displayCurrency = currency.displayCurrency;

        _showInvoiceNumber =
            settings.showInvoiceNumber;

        _showDate =
            settings.showDate;

        _showBarcode =
            settings.showBarcode;

        _showDiscount =
            settings.showDiscount;

        _showPaid =
            settings.showPaid;

        _showRemaining =
            settings.showRemaining;

        _showPaymentMethod =
            settings.showPaymentMethod;

        _showNotes =
            settings.showNotes;
        _printingEnabled = currency.printingEnabled;

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        'تعذر تحميل إعدادات الفاتورة:\n$e',
      );
    }
  }

  Future<void> _loadPrinters() async {
    if (mounted) setState(() => _loadingPrinters = true);
    try {
      final printers = await InvoicePrintService.listAvailablePrinters();
      final saved = await InvoicePrintService.getSelectedPrinterName();
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _selectedPrinterName = saved != null && printers.any((p) => p.name == saved)
            ? saved
            : (printers.length == 1 ? printers.first.name : saved);
      });
    } catch (_) {
      if (mounted) setState(() => _printers = const []);
    } finally {
      if (mounted) setState(() => _loadingPrinters = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_settingsId == null) {
      return;
    }

    setState(() {
      _saving = true;
    });

    try {
      final repository =
          ref.read(invoiceSettingsRepositoryProvider);

      final sarToYer = double.tryParse(_sarToYerController.text.trim());
      if (sarToYer == null || sarToYer <= 0) {
        _showMessage('أدخل سعر صرف صحيح: 1 ريال سعودي = كم ريال يمني؟');
        return;
      }

      await ref.read(currencyServiceProvider).setPrintingEnabled(_printingEnabled);
      await InvoicePrintService.setSelectedPrinterName(_selectedPrinterName);

      await ref.read(currencyServiceProvider).save(
        sarToYer: sarToYer,
        displayCurrency: _displayCurrency,
      );

      await repository.save(
        id: _settingsId!,
        shopName:
            _shopNameController.text.trim(),
        address:
            _emptyToNull(_addressController.text),
        phone:
            _emptyToNull(_phoneController.text),
        taxNumber:
            _emptyToNull(_taxNumberController.text),
        footerMessage:
            _emptyToNull(_footerController.text),
        paperSize: _paperSize,
        showInvoiceNumber:
            _showInvoiceNumber,
        showDate:
            _showDate,
        showBarcode:
            _showBarcode,
        showDiscount:
            _showDiscount,
        showPaid:
            _showPaid,
        showRemaining:
            _showRemaining,
        showPaymentMethod:
            _showPaymentMethod,
        showNotes:
            _showNotes,
      );

      if (!mounted) return;

      _showMessage(
        'تم حفظ إعدادات الفاتورة',
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage(
        'تعذر حفظ الإعدادات:\n$e',
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String? _emptyToNull(String value) {
    final text = value.trim();

    return text.isEmpty ? null : text;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'إعدادات الفاتورة والطباعة',
        ),
        actions: [
          FilledButton.icon(
            onPressed:
                _loading || _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child:
                        CircularProgressIndicator(
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.save),
            label: const Text('حفظ'),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: ConstrainedBox(
                    constraints:
                        const BoxConstraints(
                      maxWidth: 900,
                    ),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        _buildShopInfo(),
                        const SizedBox(height: 20),
                        _buildCurrencySettings(),
                        const SizedBox(height: 20),
                        _buildPaperSize(),
                        const SizedBox(height: 20),
                        _buildVisibilitySettings(),
                        const SizedBox(height: 20),
                        _buildPrintingToggle(),
                        const SizedBox(height: 20),
                        _buildPrinterSettings(),
                        const SizedBox(height: 20),
                        _buildPreviewCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildShopInfo() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'بيانات المحل',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            TextFormField(
              controller: _shopNameController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'اسم المحل',
                prefixIcon:
                    Icon(Icons.store),
                border:
                    OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null ||
                    value.trim().isEmpty) {
                  return 'أدخل اسم المحل';
                }

                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText: 'العنوان',
                prefixIcon:
                    Icon(Icons.location_on),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              onChanged: (_) => setState(() {}),
              keyboardType:
                  TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'رقم الهاتف',
                prefixIcon:
                    Icon(Icons.phone),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller:
                  _taxNumberController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                labelText:
                    'الرقم الضريبي - اختياري',
                prefixIcon:
                    Icon(Icons.receipt_long),
                border:
                    OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller:
                  _footerController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              decoration: const InputDecoration(
                labelText:
                    'الرسالة أسفل الفاتورة',
                hintText:
                    'شكراً لتعاملكم معنا',
                prefixIcon:
                    Icon(Icons.message),
                border:
                    OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrencySettings() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.currency_exchange_rounded,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Text(
                  'العملات وسعر الصرف',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'يتم حفظ الحسابات داخلياً بالريال اليمني كعملة أساس، ويحوّل النظام تلقائياً عند العرض أو الإدخال بالريال السعودي.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            TextFormField(
              controller: _sarToYerController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'سعر الريال السعودي مقابل اليمني',
                hintText: 'مثال: 410',
                prefixIcon: Icon(Icons.swap_horiz_rounded),
                suffixText: 'ريال يمني لكل 1 ريال سعودي',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                final rate = double.tryParse(value?.trim() ?? '');
                if (rate == null || rate <= 0) return 'أدخل سعراً صحيحاً أكبر من صفر';
                return null;
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _displayCurrency,
              decoration: const InputDecoration(
                labelText: 'عملة العرض والإدخال الافتراضية',
                prefixIcon: Icon(Icons.payments_outlined),
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'YER', child: Text('الريال اليمني (ر.ي)')),
                DropdownMenuItem(value: 'SAR', child: Text('الريال السعودي (ر.س)')),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _displayCurrency = value);
              },
            ),
            const SizedBox(height: 14),
            Builder(
              builder: (_) {
                final rate = double.tryParse(_sarToYerController.text) ?? 0;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    rate > 0
                        ? 'مثال: 1,000 ر.س = ${(rate * 1000).toStringAsFixed(0)} ر.ي'
                        : 'أدخل سعر الصرف لرؤية المثال',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaperSize() {
    final options = <Map<String, dynamic>>[
      {
        'value': 'thermal58',
        'title': 'حراري 58 mm',
        'subtitle': 'أصغر مقاس — إيصال سريع ومختصر للمحلات الصغيرة',
        'icon': Icons.receipt_long_rounded,
      },
      {
        'value': 'thermal80',
        'title': 'حراري 80 mm',
        'subtitle': 'المقاس الاحترافي الأكثر استخداماً في نقاط البيع',
        'icon': Icons.receipt_rounded,
      },
      {
        'value': 'a6',
        'title': 'A6 — 105 × 148 mm',
        'subtitle': 'فاتورة صغيرة للطباعة العادية',
        'icon': Icons.description_outlined,
      },
      {
        'value': 'a5',
        'title': 'A5 — 148 × 210 mm',
        'subtitle': 'فاتورة متوسطة بتفاصيل أكثر',
        'icon': Icons.article_outlined,
      },
      {
        'value': 'a4',
        'title': 'A4 — 210 × 297 mm',
        'subtitle': 'أكبر مقاس — فاتورة كاملة ومفصلة',
        'icon': Icons.description_rounded,
      },
    ];

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.straighten_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Text('نوع وحجم الفاتورة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'اختر المقاس من الأصغر إلى الأكبر. المعاينة والطباعة تتغيران تلقائياً حسب المقاس المختار.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ...options.map((option) {
              final selected = _paperSize == option['value'];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => setState(() => _paperSize = option['value'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.45),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(option['icon'] as IconData, size: 26, color: selected ? Theme.of(context).colorScheme.primary : null),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(option['title'] as String, style: const TextStyle(fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(option['subtitle'] as String, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        Radio<String>(
                          value: option['value'] as String,
                          groupValue: _paperSize,
                          onChanged: (value) {
                            if (value != null) setState(() => _paperSize = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildVisibilitySettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'محتويات الفاتورة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            SwitchListTile(
              title:
                  const Text('رقم الفاتورة'),
              value: _showInvoiceNumber,
              onChanged: (value) {
                setState(() {
                  _showInvoiceNumber =
                      value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('التاريخ'),
              value: _showDate,
              onChanged: (value) {
                setState(() {
                  _showDate = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('الباركود'),
              value: _showBarcode,
              onChanged: (value) {
                setState(() {
                  _showBarcode = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('الخصم'),
              value: _showDiscount,
              onChanged: (value) {
                setState(() {
                  _showDiscount = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('المدفوع'),
              value: _showPaid,
              onChanged: (value) {
                setState(() {
                  _showPaid = value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('المتبقي / الباقي'),
              value: _showRemaining,
              onChanged: (value) {
                setState(() {
                  _showRemaining = value;
                });
              },
            ),

            SwitchListTile(
              title:
                  const Text('طريقة الدفع'),
              value: _showPaymentMethod,
              onChanged: (value) {
                setState(() {
                  _showPaymentMethod =
                      value;
                });
              },
            ),

            SwitchListTile(
              title: const Text('الملاحظات'),
              value: _showNotes,
              onChanged: (value) {
                setState(() {
                  _showNotes = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrintingToggle() {
    return Card(
      child: SwitchListTile.adaptive(
        secondary: Icon(_printingEnabled ? Icons.print_rounded : Icons.print_disabled_rounded),
        title: const Text('الطباعة التلقائية بعد البيع'),
        subtitle: Text(_printingEnabled ? 'مفعّلة — سيتم طباعة الفاتورة بعد حفظ البيع' : 'متوقفة — سيتم البيع بدون طباعة فواتير'),
        value: _printingEnabled,
        onChanged: (value) => setState(() => _printingEnabled = value),
      ),
    );
  }

  Widget _buildPrinterSettings() {
    final hasSelected = _selectedPrinterName != null &&
        _printers.any((p) => p.name == _selectedPrinterName);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.print_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('الطابعة المرتبطة بالتطبيق', style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  tooltip: 'تحديث قائمة الطابعات',
                  onPressed: _loadingPrinters ? null : _loadPrinters,
                  icon: _loadingPrinters
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'اختر طابعة Windows مرة واحدة. بعد ذلك سيطبع التطبيق عليها تلقائياً عند إتمام البيع.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            if (_printers.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded),
                    SizedBox(width: 10),
                    Expanded(child: Text('لم يتم العثور على طابعة متاحة. ثبّت تعريف الطابعة ووصلها ثم اضغط تحديث.')),
                  ],
                ),
              )
            else
              DropdownButtonFormField<String>(
                value: hasSelected ? _selectedPrinterName : null,
                decoration: const InputDecoration(
                  labelText: 'الطابعة',
                  prefixIcon: Icon(Icons.print_outlined),
                  border: OutlineInputBorder(),
                ),
                items: _printers.map((printer) {
                  return DropdownMenuItem<String>(
                    value: printer.name,
                    child: Text(printer.name, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (value) => setState(() => _selectedPrinterName = value),
                validator: (_) => _printingEnabled && _selectedPrinterName == null
                    ? 'اختر الطابعة التي سيستخدمها التطبيق'
                    : null,
              ),
            if (_selectedPrinterName != null && !hasSelected)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'الطابعة المحفوظة غير متاحة حالياً: $_selectedPrinterName',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewCard() {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.preview_rounded, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('معاينة الفاتورة', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                ),
                FilledButton.icon(
                  onPressed: _loading || _saving ? null : _openPreview,
                  icon: const Icon(Icons.open_in_new_rounded),
                  label: const Text('فتح المعاينة الكبيرة'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'المعاينة تستخدم نفس تصميم الطباعة، وتعرض الفاتورة بشكل واضح وكامل للمقاس المختار.',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 620),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [BoxShadow(blurRadius: 24, spreadRadius: 1, offset: Offset(0, 10), color: Color(0x22000000))],
                  ),
                  padding: const EdgeInsets.all(26),
                  child: _buildLiveInvoicePreview(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveInvoicePreview() {
    final width = switch (_paperSize) {
      'thermal58' => 300.0,
      'thermal80' => 390.0,
      'a6' => 420.0,
      'a5' => 500.0,
      _ => 560.0,
    };
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: width,
      constraints: const BoxConstraints(minHeight: 500),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Theme.of(context).colorScheme.primary, width: 1.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(_shopNameController.text.trim().isEmpty ? 'الماجد PRO' : _shopNameController.text.trim(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('الماجد PRO • نظام المبيعات والمحاسبة', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w800, fontSize: 11)),
          if (_addressController.text.trim().isNotEmpty) Text(_addressController.text.trim(), style: const TextStyle(fontSize: 10)),
          if (_phoneController.text.trim().isNotEmpty) Text(_phoneController.text.trim(), style: const TextStyle(fontSize: 10)),
          if (_taxNumberController.text.trim().isNotEmpty) Text('الرقم الضريبي: ${_taxNumberController.text.trim()}', style: const TextStyle(fontSize: 10)),
          const SizedBox(height: 14),
          Container(height: 1, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            if (_showInvoiceNumber) const Text('رقم: INV-000125', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
            if (_showDate) const Text('13/09/2026 10:35 ص', style: TextStyle(fontSize: 10)),
          ]),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(6)),
            child: Table(
              columnWidths: const {0: FlexColumnWidth(3.5), 1: FlexColumnWidth(1), 2: FlexColumnWidth(1.4), 3: FlexColumnWidth(1.5)},
              border: TableBorder.symmetric(inside: BorderSide(color: Color(0xFFD8DED9))),
              children: [
                _previewTableRow(['الصنف', 'ك', 'السعر', 'الإجمالي'], header: true),
                _previewTableRow(['مياه معدنية', '2', '500', '1,000']),
                _previewTableRow(['أرز فاخر 5 كجم', '1', '6,500', '6,500']),
                _previewTableRow(['زيت طبخ', '2', '3,200', '6,400']),
                _previewTableRow(['سكر أبيض', '1', '1,800', '1,800']),
                _previewTableRow(['حليب كامل الدسم', '3', '900', '2,700']),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer.withOpacity(.55), borderRadius: BorderRadius.circular(8)),
            child: Column(children: [
              _previewSummary('المجموع الفرعي', '18,400.00'),
              if (_showDiscount) _previewSummary('الخصم', '-500.00'),
              const Divider(),
              _previewSummary('الإجمالي النهائي', '17,900.00', strong: true),
              if (_showPaid) _previewSummary('المدفوع', '17,900.00'),
              if (_showRemaining) _previewSummary('المتبقي / الباقي', '0.00'),
            ]),
          ),
          if (_showPaymentMethod) ...[
            const SizedBox(height: 10),
            const Text('طريقة الدفع: نقداً', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
          ],
          if (_showNotes) const Padding(padding: EdgeInsets.only(top: 7), child: Text('شكراً لتعاملكم معنا', style: TextStyle(fontSize: 10))),
          const SizedBox(height: 14),
          Container(height: 1, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 8),
          Text(_footerController.text.trim().isEmpty ? 'شكراً لتعاملكم معنا • نتشرف بخدمتكم دائماً' : _footerController.text.trim(), textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 10)),
        ],
      ),
    );
  }

  TableRow _previewTableRow(List<String> values, {bool header = false}) {
    return TableRow(
      decoration: header ? BoxDecoration(color: Theme.of(context).colorScheme.primary) : null,
      children: values.map((value) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
        child: Text(value, textAlign: TextAlign.center, style: TextStyle(color: header ? Colors.white : Colors.black87, fontSize: 9, fontWeight: header ? FontWeight.bold : FontWeight.normal)),
      )).toList(),
    );
  }

  Widget _previewSummary(String label, String value, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: strong ? 14 : 10, fontWeight: strong ? FontWeight.w900 : FontWeight.normal)),
        Text('$value ر.ي', style: TextStyle(fontSize: strong ? 14 : 10, fontWeight: strong ? FontWeight.w900 : FontWeight.normal)),
      ]),
    );
  }

  Future<void> _openPreview() async {
    try {
      final settings = await ref.read(invoiceSettingsRepositoryProvider).getOrCreate();
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          insetPadding: const EdgeInsets.all(24),
          child: SizedBox(
            width: 900,
            height: 820,
            child: PdfPreview(
              canChangePageFormat: false,
              canChangeOrientation: false,
              allowPrinting: false,
              allowSharing: false,
              pdfPreviewPageDecoration: const BoxDecoration(color: Color(0xFFE9EEEB)),
              build: (_) => InvoicePrintService.buildPreviewPdf(settings.copyWith(paperSize: _paperSize)),
            ),
          ),
        ),
      );
    } catch (e) {
      _showMessage('تعذر فتح المعاينة:\n$e');
    }
  }
}