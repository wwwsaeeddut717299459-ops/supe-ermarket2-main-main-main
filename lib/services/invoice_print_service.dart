import "dart:typed_data";
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../database/app_database.dart';

class InvoicePrintService {
  static Future<Uint8List> buildPreviewPdf(InvoiceSetting settings) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.notoSansArabicRegular();
    final bold = await PdfGoogleFonts.notoSansArabicBold();
    doc.addPage(pw.Page(theme: pw.ThemeData.withFont(base: font, bold: bold), build: (_) => pw.Directionality(textDirection: pw.TextDirection.rtl, child: pw.Column(children: [pw.Text(settings.shopName, style: pw.TextStyle(font: bold, fontSize: 22)), if (settings.address != null) pw.Text(settings.address!), if (settings.phone != null) pw.Text(settings.phone!), pw.Divider(), pw.Text('معاينة فاتورة'), pw.Text('هذه معاينة حقيقية حسب إعداداتك'), if (settings.footerMessage != null) pw.Text(settings.footerMessage!)]))));
    return doc.save();
  }

  static Future<void> printSale({
    required Sale sale,
    required List<SaleItem> items,
    required InvoiceSetting settings,
  }) async {
    final doc = pw.Document();
    final width = settings.paperSize == 'thermal58' ? 58 : settings.paperSize == 'a4' ? 210 : 80;
    final pageFormat = settings.paperSize == 'a4'
        ? PdfPageFormat.a4
        : PdfPageFormat(width * PdfPageFormat.mm, double.infinity, marginAll: 4 * PdfPageFormat.mm);
    final font = await PdfGoogleFonts.notoSansArabicRegular();
    final bold = await PdfGoogleFonts.notoSansArabicBold();
    doc.addPage(pw.Page(pageFormat: pageFormat, theme: pw.ThemeData.withFont(base: font, bold: bold), build: (context) => pw.Directionality(
      textDirection: pw.TextDirection.rtl,
      child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
        pw.Center(child: pw.Text(settings.shopName, style: pw.TextStyle(font: bold, fontSize: 18))),
        if (settings.address != null) pw.Center(child: pw.Text(settings.address!)),
        if (settings.phone != null) pw.Center(child: pw.Text(settings.phone!)),
        pw.Divider(),
        if (settings.showInvoiceNumber) pw.Text('رقم الفاتورة: ${sale.invoiceNumber}'),
        if (settings.showDate) pw.Text('التاريخ: ${sale.saleDate}'),
        pw.SizedBox(height: 8),
        pw.Table(border: pw.TableBorder.all(width: .4), children: [
          pw.TableRow(children: ['الصنف','الكمية','السعر','الإجمالي'].map((x)=>pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(x, style: pw.TextStyle(font: bold, fontSize: 9)))).toList()),
          ...items.map((i)=>pw.TableRow(children: [i.productName, i.quantity.toString(), i.unitPrice.toStringAsFixed(2), i.total.toStringAsFixed(2)].map((x)=>pw.Padding(padding: const pw.EdgeInsets.all(3), child: pw.Text(x, style: const pw.TextStyle(fontSize: 8)))).toList())),
        ]),
        pw.SizedBox(height: 8),
        pw.Text('الإجمالي: ${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(font: bold, fontSize: 13)),
        if (settings.showPaid) pw.Text('المدفوع: ${sale.paid.toStringAsFixed(2)}'),
        if (settings.showRemaining) pw.Text('المتبقي: ${sale.remaining.toStringAsFixed(2)}'),
        if (settings.showPaymentMethod) pw.Text('طريقة الدفع: ${sale.paymentMethod == 'cash' ? 'نقداً' : 'آجل'}'),
        if (settings.showNotes && sale.notes != null) pw.Text('ملاحظات: ${sale.notes}'),
        pw.SizedBox(height: 12),
        if (settings.footerMessage != null) pw.Center(child: pw.Text(settings.footerMessage!)),
      ]),
    )));
    await Printing.layoutPdf(onLayout: (PdfPageFormat format) async => Uint8List.fromList(await doc.save()));
  }
}
