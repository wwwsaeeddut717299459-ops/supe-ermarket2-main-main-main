import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../database/app_database.dart';

class InvoicePrintService {
  static const _accent = PdfColor.fromInt(0xFF1B7F5A);
  static const _dark = PdfColor.fromInt(0xFF17211D);
  static const _soft = PdfColor.fromInt(0xFFF1F6F3);
  static const _muted = PdfColor.fromInt(0xFF66736D);

  static Future<File> _printerSettingsFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(path.join(directory.path, 'printer_settings.json'));
    await file.parent.create(recursive: true);
    return file;
  }

  static Future<String?> getSelectedPrinterName() async {
    try {
      final file = await _printerSettingsFile();
      if (!await file.exists()) return null;
      final data = jsonDecode(await file.readAsString());
      if (data is Map && data['printerName'] is String) {
        final name = (data['printerName'] as String).trim();
        return name.isEmpty ? null : name;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> setSelectedPrinterName(String? name) async {
    final file = await _printerSettingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'format': 'almajed-printer-settings',
        'version': 1,
      }),
      flush: true,
    );
    if (name != null && name.trim().isNotEmpty) {
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      data['printerName'] = name.trim();
      await file.writeAsString(jsonEncode(data), flush: true);
    }
  }

  static Future<List<Printer>> listAvailablePrinters() async {
    final printers = await Printing.listPrinters();
    return printers.where((p) => p.isAvailable != false).toList();
  }

  static PdfPageFormat pageFormatFor(String paperSize, {int itemCount = 5}) {
    switch (paperSize) {
      case 'thermal58':
        final heightMm = (120 + itemCount * 8).toDouble();
        return PdfPageFormat(
          58 * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginAll: 3.5 * PdfPageFormat.mm,
        );
      case 'thermal80':
        final heightMm = (130 + itemCount * 8).toDouble();
        return PdfPageFormat(
          80 * PdfPageFormat.mm,
          heightMm * PdfPageFormat.mm,
          marginAll: 4 * PdfPageFormat.mm,
        );
      case 'a6':
        return PdfPageFormat.a6;
      case 'a5':
        return PdfPageFormat.a5;
      case 'a4':
      default:
        return PdfPageFormat.a4;
    }
  }

  static Future<Uint8List> buildPreviewPdf(InvoiceSetting settings) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansArabicRegular();
    final bold = await PdfGoogleFonts.notoSansArabicBold();
    final format = pageFormatFor(settings.paperSize, itemCount: 6);

    final sampleItems = <_PreviewItem>[
      const _PreviewItem('مياه معدنية', 2, 500),
      const _PreviewItem('أرز فاخر 5 كجم', 1, 6500),
      const _PreviewItem('زيت طبخ', 2, 3200),
      const _PreviewItem('سكر أبيض', 1, 1800),
      const _PreviewItem('حليب كامل الدسم', 3, 900),
      const _PreviewItem('بسكويت مشكل', 2, 750),
    ];
    final subtotal = sampleItems.fold<double>(
      0,
      (sum, item) => sum + item.quantity * item.price,
    );
    const discount = 500.0;
    final total = subtotal - discount;

    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        margin: pw.EdgeInsets.zero,
        build: (_) => _invoiceDocument(
          settings: settings,
          font: font,
          bold: bold,
          invoiceNumber: 'INV-000125',
          date: '13/09/2026  10:35 ص',
          items: sampleItems,
          subtotal: subtotal,
          discount: settings.showDiscount ? discount : 0,
          total: total,
          paid: total,
          remaining: 0,
          paymentMethod: 'نقداً',
          notes: 'شكراً لتعاملكم معنا',
          preview: true,
        ),
      ),
    );

    return doc.save();
  }

  static Future<void> printSale({
    required Sale sale,
    required List<SaleItem> items,
    required InvoiceSetting settings,
  }) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansArabicRegular();
    final bold = await PdfGoogleFonts.notoSansArabicBold();
    final format = pageFormatFor(settings.paperSize, itemCount: items.length);

    doc.addPage(
      pw.Page(
        pageFormat: format,
        theme: pw.ThemeData.withFont(base: font, bold: bold),
        margin: pw.EdgeInsets.zero,
        build: (_) => _invoiceDocument(
          settings: settings,
          font: font,
          bold: bold,
          invoiceNumber: sale.invoiceNumber,
          date: sale.saleDate.toString(),
          items: items
              .map(
                (item) => _PreviewItem(
                  item.productName,
                  item.quantity,
                  item.unitPrice,
                ),
              )
              .toList(),
          subtotal: sale.total + sale.discount,
          discount: settings.showDiscount ? sale.discount : 0,
          total: sale.total,
          paid: sale.paid,
          remaining: sale.remaining,
          paymentMethod: sale.paymentMethod == 'cash' ? 'نقداً' : 'آجل',
          notes: sale.notes,
        ),
      ),
    );

    final bytes = Uint8List.fromList(await doc.save());

    final available = await listAvailablePrinters();
    if (available.isEmpty) {
      throw Exception('لا توجد طابعة متاحة حالياً. قم بتوصيل الطابعة وتثبيت تعريفها ثم حاول الطباعة مرة أخرى.');
    }

    final selectedName = await getSelectedPrinterName();
    if (selectedName == null || selectedName.isEmpty) {
      throw Exception('لم يتم اختيار طابعة من إعدادات الطباعة.');
    }

    Printer? printer;
    for (final candidate in available) {
      if (candidate.name == selectedName) {
        printer = candidate;
        break;
      }
    }

    if (printer == null) {
      throw Exception('الطابعة المختارة "$selectedName" غير متصلة أو غير متاحة حالياً.');
    }

    final printed = await Printing.directPrintPdf(
      printer: printer,
      name: 'فاتورة ${sale.invoiceNumber}',
      format: format,
      dynamicLayout: false,
      usePrinterSettings: true,
      onLayout: (_) async => bytes,
    );

    if (!printed) {
      throw Exception('تعذر إرسال الفاتورة إلى الطابعة: ${printer.name}');
    }
  }

  static pw.Widget _invoiceDocument({
    required InvoiceSetting settings,
    required pw.Font font,
    required pw.Font bold,
    required String invoiceNumber,
    required String date,
    required List<_PreviewItem> items,
    required double subtotal,
    required double discount,
    required double total,
    required double paid,
    required double remaining,
    required String paymentMethod,
    String? notes,
    bool preview = false,
  }) {
    final narrow = settings.paperSize == 'thermal58' || settings.paperSize == 'thermal80';
    final veryNarrow = settings.paperSize == 'thermal58';
    final compact = narrow ? 6.5 : 9.0;
    final titleSize = veryNarrow ? 16.0 : narrow ? 19.0 : 24.0;
    final bodySize = veryNarrow ? 7.2 : narrow ? 8.2 : 9.5;
    final smallSize = veryNarrow ? 6.5 : narrow ? 7.2 : 8.5;

    return pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Container(
        width: double.infinity,
        padding: pw.EdgeInsets.all(narrow ? 4.0 * PdfPageFormat.mm : 8.0 * PdfPageFormat.mm),
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          border: pw.Border.all(color: _accent, width: narrow ? .8 : 1.2),
          borderRadius: pw.BorderRadius.circular(narrow ? 4 : 8),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.stretch,
          children: [
            pw.Container(
              padding: pw.EdgeInsets.only(bottom: compact),
              child: pw.Column(
                children: [
                  pw.Text(
                    settings.shopName.isEmpty ? 'اسم المحل' : settings.shopName,
                    textAlign: pw.TextAlign.center,
                    style: pw.TextStyle(font: bold, fontSize: titleSize, color: _dark),
                  ),
                  pw.SizedBox(height: 2),
                  if (settings.address != null && settings.address!.trim().isNotEmpty)
                    pw.Text(settings.address!, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: smallSize, color: _muted)),
                  if (settings.phone != null && settings.phone!.trim().isNotEmpty)
                    pw.Text(settings.phone!, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: smallSize, color: _muted)),
                  if (settings.taxNumber != null && settings.taxNumber!.trim().isNotEmpty)
                    pw.Text('الرقم الضريبي: ${settings.taxNumber}', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: smallSize, color: _muted)),
                ],
              ),
            ),
            pw.Container(
              padding: pw.EdgeInsets.symmetric(vertical: compact),
              decoration: const pw.BoxDecoration(
                color: _soft,
                border: pw.Border.symmetric(
                  horizontal: pw.BorderSide(color: _accent, width: .6),
                ),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (settings.showInvoiceNumber)
                    pw.Expanded(child: pw.Text('رقم: $invoiceNumber', style: pw.TextStyle(font: bold, fontSize: bodySize, color: _dark))),
                  if (settings.showDate)
                    pw.Text(date, style: pw.TextStyle(font: font, fontSize: bodySize, color: _dark)),
                ],
              ),
            ),
            pw.SizedBox(height: compact),
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey500, width: .45),
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Table(
                columnWidths: veryNarrow
                    ? {
                        0: const pw.FlexColumnWidth(3.6),
                        1: const pw.FlexColumnWidth(1.0),
                        2: const pw.FlexColumnWidth(1.4),
                        3: const pw.FlexColumnWidth(1.6),
                      }
                    : null,
                border: pw.TableBorder.symmetric(
                  inside: pw.BorderSide(color: PdfColors.grey400, width: .35),
                ),
                children: [
                  _tableRow(['الصنف', 'الكمية', 'السعر', 'الإجمالي'], bold, bodySize, header: true),
                  ...items.map(
                    (item) => _tableRow(
                      [
                        item.name,
                        _qty(item.quantity),
                        _money(item.price),
                        _money(item.quantity * item.price),
                      ],
                      font,
                      bodySize,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: compact),
            pw.Container(
              padding: pw.EdgeInsets.all(compact),
              decoration: pw.BoxDecoration(
                color: _soft,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Column(
                children: [
                  _summaryRow('المجموع الفرعي', subtotal, font, bodySize),
                  if (settings.showDiscount) _summaryRow('الخصم', discount, font, bodySize, negative: true),
                  pw.Divider(color: _accent, thickness: .7),
                  _summaryRow('الإجمالي النهائي', total, bold, veryNarrow ? 11 : narrow ? 13 : 16, strong: true),
                  if (paymentMethod == 'آجل' && settings.showPaid)
                    _summaryRow('المدفوع', paid, font, bodySize),
                  if (paymentMethod == 'آجل' && settings.showRemaining)
                    _summaryRow('المتبقي', remaining, font, bodySize),
                ],
              ),
            ),
            if (settings.showPaymentMethod || (settings.showNotes && notes != null && notes.trim().isNotEmpty))
              pw.SizedBox(height: compact),
            if (settings.showPaymentMethod)
              pw.Container(
                padding: pw.EdgeInsets.symmetric(vertical: compact),
                child: pw.Text(
                  'طريقة الدفع: $paymentMethod',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(font: bold, fontSize: bodySize, color: _dark),
                ),
              ),
            if (settings.showNotes && notes != null && notes.trim().isNotEmpty)
              pw.Text(notes, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: smallSize, color: _muted)),
            if (preview)
              pw.Padding(
                padding: pw.EdgeInsets.only(top: compact),
                child: pw.Text('هذه معاينة توضيحية • البيانات الحقيقية تظهر عند طباعة الفاتورة', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: font, fontSize: smallSize, color: _muted)),
              ),
            pw.SizedBox(height: compact),
            pw.Container(
              padding: pw.EdgeInsets.only(top: compact),
              decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: _accent, width: .6)),
              ),
              child: pw.Text(
                (settings.footerMessage == null || settings.footerMessage!.trim().isEmpty)
                    ? 'شكراً لتعاملكم معنا • نتشرف بخدمتكم دائماً'
                    : settings.footerMessage!,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(font: bold, fontSize: smallSize, color: _accent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static pw.TableRow _tableRow(
    List<String> values,
    pw.Font font,
    double size, {
    bool header = false,
  }) {
    return pw.TableRow(
      decoration: header ? const pw.BoxDecoration(color: _accent) : null,
      children: values
          .map(
            (value) => pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 4),
              child: pw.Text(
                value,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: font,
                  fontSize: size,
                  color: header ? PdfColors.white : _dark,
                  fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                ),
                maxLines: 2,
              ),
            ),
          )
          .toList(),
    );
  }

  static pw.Widget _summaryRow(
    String label,
    double value,
    pw.Font font,
    double size, {
    bool negative = false,
    bool strong = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: size, color: _dark)),
          pw.Text(
            '${negative ? '-' : ''}${_money(value)} ر.ي',
            style: pw.TextStyle(font: font, fontSize: size, color: _dark, fontWeight: strong ? pw.FontWeight.bold : pw.FontWeight.normal),
          ),
        ],
      ),
    );
  }

  static String _money(double value) => value.toStringAsFixed(2);
  static String _qty(double value) => value == value.roundToDouble() ? value.toInt().toString() : value.toStringAsFixed(2);
}

class _PreviewItem {
  final String name;
  final double quantity;
  final double price;

  const _PreviewItem(this.name, this.quantity, this.price);
}
