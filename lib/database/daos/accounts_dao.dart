import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/accounts_table.dart';

part 'accounts_dao.g.dart';

@DriftAccessor(tables: [Accounts])
class AccountsDao extends DatabaseAccessor<AppDatabase>
    with _$AccountsDaoMixin {
  AccountsDao(super.db);

  Future<List<Account>> getAll() =>
      (select(accounts)
            ..where((row) => row.isActive.equals(true))
            ..orderBy([(row) => OrderingTerm.asc(row.code)]))
          .get();
  Future<Account?> byCode(String code) => (select(
    accounts,
  )..where((row) => row.code.equals(code))).getSingleOrNull();
  Future<int> insertAccount(AccountsCompanion value) =>
      into(accounts).insert(value);
  Future<bool> updateAccount(AccountsCompanion value) =>
      update(accounts).replace(value);
}
