import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/journal_lines_table.dart';

part 'journal_lines_dao.g.dart';

@DriftAccessor(tables: [JournalLines])
class JournalLinesDao extends DatabaseAccessor<AppDatabase>
    with _$JournalLinesDaoMixin {
  JournalLinesDao(super.db);

  Future<List<JournalLine>> byEntry(int entryId) {
    return (select(journalLines)
          ..where((row) => row.entryId.equals(entryId)))
        .get();
  }

  Future<int> insertLine(JournalLinesCompanion value) {
    return into(journalLines).insert(value);
  }

  Future<int> deleteAll() {
    return delete(journalLines).go();
  }

  /// رصيد حساب واحد:
  ///
  /// الأصول والمصروفات:
  /// مدين - دائن
  ///
  /// الخصوم وحقوق الملكية والإيرادات:
  /// دائن - مدين
  ///
  /// ملاحظة:
  /// هذه الدالة ترجع الرصيد المحاسبي الخام
  /// = المدين - الدائن.
  Future<double> balance(int accountId) async {
    final result = await customSelect(
      '''
      SELECT
        COALESCE(SUM(debit - credit), 0) AS value
      FROM journal_lines
      WHERE account_id = ?
      ''',
      variables: [
        Variable.withInt(accountId),
      ],
      readsFrom: {journalLines},
    ).getSingle();

    return result.read<double>('value');
  }

  /// جلب أرصدة جميع الحسابات باستعلام واحد.
  ///
  /// النتيجة:
  /// accountId -> debit - credit
  Future<Map<int, double>> balances() async {
    final rows = await customSelect(
      '''
      SELECT
        account_id,
        COALESCE(SUM(debit - credit), 0) AS balance
      FROM journal_lines
      GROUP BY account_id
      ''',
      readsFrom: {journalLines},
    ).get();

    return {
      for (final row in rows)
        row.read<int>('account_id'):
            row.read<double>('balance'),
    };
  }

  /// إجمالي المدين والدائن.
  Future<(double debits, double credits)> totals() async {
    final row = await customSelect(
      '''
      SELECT
        COALESCE(SUM(debit), 0) AS debits,
        COALESCE(SUM(credit), 0) AS credits
      FROM journal_lines
      ''',
      readsFrom: {journalLines},
    ).getSingle();

    return (
      row.read<double>('debits'),
      row.read<double>('credits'),
    );
  }
}
