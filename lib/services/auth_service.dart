import 'package:drift/drift.dart';

import '../database/app_database.dart';
import 'password_service.dart';

class AuthService {
  final AppDatabase database;
  final PasswordService passwordService;

  AuthService({
    required this.database,
    required this.passwordService,
  });

  Future<User?> login({
    required String username,
    required String password,
  }) async {
    final normalizedUsername = username.trim();

    if (normalizedUsername.isEmpty || password.isEmpty) {
      return null;
    }

    final user = await database.usersDao.findByUsername(
      normalizedUsername,
    );

    if (user == null || !user.isActive) {
      return null;
    }

    final isValid = passwordService.verifyPassword(
      password: password,
      passwordHash: user.passwordHash,
    );

    if (!isValid) {
      return null;
    }

    final loggedInUser = user.copyWith(
      lastLoginAt: Value(DateTime.now()),
      updatedAt: DateTime.now(),
    );

    await database.usersDao.updateUser(loggedInUser);

    return loggedInUser;
  }
}