import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../database/daos/invoice_settings_dao.dart';

class InvoiceSettingsRepository {
  final InvoiceSettingsDao dao;

  InvoiceSettingsRepository(this.dao);

  Future<InvoiceSetting?> getSettings() {
    return dao.getSettings();
  }

  Future<InvoiceSetting> getOrCreate() async {
    final existing = await dao.getSettings();

    if (existing != null) {
      return existing;
    }

    await dao.insertSettings(
      InvoiceSettingsCompanion.insert(
        shopName: 'اسم المحل',
      ),
    );

    final settings = await dao.getSettings();

    if (settings == null) {
      throw Exception(
        'تعذر إنشاء إعدادات الفاتورة',
      );
    }

    return settings;
  }

  Future<bool> save({
    required int id,
    required String shopName,
    String? address,
    String? phone,
    String? taxNumber,
    String? footerMessage,
    required String paperSize,
    required bool showInvoiceNumber,
    required bool showDate,
    required bool showBarcode,
    required bool showDiscount,
    required bool showPaid,
    required bool showRemaining,
    required bool showPaymentMethod,
    required bool showNotes,
  }) {
    return dao.updateSettings(
      InvoiceSettingsCompanion(
        id: Value(id),
        shopName: Value(shopName),
        address: Value(address),
        phone: Value(phone),
        taxNumber: Value(taxNumber),
        footerMessage: Value(footerMessage),
        paperSize: Value(paperSize),
        showInvoiceNumber: Value(showInvoiceNumber),
        showDate: Value(showDate),
        showBarcode: Value(showBarcode),
        showDiscount: Value(showDiscount),
        showPaid: Value(showPaid),
        showRemaining: Value(showRemaining),
        showPaymentMethod: Value(showPaymentMethod),
        showNotes: Value(showNotes),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}