import 'package:drift/drift.dart';

import 'package:almajed_pro/core/database/app_database.dart';
import 'package:almajed_pro/core/database/tables/returns_table.dart';

part 'returns_dao.g.dart';

@DriftAccessor(tables: [Returns])
class ReturnsDao extends DatabaseAccessor<AppDatabase> with _$ReturnsDaoMixin {
  ReturnsDao(super.db);

  Future<List<Return>> getAll() =>
      (select(returns)..orderBy([(row) => OrderingTerm.desc(row.returnDate)])).get();

  Future<List<Return>> search(String query) {
    final term = '%${query.trim()}%';
    final statement = select(returns)
      ..where((row) => row.returnNumber.like(term) | row.type.like(term))
      ..orderBy([(row) => OrderingTerm.desc(row.returnDate)]);
    return statement.get();
  }

  Future<Return?> getById(int id) =>
      (select(returns)..where((row) => row.id.equals(id))).getSingleOrNull();

  Future<Return?> getByNumber(String number) => (select(
    returns,
  )..where((row) => row.returnNumber.equals(number))).getSingleOrNull();

  Future<int> insertReturn(ReturnsCompanion value) =>
      into(returns).insert(value);

  Future<bool> updateReturn(ReturnsCompanion value) =>
      update(returns).replace(value);
}
