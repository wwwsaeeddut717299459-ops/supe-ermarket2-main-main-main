import 'package:drift/drift.dart';

import 'roles_table.dart';

class Users extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get username => text().unique()();

  TextColumn get passwordHash => text()();

  TextColumn get fullName => text()();

  IntColumn get roleId =>
      integer().references(Roles, #id)();

  BoolColumn get isActive =>
      boolean().withDefault(const Constant(true))();

  DateTimeColumn get createdAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt =>
      dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get lastLoginAt =>
      dateTime().nullable()();
}