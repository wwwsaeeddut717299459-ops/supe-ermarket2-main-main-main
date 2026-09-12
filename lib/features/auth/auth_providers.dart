import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../database/app_database.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session.dart';
import '../../services/password_service.dart';
import 'auth_controller.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final database = AppDatabase();

  ref.onDispose(database.close);

  return database;
});

final passwordServiceProvider = Provider<PasswordService>((ref) {
  return const PasswordService();
});

final authSessionProvider = Provider<AuthSession>((ref) {
  return AuthSession();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    database: ref.watch(databaseProvider),
    passwordService: ref.watch(passwordServiceProvider),
  );
});

final authControllerProvider = Provider<AuthController>((ref) {
  return AuthController(
    authService: ref.watch(authServiceProvider),
    authSession: ref.watch(authSessionProvider),
  );
});