import 'package:drift/drift.dart';

import 'package:almajed_pro/core/database/app_database.dart';
import 'package:almajed_pro/core/database/tables/purchase_items_table.dart';

part 'purchase_items_dao.g.dart';

@DriftAccessor(tables: [PurchaseItems])
class PurchaseItemsDao extends DatabaseAccessor<AppDatabase>
    with _$PurchaseItemsDaoMixin {
  PurchaseItemsDao(super.db);

  Future<List<PurchaseItem>> byPurchase(int purchaseId) {
    return (select(purchaseItems)
          ..where((item) => item.purchaseId.equals(purchaseId))
          ..orderBy([
            (item) => OrderingTerm(
                  expression: item.id,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<int> insertItem(PurchaseItemsCompanion item) {
    return into(purchaseItems).insert(item);
  }

  Future<int> deleteByPurchase(int purchaseId) {
    return (delete(purchaseItems)
          ..where((item) => item.purchaseId.equals(purchaseId)))
        .go();
  }
}
