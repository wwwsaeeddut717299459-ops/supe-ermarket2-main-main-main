import '../database/app_database.dart';

class AuthSession {
  User? _currentUser;

  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  int? get currentUserId => _currentUser?.id;

  int? get currentRoleId => _currentUser?.roleId;

  void login(User user) {
    _currentUser = user;
  }

  void logout() {
    _currentUser = null;
  }
}