import 'package:drift/drift.dart';

import '../database/app_database.dart';

class RolesRepository {
  final AppDatabase database;

  RolesRepository(this.database);

  Future<Role?> findById(int id) {
    return database.rolesDao.findById(id);
  }

  Future<Role?> findByName(String name) {
    return database.rolesDao.findByName(name);
  }

  Future<List<Role>> getAllRoles() {
    return database.rolesDao.getAll();
  }

  Future<int> createRole({
    required String name,
    String? description,
  }) {
    return database.rolesDao.insertRole(
      RolesCompanion.insert(
        name: name,
        description: Value(description),
      ),
    );
  }

  Future<bool> updateRole(Role role) {
    return database.rolesDao.updateRole(role);
  }

  Future<bool> deleteRole(int id) {
    return database.rolesDao.deleteRole(id);
  }
}