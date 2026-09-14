// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'roles_dao.dart';

// ignore_for_file: type=lint
mixin _$RolesDaoMixin on DatabaseAccessor<AppDatabase> {
  $RolesTable get roles => attachedDatabase.roles;
  RolesDaoManager get managers => RolesDaoManager(this);
}

class RolesDaoManager {
  final _$RolesDaoMixin _db;
  RolesDaoManager(this._db);
  $$RolesTableTableManager get roles =>
      $$RolesTableTableManager(_db.attachedDatabase, _db.roles);
}
