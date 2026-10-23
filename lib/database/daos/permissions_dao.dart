import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/permissions_table.dart';

part 'permissions_dao.g.dart';

@DriftAccessor(tables: [Permissions])
class PermissionsDao extends DatabaseAccessor<AppDatabase>
    with _$PermissionsDaoMixin {
  PermissionsDao(super.db);

  Future<Permission?> findById(int id) {
    return (select(permissions)
          ..where((permission) => permission.id.equals(id)))
        .getSingleOrNull();
  }

  Future<Permission?> findByCode(String code) {
    return (select(permissions)
          ..where((permission) => permission.code.equals(code)))
        .getSingleOrNull();
  }

  Future<List<Permission>> getAll() {
    return select(permissions).get();
  }

  Future<int> insertPermission(
    PermissionsCompanion permission,
  ) {
    return into(permissions).insert(permission);
  }

  Future<bool> updatePermission(Permission permission) {
    return update(permissions).replace(permission);
  }

  Future<bool> deletePermission(int id) async {
    final deletedRows = await (delete(permissions)
          ..where((permission) => permission.id.equals(id)))
        .go();

    return deletedRows > 0;
  }
}