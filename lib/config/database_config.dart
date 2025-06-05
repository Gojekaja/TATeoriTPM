class DatabaseConfig {
  // Box names
  static const String userBox = 'users';
  static const String gameStatsBox = 'game_stats';
  static const String settingsBox = 'settings';
  static const String storeBox = 'store_items';

  // Type IDs for Hive adapters
  static const int userTypeId = 0;
  static const int purchaseHistoryTypeId = 2;
  static const int powerUpStatsTypeId = 3;
  static const int storeItemTypeId = 4;

  // Default values
  static const double initialBalance = 1000.0; // Starting balance for new users
  static const String defaultProfilePic = 'assets/images/pfp.jpeg';
  static const int maxPowerUpsAllowed = 30;
  static const int maxTopUpPerHour = 5;
  static const int maxPowerUpPerTransaction = 5;
  static const double maxBalance = 100000000.0; // 100M dollar limit

  // Backup and restore
  static const String backupPath = 'millionaire_backup';
  static const Duration backupInterval = Duration(days: 1);

  // Cache settings
  static const bool enableCache = true;
  static const Duration cacheExpiry = Duration(hours: 1);
}
