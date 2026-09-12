import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'password_service.dart';

class DatabaseInitializer {
  final AppDatabase database;
  final PasswordService passwordService;

  DatabaseInitializer({
    required this.database,
    required this.passwordService,
  });

  Future<void> initialize() async {
    final users = await database.usersDao.getAllUsers();

    if (users.isNotEmpty) {
      return;
    }

    await database.transaction(() async {
      final adminRoleId = await database.rolesDao.insertRole(
        RolesCompanion.insert(
          name: 'Admin',
          description: const Value(
            'System administrator',
          ),
        ),
      );

      final passwordHash = passwordService.hashPassword(
        'admin123',
      );

      await database.usersDao.insertUser(
        UsersCompanion.insert(
          username: 'admin',
          passwordHash: passwordHash,
          fullName: 'System Administrator',
          roleId: adminRoleId,
        ),
      );
    });
  }
}