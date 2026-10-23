import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/return_items_table.dart';

part 'return_items_dao.g.dart';

@DriftAccessor(tables: [ReturnItems])
class ReturnItemsDao extends DatabaseAccessor<AppDatabase>
    with _$ReturnItemsDaoMixin {
  ReturnItemsDao(super.db);

  Future<List<ReturnItem>> byReturn(int returnId) {
    return (select(
      returnItems,
    )..where((row) => row.returnId.equals(returnId))).get();
  }

  Future<int> insertItem(ReturnItemsCompanion value) =>
      into(returnItems).insert(value);
}
