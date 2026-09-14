import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/journal_entries_table.dart';

part 'journal_entries_dao.g.dart';

@DriftAccessor(tables: [JournalEntries])
class JournalEntriesDao extends DatabaseAccessor<AppDatabase>
    with _$JournalEntriesDaoMixin {
  JournalEntriesDao(super.db);

  Future<List<JournalEntry>> recent({int? limit}) {
    final query = select(journalEntries)
      ..orderBy([(row) => OrderingTerm.desc(row.entryDate)]);
    if (limit != null) query.limit(limit);
    return query.get();
  }
  Future<JournalEntry?> bySource(String sourceType, int sourceId) =>
      (select(journalEntries)..where(
            (row) =>
                row.sourceType.equals(sourceType) &
                row.sourceId.equals(sourceId),
          ))
          .getSingleOrNull();
  Future<int> insertEntry(JournalEntriesCompanion value) =>
      into(journalEntries).insert(value);
  Future<int> deleteAll() => delete(journalEntries).go();
}
