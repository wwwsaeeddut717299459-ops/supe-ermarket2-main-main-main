import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/invoice_settings_table.dart';

part 'invoice_settings_dao.g.dart';

@DriftAccessor(tables: [InvoiceSettings])
class InvoiceSettingsDao extends DatabaseAccessor<AppDatabase>
    with _$InvoiceSettingsDaoMixin {
  InvoiceSettingsDao(super.db);

  Future<InvoiceSetting?> getSettings() {
    return (select(invoiceSettings)
          ..orderBy([
            (item) => OrderingTerm(
                  expression: item.id,
                  mode: OrderingMode.asc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
  }

  Future<int> insertSettings(
    InvoiceSettingsCompanion settings,
  ) {
    return into(invoiceSettings).insert(settings);
  }

  Future<bool> updateSettings(
    InvoiceSettingsCompanion settings,
  ) {
    return update(invoiceSettings).replace(settings);
  }
}