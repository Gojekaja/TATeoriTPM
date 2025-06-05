import 'dart:io';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import '../config/database_config.dart';
import '../models/user.dart';
import '../models/store_item.dart';
import 'package:flutter/foundation.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  bool _isInitialized = false;

  // Boxes
  late Box<User> _userBox;
  late Box<Map<dynamic, dynamic>> _gameStatsBox;
  late Box<Map<dynamic, dynamic>> _settingsBox;
  late Box<StoreItem> _storeBox;

  factory DatabaseService() {
    return _instance;
  }

  DatabaseService._internal();

  bool get isInitialized => _isInitialized;
  Box<User> get userBox => _userBox;
  Box<Map<dynamic, dynamic>> get gameStatsBox => _gameStatsBox;
  Box<Map<dynamic, dynamic>> get settingsBox => _settingsBox;
  Box<StoreItem> get storeBox => _storeBox;

  Future<void> init() async {
    if (_isInitialized) return;

    try {
      // Get the application documents directory for persistent storage
      final appDocDir = await getApplicationDocumentsDirectory();
      // Initialize Hive with the documents directory path
      await Hive.initFlutter(appDocDir.path);

      // Register adapters in correct order
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(UserAdapter());
      }
      if (!Hive.isAdapterRegistered(2)) {
        Hive.registerAdapter(PurchaseHistoryAdapter());
      }
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(PowerUpStatsAdapter());
      }
      if (!Hive.isAdapterRegistered(4)) {
        Hive.registerAdapter(StoreItemAdapter());
      }

      // Open boxes with encryption key if needed
      _userBox = await Hive.openBox<User>(
        DatabaseConfig.userBox,
        // Optional: Add encryption key for sensitive data
        // encryptionCipher: HiveAesCipher(encryptionKey),
      );

      _gameStatsBox = await Hive.openBox<Map>(DatabaseConfig.gameStatsBox);
      _settingsBox = await Hive.openBox<Map>(DatabaseConfig.settingsBox);
      _storeBox = await Hive.openBox<StoreItem>(DatabaseConfig.storeBox);

      _isInitialized = true;
      debugPrint('Database initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('Database initialization error: $e\n$stackTrace');
      // Only delete boxes if there's a corruption error
      if (e.toString().contains('corrupted')) {
        await Hive.deleteBoxFromDisk(DatabaseConfig.userBox);
        await Hive.deleteBoxFromDisk(DatabaseConfig.gameStatsBox);
        await Hive.deleteBoxFromDisk(DatabaseConfig.settingsBox);
        await Hive.deleteBoxFromDisk(DatabaseConfig.storeBox);
        rethrow;
      }
      rethrow;
    }
  }

  Future<void> closeBoxes() async {
    await _userBox.close();
    await _gameStatsBox.close();
    await _settingsBox.close();
    await _storeBox.close();
    _isInitialized = false;
  }

  Future<void> clearAllData() async {
    await _userBox.clear();
    await _gameStatsBox.clear();
    await _settingsBox.clear();
    await _storeBox.clear();
  }

  Future<void> backup() async {
    if (!_isInitialized) throw Exception('Database not initialized');

    final appDir = await getApplicationDocumentsDirectory();
    final backupDir = Directory('${appDir.path}/${DatabaseConfig.backupPath}');

    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final backupFile = File('${backupDir.path}/backup_$timestamp.hive');

    // Create backup of all boxes
    final allData = {
      'users': _userBox.toMap(),
      'gameStats': _gameStatsBox.toMap(),
      'settings': _settingsBox.toMap(),
      'store': _storeBox.toMap(),
    };

    await backupFile.writeAsString(allData.toString());
  }

  Future<void> restore(String backupPath) async {
    if (!_isInitialized) throw Exception('Database not initialized');

    final backupFile = File(backupPath);
    if (!await backupFile.exists()) {
      throw Exception('Backup file not found');
    }

    // Clear current data
    await clearAllData();

    try {
      // Read and restore backup
      final String contents = await backupFile.readAsString();
      final Map<String, dynamic> backupData = Map<String, dynamic>.from(
        // Parse the string back to a Map
        // Note: In a production app, you'd want to use a proper serialization format
        eval(contents) as Map,
      );

      // Restore data to boxes
      await _userBox.putAll(
        Map<dynamic, User>.from(backupData['users'] as Map),
      );
      await _gameStatsBox.putAll(
        Map<dynamic, Map>.from(backupData['gameStats'] as Map),
      );
      await _settingsBox.putAll(
        Map<dynamic, Map>.from(backupData['settings'] as Map),
      );
      await _storeBox.putAll(
        Map<dynamic, StoreItem>.from(backupData['store'] as Map),
      );
    } catch (e) {
      throw Exception('Failed to restore backup: $e');
    }
  }

  Future<void> compactBoxes() async {
    await _userBox.compact();
    await _gameStatsBox.compact();
    await _settingsBox.compact();
    await _storeBox.compact();
  }

  Future<void> validateBoxes() async {
    if (!_isInitialized) throw Exception('Database not initialized');

    // Validate user box
    for (var user in _userBox.values) {
      if (user.username.isEmpty || user.email.isEmpty) {
        await _userBox.delete(user.key);
      }
    }

    // Validate game stats
    for (var entry in _gameStatsBox.toMap().entries) {
      if (!entry.value.containsKey('lastLogin') &&
          !entry.value.containsKey('loginCount')) {
        await _gameStatsBox.delete(entry.key);
      }
    }

    // Validate store items
    for (var item in _storeBox.values) {
      if (item.id.isEmpty || item.name.isEmpty || item.dolarPrice <= 0) {
        await _storeBox.delete(item.key);
      }
    }
  }

  // Helper method to safely evaluate string to Map
  // Note: This is a simplified version. In production, use proper serialization
  dynamic eval(String source) {
    // Implementation would go here
    // For security reasons, you should use a proper serialization format like JSON
    throw UnimplementedError('Implement proper serialization');
  }

  // Add a method to check if user exists
  bool hasUser(String username) {
    return _userBox.containsKey(username);
  }

  // Add a method to get user count
  int get userCount => _userBox.length;
}
