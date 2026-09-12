import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import '../../services/invoice_print_service.dart';

import '../../providers/database_providers.dart';
import '../../providers/currency_providers.dart';

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

  int? _settingsId;

  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'حجم الفاتورة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 16),

            RadioGroup<String>(
              groupValue: _paperSize,
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _paperSize = value;
                });
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    value: 'thermal58',
                    title:
                        Text('طابعة حرارية 58mm'),
                    subtitle: Text(
                      'مناسبة للفواتير الصغيرة',
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'thermal80',
                    title:
                        Text('طابعة حرارية 80mm'),
                    subtitle: Text(
                      'مناسبة لفواتير المحلات',
                    ),
                  ),
                  RadioListTile<String>(
                    value: 'a4',
                    title:
                        Text('طابعة عادية A4'),
                    subtitle: Text(
                      'فاتورة بحجم ورق A4',
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

  Widget _buildPreviewCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const Text(
              'المعاينة',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final settings = await ref.read(invoiceSettingsRepositoryProvider).getOrCreate();
                  if (!mounted) return;
                  await showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: SizedBox(
                        width: 420,
                        height: 650,
                        child: PdfPreview(
                          canChangePageFormat: false,
                          canChangeOrientation: false,
                          allowPrinting: false,
                          allowSharing: false,
                          build: (format) => InvoicePrintService.buildPreviewPdf(settings),
                        ),
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.preview),
                label: const Text(
                  'معاينة الفاتورة',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}