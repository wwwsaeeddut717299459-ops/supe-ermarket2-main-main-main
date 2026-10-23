// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permissions_dao.dart';

// ignore_for_file: type=lint
mixin _$PermissionsDaoMixin on DatabaseAccessor<AppDatabase> {
  $PermissionsTable get permissions => attachedDatabase.permissions;
  PermissionsDaoManager get managers => PermissionsDaoManager(this);
}

class PermissionsDaoManager {
  final _$PermissionsDaoMixin _db;
  PermissionsDaoManager(this._db);
  $$PermissionsTableTableManager get permissions =>
      $$PermissionsTableTableManager(_db.attachedDatabase, _db.permissions);
}
