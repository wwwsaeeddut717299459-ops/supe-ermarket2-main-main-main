import '../database/app_database.dart';

class RolePermissionsRepository {
  final AppDatabase database;

  RolePermissionsRepository(this.database);

  Future<List<Permission>> getPermissionsForRole(int roleId) {
    return database.rolePermissionsDao.getPermissionsForRole(roleId);
  }

  Future<bool> hasPermission(
    int roleId,
    String permissionCode,
  ) {
    return database.rolePermissionsDao.hasPermission(
      roleId,
      permissionCode,
    );
  }

  Future<void> addPermissionToRole({
    required int roleId,
    required int permissionId,
  }) {
    return database.rolePermissionsDao.addPermissionToRole(
      roleId,
      permissionId,
    );
  }

  Future<void> removePermissionFromRole({
    required int roleId,
    required int permissionId,
  }) {
    return database.rolePermissionsDao.removePermissionFromRole(
      roleId,
      permissionId,
    );
  }

  Future<void> removeAllPermissionsFromRole(int roleId) {
    return database.rolePermissionsDao.removeAllPermissionsFromRole(roleId);
  }
}