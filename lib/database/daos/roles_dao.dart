import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/roles_table.dart';

part 'roles_dao.g.dart';

@DriftAccessor(tables: [Roles])
class RolesDao extends DatabaseAccessor<AppDatabase>
    with _$RolesDaoMixin {
  RolesDao(super.db);

  Future<Role?> findById(int id) {
    return (select(roles)..where((role) => role.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Role?> findByName(String name) {
    return (select(roles)..where((role) => role.name.equals(name)))
        .getSingleOrNull();
  }

  Future<List<Role>> getAll() {
    return select(roles).get();
  }

  Future<int> insertRole(RolesCompanion role) {
    return into(roles).insert(role);
  }

  Future<bool> updateRole(Role role) {
    return update(roles).replace(role);
  }

  Future<bool> deleteRole(int id) async {
    final deletedRows = await (delete(roles)
          ..where((role) => role.id.equals(id)))
        .go();

    return deletedRows > 0;
  }
}