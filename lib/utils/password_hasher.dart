import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

class PasswordHasher {
  static String hashPassword(String password) {
    try {
      if (password.isEmpty) {
        throw Exception('Password cannot be empty');
      }

      // Add a consistent salt to make hashing more secure
      final salt = "MILLIONAIRE_GAME_SALT";
      final saltedPassword = password + salt;
      
      final bytes = utf8.encode(saltedPassword);
      final hash = sha256.convert(bytes);
      
      debugPrint('Password hashed successfully');
      return hash.toString();
    } catch (e, stackTrace) {
      debugPrint('Error hashing password: $e');
      debugPrint('Stack trace: $stackTrace');
      rethrow;
    }
  }

  static bool verifyPassword(String password, String hashedPassword) {
    try {
      if (password.isEmpty || hashedPassword.isEmpty) {
        return false;
      }

      final hashedInput = hashPassword(password);
      final isMatch = hashedInput == hashedPassword;
      
      debugPrint('Password verification result: $isMatch');
      return isMatch;
    } catch (e, stackTrace) {
      debugPrint('Error verifying password: $e');
      debugPrint('Stack trace: $stackTrace');
      return false;
    }
  }
}


