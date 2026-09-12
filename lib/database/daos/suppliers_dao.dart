import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/suppliers_table.dart';

part 'suppliers_dao.g.dart';

@DriftAccessor(tables: [Suppliers])
class SuppliersDao extends DatabaseAccessor<AppDatabase>
    with _$SuppliersDaoMixin {
  SuppliersDao(super.db);

  Future<List<Supplier>> getAll() {
    return (select(suppliers)
          ..where((supplier) => supplier.isActive.equals(true))
          ..orderBy([
            (supplier) => OrderingTerm(
                  expression: supplier.name,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<Supplier?> getById(int id) {
    return (select(suppliers)
          ..where((supplier) => supplier.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Supplier>> search(String query) {
    final normalized = query.trim();
    if (normalized.isEmpty) return getAll();

    return (select(suppliers)
          ..where(
            (supplier) =>
                supplier.name.like('%$normalized%') |
                supplier.phone.like('%$normalized%') |
                supplier.email.like('%$normalized%'),
          )
          ..orderBy([
            (supplier) => OrderingTerm(
                  expression: supplier.name,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<int> insertSupplier(SuppliersCompanion supplier) {
    return into(suppliers).insert(supplier);
  }

  Future<bool> updateSupplier(SuppliersCompanion supplier) {
    return update(suppliers).replace(supplier);
  }

  Future<int> deactivate(int id) {
    return (update(suppliers)..where((supplier) => supplier.id.equals(id)))
        .write(const SuppliersCompanion(isActive: Value(false)));
  }
}
