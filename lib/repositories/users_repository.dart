

import '../database/app_database.dart';

class UsersRepository {
  final AppDatabase database;

  UsersRepository(this.database);


  Future<User?> findByUsername(String username) {
    return database.usersDao.findByUsername(username);
  }

  Future<User?> findById(int id) {
    return database.usersDao.findById(id);
  }

  Future<List<User>> getAllUsers() {
    return database.usersDao.getAllUsers();
  }

  Future<int> createUser({
    required String username,
    required String passwordHash,
    required String fullName,
    required int roleId,
  }) {
    return database.usersDao.insertUser(
      UsersCompanion.insert(
        username: username,
        passwordHash: passwordHash,
        fullName: fullName,
        roleId: roleId,
      ),
    );
  }

  Future<bool> updateUser(User user) {
    return database.usersDao.updateUser(user);
  }

  Future<bool> deactivateUser(int id) {
    return database.usersDao.deactivateUser(id);
  }
}