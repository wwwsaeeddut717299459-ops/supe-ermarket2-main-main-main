import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/permissions_table.dart';
import '../tables/role_permissions_table.dart';

part 'role_permissions_dao.g.dart';

@DriftAccessor(
  tables: [
    RolePermissions,
    Permissions,
  ],
)
class RolePermissionsDao extends DatabaseAccessor<AppDatabase>
    with _$RolePermissionsDaoMixin {
  RolePermissionsDao(super.db);

  Future<List<Permission>> getPermissionsForRole(int roleId) {
    final query = select(permissions).join([
      innerJoin(
        rolePermissions,
        rolePermissions.permissionId.equalsExp(permissions.id),
      ),
    ])
      ..where(rolePermissions.roleId.equals(roleId));

    return query.map((row) => row.readTable(permissions)).get();
  }

  Future<bool> hasPermission(
    int roleId,
    String permissionCode,
  ) async {
    final query = select(permissions).join([
      innerJoin(
        rolePermissions,
        rolePermissions.permissionId.equalsExp(permissions.id),
      ),
    ])
      ..where(
        rolePermissions.roleId.equals(roleId) &
            permissions.code.equals(permissionCode),
      );

    final result = await query.getSingleOrNull();

    return result != null;
  }

  Future<void> addPermissionToRole(
    int roleId,
    int permissionId,
  ) async {
    await into(rolePermissions).insert(
      RolePermissionsCompanion.insert(
        roleId: roleId,
        permissionId: permissionId,
      ),
    );
  }

  Future<void> removePermissionFromRole(
    int roleId,
    int permissionId,
  ) async {
    await (delete(rolePermissions)
          ..where(
            (row) =>
                row.roleId.equals(roleId) &
                row.permissionId.equals(permissionId),
          ))
        .go();
  }

  Future<void> removeAllPermissionsFromRole(int roleId) async {
    await (delete(rolePermissions)
          ..where((row) => row.roleId.equals(roleId)))
        .go();
  }
}