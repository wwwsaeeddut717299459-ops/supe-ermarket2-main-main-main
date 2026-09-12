import 'package:flutter_test/flutter_test.dart';

import 'package:almajed_pro/database/app_database.dart';
import 'package:almajed_pro/services/database_initializer.dart';
import 'package:almajed_pro/services/password_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Database initialization creates admin user', () async {
    final database = AppDatabase();

    final initializer = DatabaseInitializer(
      database: database,
      passwordService: const PasswordService(),
    );

    await initializer.initialize();

    final users = await database.usersDao.getAllUsers();

    expect(users.length, 1);
    expect(users.first.username, 'admin');
    expect(users.first.fullName, 'System Administrator');

    final role = await database.rolesDao.findById(
      users.first.roleId,
    );

    expect(role, isNotNull);
    expect(role!.name, 'Admin');

    await database.close();
  });
}