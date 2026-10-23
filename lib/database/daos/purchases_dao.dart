import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/purchases_table.dart';

part 'purchases_dao.g.dart';

@DriftAccessor(tables: [Purchases])
class PurchasesDao extends DatabaseAccessor<AppDatabase>
    with _$PurchasesDaoMixin {
  PurchasesDao(super.db);

  Future<List<Purchase>> getAll() {
    return (select(purchases)
          ..orderBy([
            (purchase) => OrderingTerm(
                  expression: purchase.purchaseDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<Purchase?> getById(int id) {
    return (select(purchases)
          ..where((purchase) => purchase.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Purchase?> getByInvoiceNumber(String invoiceNumber) {
    final normalized = invoiceNumber.trim();
    if (normalized.isEmpty) return Future.value(null);

    return (select(purchases)
          ..where(
            (purchase) =>
                purchase.invoiceNumber.equals(normalized),
          ))
        .getSingleOrNull();
  }

  Future<List<Purchase>> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return getAll();

    return (select(purchases)
          ..where(
            (purchase) =>
                purchase.invoiceNumber.like('%$normalized%') |
                purchase.paymentMethod.like('%$normalized%') |
                purchase.status.like('%$normalized%'),
          )
          ..orderBy([
            (purchase) => OrderingTerm(
                  expression: purchase.purchaseDate,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();
  }

  Future<int> insertPurchase(PurchasesCompanion purchase) {
    return into(purchases).insert(purchase);
  }

  Future<bool> updatePurchase(PurchasesCompanion purchase) {
    return update(purchases).replace(purchase);
  }
}
