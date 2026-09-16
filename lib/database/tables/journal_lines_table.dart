import 'package:drift/drift.dart';

import 'accounts_table.dart';
import 'journal_entries_table.dart';

class JournalLines extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get entryId => integer().references(JournalEntries, #id)();
  IntColumn get accountId => integer().references(Accounts, #id)();
  RealColumn get debit => real().withDefault(const Constant(0))();
  RealColumn get credit => real().withDefault(const Constant(0))();
  TextColumn get memo => text().nullable()();
}
