import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/roles_table.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users, Roles])
class UsersDao extends DatabaseAccessor<AppDatabase>
    with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<User?> findByUsername(String username) {
    return (select(users)
          ..where((user) => user.username.equals(username)))
        .getSingleOrNull();
  }

  Future<User?> findById(int id) {
    return (select(users)
          ..where((user) => user.id.equals(id)))
        .getSingleOrNull();
  }

  Future<int> insertUser(UsersCompanion user) {
    return into(users).insert(user);
  }

  Future<bool> updateUser(User user) {
    return update(users).replace(user);
  }

  Future<bool> deactivateUser(int id) async {
    final updatedRows = await (update(users)
          ..where((user) => user.id.equals(id)))
        .write(
      const UsersCompanion(
        isActive: Value(false),
      ),
    );

    return updatedRows > 0;
  }

  Future<List<User>> getAllUsers() {
    return select(users).get();
  }
}