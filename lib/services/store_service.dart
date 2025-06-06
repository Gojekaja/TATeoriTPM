import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/store_item.dart';
import '../models/user.dart';
import '../utils/currency_converter.dart';
import '../utils/localization_helper.dart';
import 'auth_service.dart';
import 'database_service.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();
  final AuthService _authService = AuthService();
  final DatabaseService _db = DatabaseService();

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

  Future<void> init() async {
    try {
      print('memulai inisialisasi store...');

      // Wait for database to be initialized if it isn't already
      if (!_db.isInitialized) {
        await _db.init();
      }

      // Initialize default items if empty
      if (_db.storeBox.isEmpty) {
        print('box store kosong, memuat barang default...');
        await _initializeDefaultItems();
        print(
          'barang default berhasil dimuat. jumlah barang: ${_db.storeBox.length}',
        );
      } else {
        print('store memiliki barang yang sudah ada: ${_db.storeBox.length}');
        // Verify items are valid
        final topUpItems = getTopUpItems();
        final powerUpItems = getPowerUpItems();
        print(
          'Found ${topUpItems.length} top-up and ${powerUpItems.length} power-up items',
        );

        if (topUpItems.isEmpty && powerUpItems.isEmpty) {
          print('tidak ada barang yang valid, mereset store...');
          await resetStore();
        }
      }
    } catch (e, stackTrace) {
      print('error kritis saat inisialisasi store:');
      print('error: $e');
      print('trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> resetStore() async {
    try {
      print('memulai mereset store...');

      // Clear any existing items
      print('menghapus semua barang yang sudah ada...');
      await _db.storeBox.clear();

      // Initialize with default items
      print('menambahkan barang default...');
      await _initializeDefaultItems();
      print(
        'mereset store selesai. store sekarang memiliki ${_db.storeBox.length} barang',
      );
    } catch (e, stackTrace) {
      print('error saat mereset store:');
      print('error: $e');
      print('trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _initializeDefaultItems() async {
    try {
      print('memuat barang default...');
      final defaultItems = StoreItem.getDefaultItems();
      print('ditemukan ${defaultItems.length} barang default');

      // Clear existing items first
      await _db.storeBox.clear();
      print('menghapus barang yang sudah ada');

      for (var item in defaultItems) {
        print('menambahkan barang: ${item.id} - ${item.name} (${item.type})');
        await _db.storeBox.put(item.id, item);
      }

      print('semua barang default berhasil ditambahkan');
      print('store sekarang memiliki ${_db.storeBox.length} barang');

      // Verify items were added
      final topUpItems = getTopUpItems();
      final powerUpItems = getPowerUpItems();
      print(
        'verifikasi - ditemukan ${topUpItems.length} barang top-up dan ${powerUpItems.length} barang power-up',
      );
    } catch (e, stackTrace) {
      print('error saat memuat barang default:');
      print('error: $e');
      print('trace: $stackTrace');
      rethrow;
    }
  }

  Future<bool> purchaseTopUp(String itemId) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    final item = _db.storeBox.get(itemId);
    if (item == null) throw Exception('barang tidak ditemukan');
    if (item.type != 'top_up') throw Exception('jenis barang tidak valid');

    // Check if balance would exceed maximum
    final maxBalance = 10000000.0; // 10 million Dolar limit
    if (user.dolarBalance + item.dolarPrice > maxBalance) {
      return false; // Return false instead of throwing exception
    }

    // Add purchase record
    user.purchaseHistory.add(
      PurchaseHistory(
        type: item.type,
        amount: item.dolarPrice,
        date: DateTime.now(),
        item: item.name,
        price: '${item.dolarPrice.toStringAsFixed(0)} Dolar',
      ),
    );

    // Update balance
    user.dolarBalance += item.dolarPrice;

    // Save changes
    await user.save();
    return true;
  }

  Future<bool> purchasePowerUp(String itemId) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    final item = _db.storeBox.get(itemId);
    if (item == null) throw Exception('Item not found');
    if (item.type != 'power_up') throw Exception('Invalid item type');

    // Check if user has enough balance
    if (user.dolarBalance < item.dolarPrice) {
      return false;
    }

    // Add purchase record
    user.purchaseHistory.add(
      PurchaseHistory(
        type: item.type,
        amount: -item.dolarPrice,
        date: DateTime.now(),
        item: item.name,
        price: '${item.dolarPrice.toStringAsFixed(0)} Dolar',
      ),
    );

    // Update balance and power-ups
    user.dolarBalance -= item.dolarPrice;

    // Update power-up count
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

    // Save changes
    await user.save();
    return true;
  }

  List<StoreItem> getTopUpItems() {
    try {
      print('Getting top-up items...');
      print('Store box length: ${_db.storeBox.length}');
      print(
        'Store box values: ${_db.storeBox.values.map((e) => '${e.id}: ${e.name}').join(', ')}',
      );

      final items =
          _db.storeBox.values.where((item) => item.type == 'top_up').toList()
            ..sort((a, b) => a.dolarPrice.compareTo(b.dolarPrice));

      print('Found ${items.length} top-up items:');
      for (var item in items) {
        print('- ${item.id}: ${item.name} (${item.dolarPrice} Dolar)');
      }
      return items;
    } catch (e, stackTrace) {
      print('Error getting top-up items:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      return [];
    }
  }

  List<StoreItem> getPowerUpItems() {
    try {
      print('Getting power-up items...');
      final items = _db.storeBox.values
          .where((item) => item.type == 'power_up')
          .toList();
      print('Found ${items.length} power-up items:');
      for (var item in items) {
        print('- ${item.id}: ${item.name}');
      }
      return items;
    } catch (e) {
      print('Error getting power-up items: $e');
      return [];
    }
  }

  Future<String> getLocalizedPrice(double dolarAmount) async {
    try {
      final idrAmount = CurrencyConverter.dolarToRupiah(dolarAmount);
      final countryCode = await LocalizationHelper.detectCountryCode();
      final localPrice = LocalizationHelper.formatLocalPrice(
        idrAmount.toInt(),
        countryCode,
      );
      return localPrice;
    } catch (e) {
      // If anything fails, just show the dolar amount
      return CurrencyConverter.formatDolar(dolarAmount);
    }
  }
}
