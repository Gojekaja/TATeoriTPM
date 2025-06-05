import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../utils/localization_helper.dart';
import '../utils/password_hasher.dart';

part 'user.g.dart';

@HiveType(typeId: 0)
class User extends HiveObject {
  @HiveField(0)
  String username;

  @HiveField(1)
  String hashedPassword;

  @HiveField(2)
  String email;

  @HiveField(3)
  double dolarBalance;

  @HiveField(4)
  List<PurchaseHistory> purchaseHistory;

  @HiveField(5)
  String profilePicPath;

  @HiveField(6)
  PowerUpStats powerUpStats;

  User({
    required this.username,
    required this.email,
    String password = '', // Make password optional
    this.dolarBalance = 0.0, // Explicitly specify as double
    List<PurchaseHistory>? purchaseHistory,
    this.profilePicPath = 'assets/default_avatar.png',
    PowerUpStats? powerUpStats,
    String? hashedPassword,
  }) : 
    this.hashedPassword = hashedPassword ?? (password.isNotEmpty ? PasswordHasher.hashPassword(password) : ''),
    this.purchaseHistory = purchaseHistory ?? [],
    this.powerUpStats = powerUpStats ?? PowerUpStats(
      fiftyFiftyUsed: 0,
      callFriendUsed: 0,
      audienceUsed: 0
    );

  bool verifyPassword(String password) {
    return PasswordHasher.verifyPassword(password, hashedPassword);
  }

  void updatePassword(String newPassword) {
    hashedPassword = PasswordHasher.hashPassword(newPassword);
    save();
  }
}

@HiveType(typeId: 2)
class PurchaseHistory {
  @HiveField(0)
  final String type;

  @HiveField(1)
  final double amount;

  @HiveField(2)
  final String? price;

  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final String? item;

  @HiveField(5)
  final String originalCurrency;

  PurchaseHistory({
    required this.type,
    required this.amount,
    this.price,
    required this.date,
    this.item,
    this.originalCurrency = 'IDR',
  });

  Future<String> getLocalTime() async {
    final timezone = await LocalizationHelper.detectTimezone();
    return LocalizationHelper.formatLocalTime(date, timezone);
  }

  Future<String> getLocalPrice() async {
    final countryCode = await LocalizationHelper.detectCountryCode();
    return LocalizationHelper.formatLocalPrice(amount.toInt(), countryCode);
  }

  String getFormattedAmount() {
    final prefix = amount >= 0 ? '+' : '';
    return '$prefix${amount.toStringAsFixed(0)} Dolar';
  }
}

@HiveType(typeId: 3)
class PowerUpStats {
  @HiveField(0)
  int fiftyFiftyUsed;

  @HiveField(1)
  int callFriendUsed;

  @HiveField(2)
  int audienceUsed;

  PowerUpStats({
    required this.fiftyFiftyUsed,
    required this.callFriendUsed,
    required this.audienceUsed,
  });

  int getPowerUpCount(String powerUpId) {
    switch (powerUpId) {
      case 'power_up_fifty_fifty':
        return fiftyFiftyUsed;
      case 'power_up_call_friend':
        return callFriendUsed;
      case 'power_up_audience':
        return audienceUsed;
      default:
        return 0;
    }
  }
}
