import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../database/app_database.dart';
import '../../../providers/database_providers.dart';
import '../../../services/returns_service.dart';

class ReturnsPage extends ConsumerStatefulWidget {
  const ReturnsPage({super.key});

  @override
  ConsumerState<ReturnsPage> createState() => _ReturnsPageState();
}

class _ReturnsPageState extends ConsumerState<ReturnsPage> {
  int _tab = 0;
  String _search = '';

  Future<void> _createReturn() async {
    if (_tab == 0) {
      await _createSaleReturnByBarcode();
    } else {
      await _createPurchaseReturnFromInvoice();
    }
  }

  Future<void> _createSaleReturnByBarcode() async {
    final barcode = TextEditingController();
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();

    SaleBarcodeReturnSource? source;
    double quantity = 1;
    bool loading = false;
    bool saving = false;

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> scan() async {
              if (!formKey.currentState!.validate()) return;

              setDialogState(() => loading = true);
              try {
                final result = await ref
                    .read(returnsServiceProvider)
                    .findSaleByBarcode(barcode.text);

                if (result == null) {
                  throw Exception(
                    'الصنف غير موجود في فواتير البيع أو تم إرجاع كامل الكمية.',
                  );
                }

                source = result;
                quantity = quantity.clamp(1, result.line.quantity).toDouble();

                if (context.mounted) {
                  setDialogState(() => loading = false);
                }
              } catch (e) {
                if (context.mounted) {
                  setDialogState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }

            Future<void> save() async {
              final current = source;
              if (current == null || quantity <= 0) return;

              setDialogState(() => saving = true);
              try {
                await ref.read(returnsServiceProvider).createSaleReturn(
                  saleId: current.saleId,
                  items: [
                    ReturnLineInput(
                      productId: current.line.productId,
                      productName: current.line.productName,
                      barcode: current.line.barcode,
                      unitPrice: current.line.unitPrice,
                      quantity: quantity,
                    ),
                  ],
                  reason: reason.text.trim().isEmpty
                      ? null
                      : reason.text.trim(),
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              } catch (e) {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }

            return AlertDialog(
              title: const Text('مرتجع مبيعات'),
              content: SizedBox(
                width: 620,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'امسح باركود الصنف مباشرة. لا تحتاج للبحث عن الفاتورة.',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: barcode,
                          autofocus: true,
                          onFieldSubmitted: (_) => scan(),
                          decoration: const InputDecoration(
                            labelText: 'باركود الصنف',
                            prefixIcon: Icon(Icons.qr_code_scanner),
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty
                              ? 'امسح باركود الصنف'
                              : null,
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: loading || saving ? null : scan,
                          icon: const Icon(Icons.search),
                          label: Text(loading ? 'جاري البحث...' : 'قراءة الباركود'),
                        ),
                        if (source != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    source!.line.productName,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text('الباركود: ${source!.line.barcode}'),
                                  Text('الفاتورة الأصلية: ${source!.invoiceNumber}'),
                                  Text(
                                    'المتاح للإرجاع: ${source!.line.quantity.toStringAsFixed(2)}',
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    children: [
                                      const Text('الكمية:'),
                                      IconButton(
                                        onPressed: saving || quantity <= 1
                                            ? null
                                            : () => setDialogState(
                                                () => quantity--,
                                              ),
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      Text(
                                        quantity.toStringAsFixed(
                                          quantity == quantity.roundToDouble() ? 0 : 2,
                                        ),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: saving ||
                                                quantity >= source!.line.quantity
                                            ? null
                                            : () => setDialogState(
                                                () => quantity++,
                                              ),
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                            labelText: 'سبب المرتجع (اختياري)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: source == null || saving ? null : save,
                  icon: const Icon(Icons.assignment_return),
                  label: Text(saving ? 'جاري الحفظ...' : 'إرجاع الصنف'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      barcode.dispose();
      reason.dispose();
    }
  }

  Future<void> _createPurchaseReturnFromInvoice() async {
    final invoice = TextEditingController();
    final reason = TextEditingController();
    final formKey = GlobalKey<FormState>();

    Purchase? purchase;
    List<ReturnLineInput> lines = [];
    final quantities = <int, double>{};
    bool loading = false;
    bool saving = false;

    try {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> loadInvoice() async {
              if (!formKey.currentState!.validate()) return;

              setDialogState(() => loading = true);
              try {
                final found = await ref
                    .read(purchasesDaoProvider)
                    .getByInvoiceNumber(invoice.text);

                if (found == null) {
                  throw Exception('فاتورة الشراء غير موجودة');
                }

                final loadedLines = await ref
                    .read(returnsServiceProvider)
                    .purchaseLines(found.id);

                if (loadedLines.isEmpty) {
                  throw Exception('الفاتورة لا تحتوي على أصناف قابلة للإرجاع');
                }

                purchase = found;
                lines = loadedLines;
                quantities
                  ..clear()
                  ..addEntries(
                    lines.map((line) => MapEntry(line.productId, 0)),
                  );

                if (context.mounted) {
                  setDialogState(() => loading = false);
                }
              } catch (e) {
                if (context.mounted) {
                  setDialogState(() => loading = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }

            void decrease(ReturnLineInput line) {
              final current = quantities[line.productId] ?? 0;
              if (current <= 0) return;
              setDialogState(() {
                quantities[line.productId] =
                    (current - 1).clamp(0, line.quantity).toDouble();
              });
            }

            void increase(ReturnLineInput line) {
              final current = quantities[line.productId] ?? 0;
              if (current >= line.quantity) return;
              setDialogState(() {
                quantities[line.productId] =
                    (current + 1).clamp(0, line.quantity).toDouble();
              });
            }

            void remove(ReturnLineInput line) {
              setDialogState(() => quantities[line.productId] = 0);
            }

            Future<void> save() async {
              final source = purchase;
              if (source == null) return;

              final items = <ReturnLineInput>[];
              for (final line in lines) {
                final q = quantities[line.productId] ?? 0;
                if (q > 0) {
                  items.add(
                    ReturnLineInput(
                      productId: line.productId,
                      productName: line.productName,
                      barcode: line.barcode,
                      unitPrice: line.unitPrice,
                      quantity: q,
                    ),
                  );
                }
              }

              if (items.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('اختر صنفاً واحداً على الأقل للإرجاع'),
                  ),
                );
                return;
              }

              setDialogState(() => saving = true);
              try {
                await ref.read(returnsServiceProvider).createPurchaseReturn(
                  purchaseId: source.id,
                  items: items,
                  reason: reason.text.trim().isEmpty
                      ? null
                      : reason.text.trim(),
                );

                if (dialogContext.mounted) Navigator.pop(dialogContext);
                if (mounted) setState(() {});
              } catch (e) {
                if (context.mounted) {
                  setDialogState(() => saving = false);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString())),
                  );
                }
              }
            }

            final selectedTotal = lines.fold<double>(
              0,
              (sum, line) =>
                  sum + (line.unitPrice * (quantities[line.productId] ?? 0)),
            );

            return AlertDialog(
              title: const Text('مرتجع مشتريات'),
              content: SizedBox(
                width: 900,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: invoice,
                                autofocus: true,
                                onFieldSubmitted: (_) => loadInvoice(),
                                decoration: const InputDecoration(
                                  labelText: 'رقم فاتورة الشراء',
                                  prefixIcon: Icon(Icons.receipt_long),
                                ),
                                validator: (value) =>
                                    value == null || value.trim().isEmpty
                                    ? 'أدخل رقم فاتورة الشراء'
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton.icon(
                              onPressed: loading || saving ? null : loadInvoice,
                              icon: const Icon(Icons.search),
                              label: Text(loading ? 'جاري التحميل...' : 'عرض الفاتورة'),
                            ),
                          ],
                        ),
                        if (purchase != null) ...[
                          const SizedBox(height: 16),
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Wrap(
                                spacing: 28,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    'الفاتورة: ${purchase!.invoiceNumber}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'التاريخ: ${purchase!.purchaseDate.toLocal()}',
                                  ),
                                  Text('الإجمالي: ${purchase!.total.toStringAsFixed(2)}'),
                                  Text('المدفوع: ${purchase!.paid.toStringAsFixed(2)}'),
                                  Text('المتبقي: ${purchase!.remaining.toStringAsFixed(2)}'),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'أصناف الفاتورة — استخدم − لإنقاص الكمية أو 🗑 لحذف الصنف من المرتجع.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          ...lines.map(
                            (line) {
                              final q = quantities[line.productId] ?? 0;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              line.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'باركود: ${line.barcode} • سعر الشراء: ${line.unitPrice.toStringAsFixed(2)}',
                                            ),
                                            Text(
                                              'المتاح للإرجاع: ${line.quantity.toStringAsFixed(2)}',
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'إنقاص',
                                        onPressed: saving ? null : () => decrease(line),
                                        icon: const Icon(Icons.remove_circle_outline),
                                      ),
                                      SizedBox(
                                        width: 54,
                                        child: Center(
                                          child: Text(
                                            q.toStringAsFixed(
                                              q == q.roundToDouble() ? 0 : 2,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                          ),
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'زيادة',
                                        onPressed: saving ? null : () => increase(line),
                                        icon: const Icon(Icons.add_circle_outline),
                                      ),
                                      IconButton(
                                        tooltip: 'حذف من المرتجع',
                                        onPressed: saving ? null : () => remove(line),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                          const Divider(),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'إجمالي المرتجع: ${selectedTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                            labelText: 'سبب المرتجع (اختياري)',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: saving ? null : () => Navigator.pop(dialogContext),
                  child: const Text('إلغاء'),
                ),
                FilledButton.icon(
                  onPressed: purchase == null || saving ? null : save,
                  icon: const Icon(Icons.assignment_return),
                  label: Text(saving ? 'جاري الحفظ...' : 'حفظ المرتجع'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      invoice.dispose();
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final dao = ref.watch(returnsDaoProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('المرتجعات'),
          actions: [
            IconButton(
              tooltip: _tab == 0
                  ? 'مرتجع بالباركود'
                  : 'مرتجع من فاتورة شراء',
              onPressed: _createReturn,
              icon: const Icon(Icons.assignment_return),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(
                          value: 0,
                          label: Text('مرتجعات المبيعات'),
                          icon: Icon(Icons.point_of_sale),
                        ),
                        ButtonSegment(
                          value: 1,
                          label: Text('مرتجعات المشتريات'),
                          icon: Icon(Icons.shopping_cart),
                        ),
                      ],
                      selected: {_tab},
                      onSelectionChanged: (value) =>
                          setState(() => _tab = value.first),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        labelText: 'بحث برقم المرتجع أو النوع',
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: FutureBuilder<List<Return>>(
                future: dao.search(_search),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('تعذر تحميل المرتجعات: ${snapshot.error}'),
                    );
                  }

                  final values = (snapshot.data ?? [])
                      .where(
                        (item) => _tab == 0
                            ? item.type == 'sale_return'
                            : item.type == 'purchase_return',
                      )
                      .toList();

                  if (values.isEmpty) {
                    return const Center(child: Text('لا توجد مرتجعات'));
                  }

                  return ListView.separated(
                    itemCount: values.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = values[index];
                      return ListTile(
                        leading: const Icon(Icons.assignment_return),
                        title: Text(item.returnNumber),
                        subtitle: Text(
                          '${item.returnDate.toLocal()}\n${item.reason ?? 'بدون سبب'}',
                        ),
                        trailing: Text(
                          item.total.toStringAsFixed(2),
                          style: const TextStyle(fontWeight: FontWeight.bold),
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
    );
  }
}
