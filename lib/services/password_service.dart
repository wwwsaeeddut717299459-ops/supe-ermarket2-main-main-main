import 'dart:convert';

import 'package:crypto/crypto.dart';

class PasswordService {
  const PasswordService();

  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  bool verifyPassword({
    required String password,
    required String passwordHash,
  }) {
    return hashPassword(password) == passwordHash;
  }
}