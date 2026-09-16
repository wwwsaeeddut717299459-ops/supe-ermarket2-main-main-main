// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'invoice_settings_dao.dart';

// ignore_for_file: type=lint
mixin _$InvoiceSettingsDaoMixin on DatabaseAccessor<AppDatabase> {
  $InvoiceSettingsTable get invoiceSettings => attachedDatabase.invoiceSettings;
  InvoiceSettingsDaoManager get managers => InvoiceSettingsDaoManager(this);
}

class InvoiceSettingsDaoManager {
  final _$InvoiceSettingsDaoMixin _db;
  InvoiceSettingsDaoManager(this._db);
  $$InvoiceSettingsTableTableManager get invoiceSettings =>
      $$InvoiceSettingsTableTableManager(
        _db.attachedDatabase,
        _db.invoiceSettings,
      );
}
