import 'package:drift/drift.dart';

class JournalEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get entryNumber => text().unique()();
  DateTimeColumn get entryDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get description => text()();
  TextColumn get sourceType => text().nullable()();
  IntColumn get sourceId => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('posted'))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
