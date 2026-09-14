// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'role_permissions_dao.dart';

// ignore_for_file: type=lint
mixin _$RolePermissionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $RolesTable get roles => attachedDatabase.roles;
  $PermissionsTable get permissions => attachedDatabase.permissions;
  $RolePermissionsTable get rolePermissions => attachedDatabase.rolePermissions;
  RolePermissionsDaoManager get managers => RolePermissionsDaoManager(this);
}

class RolePermissionsDaoManager {
  final _$RolePermissionsDaoMixin _db;
  RolePermissionsDaoManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db.attachedDatabase, _db.permissions);
  $$RolePermissionsTableTableManager get rolePermissions =>
      $$RolePermissionsTableTableManager(
        _db.attachedDatabase,
        _db.rolePermissions,
      );
}
