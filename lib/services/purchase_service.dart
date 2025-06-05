import '../models/store_item.dart';
import '../models/user.dart';
import 'auth_service.dart';
import 'database_service.dart';

class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  final DatabaseService _db = DatabaseService();
  final AuthService _authService = AuthService();

  factory PurchaseService() => _instance;
  PurchaseService._internal();

  Future<bool> processPurchase(List<StoreItem> items) async {
    try {
      final user = _authService.currentUser;
      if (user == null) return false;

      double totalAmount = 0;
      for (var item in items) {
        totalAmount += item.dolarPrice;
      }

      // Add purchase records to history
      for (var item in items) {
        user.purchaseHistory.add(
          PurchaseHistory(
            type: item.type == 'power_up' ? 'Power-Up' : 'Top-Up',
            amount: item.type == 'top_up' ? item.dolarPrice : -item.dolarPrice,
            date: DateTime.now(),
            item: item.name,
            price: '${item.dolarPrice.toStringAsFixed(0)} Dolar',
          ),
        );

        // Update user balance and power-ups
        if (item.type == 'top_up') {
          user.dolarBalance += item.dolarPrice;
          // Update game stats for top-up
          await _db.gameStatsBox.put('${user.username}_top_up_history', {
            'lastTopUp': DateTime.now().toIso8601String(),
            'totalTopUps':
                (_db.gameStatsBox.get(
                      '${user.username}_top_up_history',
                    )?['totalTopUps'] ??
                    0) +
                1,
            'totalAmount':
                (_db.gameStatsBox.get(
                      '${user.username}_top_up_history',
                    )?['totalAmount'] ??
                    0.0) +
                item.dolarPrice,
          });
        } else if (item.type == 'power_up') {
          user.dolarBalance -= item.dolarPrice;
          switch (item.id) {
            case 'power_up_fifty_fifty':
              user.powerUpStats.fiftyFiftyUsed++;
              break;
            case 'power_up_call_friend':
              user.powerUpStats.callFriendUsed++;
              break;
            case 'power_up_audience':
              user.powerUpStats.audienceUsed++;
              break;
          }
          // Update game stats for power-up usage
          await _db.gameStatsBox.put('${user.username}_power_up_history', {
            'lastPowerUp': DateTime.now().toIso8601String(),
            'totalPowerUps':
                (_db.gameStatsBox.get(
                      '${user.username}_power_up_history',
                    )?['totalPowerUps'] ??
                    0) +
                1,
            'powerUpTypes': [
              ...(_db.gameStatsBox.get(
                    '${user.username}_power_up_history',
                  )?['powerUpTypes'] ??
                  []),
              item.id,
            ],
          });
        }
      }

      // Save changes to user box
      await _db.userBox.put(user.username, user);

      return true;
    } catch (e) {
      return false;
    }
  }

  // Get QR image path
  String getQRImagePath() {
    return 'assets/images/qr.png';
  }
}
