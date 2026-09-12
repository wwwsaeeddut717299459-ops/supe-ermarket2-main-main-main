import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/customers_table.dart';

part 'customers_dao.g.dart';

@DriftAccessor(tables: [Customers])
class CustomersDao extends DatabaseAccessor<AppDatabase>
    with _$CustomersDaoMixin {
  CustomersDao(super.db);

  Future<List<Customer>> getAll() {
    return (select(customers)
          ..where((customer) => customer.isActive.equals(true))
          ..orderBy([
            (customer) => OrderingTerm(
                  expression: customer.name,
                  mode: OrderingMode.asc,
                ),
          ]))
        .get();
  }

  Future<Customer?> getById(int id) {
    return (select(customers)
          ..where((customer) => customer.id.equals(id)))
        .getSingleOrNull();
  }

  Future<List<Customer>> search(String query) {
    final normalized = query.trim();

    if (normalized.isEmpty) {
      return getAll();
    }

    return (select(customers)
          ..where(
            (customer) =>
                customer.name.like('%$normalized%') |
                customer.phone.like('%$normalized%'),
          )
          ..orderBy([
            (customer) => OrderingTerm(
                  expression: customer.name,
                  mode: OrderingMode.asc,
                ),
          ])
          ..limit(30))
        .get();
  }

  Future<int> insertCustomer(
    CustomersCompanion customer,
  ) {
    return into(customers).insert(customer);
  }

  Future<bool> updateCustomer(
    CustomersCompanion customer,
  ) {
    return update(customers).replace(customer);
  }

  Future<int> deleteCustomer(int id) {
    return (delete(customers)
          ..where((customer) => customer.id.equals(id)))
        .go();
  }
}