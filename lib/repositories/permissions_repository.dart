import 'package:drift/drift.dart';

import '../database/app_database.dart';


class PermissionsRepository {
  final AppDatabase database;

  PermissionsRepository(this.database);

  Future<Permission?> findById(int id) {
    return database.permissionsDao.findById(id);
  }

  Future<Permission?> findByCode(String code) {
    return database.permissionsDao.findByCode(code);
  }

  Future<List<Permission>> getAllPermissions() {
    return database.permissionsDao.getAll();
  }

  Future<int> createPermission({
    required String code,
    required String name,
    String? description,
  }) {
    return database.permissionsDao.insertPermission(
      PermissionsCompanion.insert(
        code: code,
        name: name,
        description: Value(description),
      ),
    );
  }

  Future<bool> updatePermission(Permission permission) {
    return database.permissionsDao.updatePermission(permission);
  }

  Future<bool> deletePermission(int id) {
    return database.permissionsDao.deletePermission(id);
  }
}