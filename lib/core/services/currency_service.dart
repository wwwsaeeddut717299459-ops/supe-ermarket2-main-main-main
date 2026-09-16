
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// إدارة العملتين في النظام.
///
/// كل القيم المالية داخل قاعدة البيانات تبقى بالريال اليمني (YER)
/// كعملة أساس حتى لا تتأثر القيود والديون عند تغيير سعر الصرف.
/// هذه الخدمة مسؤولة عن سعر الصرف والتحويل والعرض.
class CurrencyService {
  static const double defaultSarToYer = 410.0;

  double sarToYer = defaultSarToYer;

  String displayCurrency = 'YER';

  bool _printingEnabled = true;

  bool get printingEnabled => _printingEnabled;

  Future<File> settingsFile() async {
    final directory = await getApplicationSupportDirectory();
    final file = File(p.join(directory.path, 'currency_settings.json'));
    await file.parent.create(recursive: true);
    return file;
  }

  Future<void> load() async {
    try {
      final file = await settingsFile();
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
      final rate = (data['sarToYer'] as num?)?.toDouble();
      if (rate != null && rate > 0) sarToYer = rate;
      final currency = data['displayCurrency']?.toString();
      if (currency == 'YER' || currency == 'SAR') displayCurrency = currency!;
      final printing = data['printingEnabled'];
      if (printing is bool) _printingEnabled = printing;
    } catch (_) {
      // استخدام القيم الافتراضية إذا كان ملف الإعدادات غير صالح.
    }
  }

  Future<void> setPrintingEnabled(bool enabled) async {
    _printingEnabled = enabled;
    final file = await settingsFile();
    Map<String, dynamic> data = {};
    if (await file.exists()) {
      try { data = jsonDecode(await file.readAsString()) as Map<String, dynamic>; } catch (_) {}
    }
    data['printingEnabled'] = enabled;
    await file.writeAsString(jsonEncode(data));
  }

  Future<void> save({
    required double sarToYer,
    String? displayCurrency,
  }) async {
    if (sarToYer <= 0) {
      throw ArgumentError('سعر الصرف يجب أن يكون أكبر من صفر');
    }
    this.sarToYer = sarToYer;
    if (displayCurrency == 'YER' || displayCurrency == 'SAR') {
      this.displayCurrency = displayCurrency!;
    }
    final file = await settingsFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert({
        'format': 'supermarket-currency-settings',
        'version': 1,
        'sarToYer': this.sarToYer,
        'displayCurrency': this.displayCurrency,
        'printingEnabled': _printingEnabled,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      }),
      flush: true,
    );
  }

  double toYer(double amount, {String? currency}) {
    if (!amount.isFinite) throw ArgumentError('المبلغ غير صالح');
    final code = currency ?? displayCurrency;
    if (code != 'YER' && code != 'SAR') {
      throw ArgumentError('العملة غير مدعومة: $code');
    }
    return code == 'SAR' ? amount * sarToYer : amount;
  }

  double fromYer(double amount, {String? currency}) {
    if (!amount.isFinite) throw ArgumentError('المبلغ غير صالح');
    final code = currency ?? displayCurrency;
    if (code != 'YER' && code != 'SAR') {
      throw ArgumentError('العملة غير مدعومة: $code');
    }
    return code == 'SAR' ? amount / sarToYer : amount;
  }

  double convert(
    double amount, {
    required String from,
    required String to,
  }) {
    if (!amount.isFinite) throw ArgumentError('المبلغ غير صالح');
    if ((from != 'YER' && from != 'SAR') ||
        (to != 'YER' && to != 'SAR')) {
      throw ArgumentError('العملة غير مدعومة');
    }
    if (from == to) return amount;
    return from == 'SAR' ? amount * sarToYer : amount / sarToYer;
  }

  String symbol([String? currency]) =>
      (currency ?? displayCurrency) == 'SAR' ? 'ر.س' : 'ر.ي';

  String name([String? currency]) =>
      (currency ?? displayCurrency) == 'SAR'
          ? 'ريال سعودي'
          : 'ريال يمني';

  String format(double amount, {String? currency, int decimals = 2}) {
    final code = currency ?? displayCurrency;
    return '${amount.toStringAsFixed(decimals)} ${symbol(code)}';
  }

  String formatBothFromYer(double yerAmount) {
    final sar = fromYer(yerAmount, currency: 'SAR');
    return '${format(yerAmount, currency: 'YER')}  |  ${format(sar, currency: 'SAR')}';
  }
}
