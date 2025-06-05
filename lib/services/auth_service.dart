import 'package:flutter/material.dart';
import 'package:millionaire_game/utils/password_hasher.dart';

import '../models/user.dart';
import '../config/database_config.dart';
import 'database_service.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AuthService {
  static final AuthService _instance = AuthService._internal();
  User? _currentUser;
  late final DatabaseService _db;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal() {
    _db = DatabaseService();
  }

  Future<void> init() async {
    try {
      // Get last logged in user if exists
      final lastUserData = _db.settingsBox.get('lastLoggedInUser') as Map?;
      final lastUsername = lastUserData?['username'] as String?;
      if (lastUsername != null) {
        final user = _db.userBox.get(lastUsername);
        if (user != null && user.hashedPassword.isNotEmpty) {
          _currentUser = user;
          debugPrint('Restored user session for: ${user.username}');
        } else {
          // Clear invalid session
          await _db.settingsBox.delete('lastLoggedInUser');
          debugPrint('Cleared invalid user session');
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error initializing auth service: $e');
      debugPrint('Stack trace: $stackTrace');
      // Clear potentially corrupted session
      await _db.settingsBox.delete('lastLoggedInUser');
    }
  }

  bool _validateUsername(String username) {
    final regex = RegExp(r'^[a-zA-Z0-9_]{3,10}$');
    return regex.hasMatch(username);
  }

  bool _validatePassword(String password) {
    if (password.length < 8 || password.length > 10) return false;

    bool hasLetter = false;
    bool hasNumber = false;

    for (var char in password.runes) {
      final c = String.fromCharCode(char);
      if (RegExp(r'[a-zA-Z]').hasMatch(c)) hasLetter = true;
      if (RegExp(r'[0-9]').hasMatch(c)) hasNumber = true;
      if (hasLetter && hasNumber) break;
    }

    return hasLetter && hasNumber;
  }

  bool _validateEmail(String email) {
    final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return regex.hasMatch(email);
  }

  Future<User> register({
    required String username,
    required String password,
    required String email,
  }) async {
    // Input validation
    if (!_validateUsername(username)) {
      throw Exception('Username must be 3-10 characters (letters/numbers/_)');
    }
    if (!_validatePassword(password)) {
      throw Exception(
        'Password must be 8-10 characters with letters and numbers',
      );
    }
    if (!_validateEmail(email)) {
      throw Exception('Invalid email format');
    }

    // Check for existing user
    if (_db.userBox.containsKey(username)) {
      throw Exception('Username already exists');
    }

    // Check for existing email
    final existingEmail = _db.userBox.values.any((user) => user.email == email);
    if (existingEmail) {
      throw Exception('Email already registered');
    }

    // Create new user
    final user = User(
      username: username,
      email: email,
      password: password,
      dolarBalance: DatabaseConfig.initialBalance,
      profilePicPath: DatabaseConfig.defaultProfilePic,
    );

    try {
      // Save to database
      await _db.userBox.put(username, user);

      // Save game stats
      await _db.gameStatsBox.put('${username}_stats', {
        'gamesPlayed': 0,
        'totalWinnings': 0.0,
        'highestLevel': 0,
        'lastPlayed': DateTime.now().toIso8601String(),
      });

      _currentUser = user;
      // Store username directly instead of as Map
      await _db.settingsBox.put('lastLoggedInUser', {'username': username});

      return user;
    } catch (e) {
      throw Exception('Failed to create user: ${e.toString()}');
    }
  }

  Future<User> login({
    required String username,
    required String password,
  }) async {
    try {
      final user = _db.userBox.get(username);
      if (user == null) {
        throw Exception('User not found');
      }

      if (!user.verifyPassword(password)) {
        throw Exception('Invalid password');
      }

      _currentUser = user;
      
      // Save login session as String, not Map
      await _db.settingsBox.put('lastLoggedInUser', {'username': username});
      
      // Log login time
      await _db.gameStatsBox.put('${username}_login_history', {
        'lastLogin': DateTime.now().toIso8601String(),
        ..._db.gameStatsBox.get('${username}_login_history') ?? {},
      });

      return user;
    } catch (e) {
      debugPrint('Login error: $e');
      rethrow;
    }
    throw Exception('Unknown login error');
  }

  Future<void> logout() async {
    if (_currentUser != null) {
      await _db.settingsBox.put('lastLoggedInUser', {'username': ''});
      _currentUser = null;
    }
  }

  User? get currentUser => _currentUser;

  Future<String> _saveProfilePicture(String sourcePath) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName =
          'profile_${DateTime.now().millisecondsSinceEpoch}${path.extension(sourcePath)}';
      final destinationPath = path.join(
        appDir.path,
        'profile_pictures',
        fileName,
      );

      // Create the profile_pictures directory if it doesn't exist
      final directory = Directory(path.dirname(destinationPath));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      // Copy the file to the new location
      await File(sourcePath).copy(destinationPath);
      return destinationPath;
    } catch (e) {
      throw Exception('Failed to save profile picture: $e');
    }
  }

  Future<void> updateProfile({
    String? username,
    String? email,
    String? profilePicPath,
  }) async {
    if (_currentUser == null) throw Exception('No user logged in');

    if (username != null) {
      if (!_validateUsername(username)) {
        throw Exception('Invalid username format');
      }
      if (_db.userBox.containsKey(username) &&
          username != _currentUser!.username) {
        throw Exception('Username already exists');
      }

      // Update game stats and other references
      final oldUsername = _currentUser!.username;
      final gameStats = _db.gameStatsBox.get(oldUsername);
      if (gameStats != null) {
        await _db.gameStatsBox.delete(oldUsername);
        await _db.gameStatsBox.put(username, gameStats);
      }

      _currentUser!.username = username;
    }

    if (email != null) {
      if (!_validateEmail(email)) {
        throw Exception('Invalid email format');
      }
      if (_db.userBox.values.any(
        (u) => u.email == email && u.username != _currentUser!.username,
      )) {
        throw Exception('Email already registered');
      }
      _currentUser!.email = email;
    }

    if (profilePicPath != null) {
      // Only process if it's not an asset path
      if (!profilePicPath.startsWith('assets/')) {
        final savedPath = await _saveProfilePicture(profilePicPath);
        _currentUser!.profilePicPath = savedPath;
      }
    }

    await _currentUser!.save();
  }

  Future<void> signOut() async {
  if (_currentUser != null) {
    // Log the last logout time
    final username = _currentUser!.username;
    await _db.gameStatsBox.put('${username}_login_history', {
      'lastLogout': DateTime.now().toIso8601String(),
      ..._db.gameStatsBox.get('${username}_login_history') ?? {},
    });

    // Clear the session
    await _db.settingsBox.put('lastLoggedInUser', {'username': ''});
    _currentUser = null;
  }
}

  Future<void> deleteAccount() async {
    if (_currentUser == null) throw Exception('No user logged in');

    final username = _currentUser!.username;

    // Delete all user data
    await _db.userBox.delete(username);
    await _db.gameStatsBox.delete(username);
    await _db.settingsBox.delete('lastLoggedInUser');

    _currentUser = null;
  }

  // Purchase history methods
  Future<void> addTopUp(double amount, String currency) async {
    if (_currentUser == null) throw Exception('No user logged in');

    _currentUser!.dolarBalance += amount;
    _currentUser!.purchaseHistory.add(
      PurchaseHistory(
        type: 'Top-Up',
        amount: amount,
        price: currency,
        date: DateTime.now(),
      ),
    );

    await _currentUser!.save();
  }

  Future<void> buyPowerUp(String type, double cost) async {
    if (_currentUser == null) throw Exception('No user logged in');
    if (_currentUser!.dolarBalance < cost) {
      throw Exception('Insufficient balance');
    }

    _currentUser!.dolarBalance -= cost;
    _currentUser!.purchaseHistory.add(
      PurchaseHistory(
        type: 'Power-Up',
        amount: -cost,
        date: DateTime.now(),
        item: type,
      ),
    );

    // Update power-up stats
    switch (type) {
      case '50:50':
        _currentUser!.powerUpStats.fiftyFiftyUsed++;
        break;
      case 'call_friend':
        _currentUser!.powerUpStats.callFriendUsed++;
        break;
      case 'audience':
        _currentUser!.powerUpStats.audienceUsed++;
        break;
    }

    await _currentUser!.save();
  }
}
