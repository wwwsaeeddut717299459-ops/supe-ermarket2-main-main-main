import '../../database/app_database.dart';
import '../../services/auth_service.dart';
import '../../services/auth_session.dart';

class AuthController {
  final AuthService authService;
  final AuthSession authSession;

  AuthController({
    required this.authService,
    required this.authSession,
  });

  Future<bool> login({
    required String username,
    required String password,
  }) async {
    final user = await authService.login(
      username: username,
      password: password,
    );

    if (user == null) {
      return false;
    }

    authSession.login(user);

    return true;
  }

  void logout() {
    authSession.logout();
  }

  User? get currentUser => authSession.currentUser;

  bool get isLoggedIn => authSession.isLoggedIn;
}