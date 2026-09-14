import 'package:drift/drift.dart';

import '../database/app_database.dart';
import '../data/seed/supermarket_catalog_seeder.dart';
import 'password_service.dart';

class DatabaseInitializer {
  final AppDatabase database;
  final PasswordService passwordService;

  DatabaseInitializer({
    required this.database,
    required this.passwordService,
  });

  Future<void> initialize() async {
    // قاعدة البيانات الجديدة تبدأ بكتالوج السوبر ماركت الجاهز.
    // لا يتم إدخال سعر أو مخزون أو تاريخ صلاحية للمنتجات.
    await SupermarketCatalogSeeder.seed(database);

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
        '000',
      );

      await database.usersDao.insertUser(
        UsersCompanion.insert(
          username: '000',
          passwordHash: passwordHash,
          fullName: 'مدير النظام',
          roleId: adminRoleId,
        ),
      );
    });
  }
}