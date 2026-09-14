import 'package:drift/drift.dart';

import 'permissions_table.dart';
import 'roles_table.dart';

class RolePermissions extends Table {
  IntColumn get roleId =>
      integer().references(Roles, #id)();

  IntColumn get permissionId =>
      integer().references(Permissions, #id)();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => {
        roleId,
        permissionId,
      };
}