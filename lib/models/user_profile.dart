class UserProfile {
  final String username;
  final String email;
  final String profilePicPath;
  final double dollarBalance;
  final List<PurchaseHistory> purchaseHistory;
  final PowerUpStats powerUpStats;

  UserProfile({
    required this.username,
    required this.email,
    required this.profilePicPath,
    required this.dollarBalance,
    required this.purchaseHistory,
    required this.powerUpStats,
  });

  // For demo purposes, create a sample profile
  factory UserProfile.sample() {
    return UserProfile(
      username: 'Player123',
      email: 'player@email.com',
      profilePicPath: 'assets/default_avatar.png',
      dollarBalance: 125000,
      purchaseHistory: [
        PurchaseHistory(
          type: 'Top-Up',
          amount: 20000,
          price: '50,000 IDR',
          date: DateTime.parse('2023-10-25 14:30:00'),
        ),
        PurchaseHistory(
          type: 'Power-Up',
          amount: -1000,
          date: DateTime.parse('2023-10-24 09:15:00'),
          item: '50:50',
        ),
      ],
      powerUpStats: PowerUpStats(
        fiftyFiftyUsed: 12,
        callFriendUsed: 5,
        audienceUsed: 3,
      ),
    );
  }
}

class PurchaseHistory {
  final String type;
  final double amount;
  final String? price;
  final DateTime date;
  final String? item;

  PurchaseHistory({
    required this.type,
    required this.amount,
    this.price,
    required this.date,
    this.item,
  });
}

class PowerUpStats {
  final int fiftyFiftyUsed;
  final int callFriendUsed;
  final int audienceUsed;

  PowerUpStats({
    required this.fiftyFiftyUsed,
    required this.callFriendUsed,
    required this.audienceUsed,
  });
}
