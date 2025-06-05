import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/store_item.dart';
import '../models/user.dart';
import '../utils/currency_converter.dart';
import '../utils/localization_helper.dart';
import 'auth_service.dart';

class StoreService {
  static final StoreService _instance = StoreService._internal();
  final AuthService _authService = AuthService();
  late final Box<StoreItem> _storeBox;

  factory StoreService() {
    return _instance;
  }

  StoreService._internal();

  Future<void> init() async {
    try {
      print('Starting store initialization...');

      // Initialize Hive if needed
      try {
        print('Ensuring Hive is initialized...');
        await Hive.initFlutter();
      } catch (e) {
        print('Hive already initialized');
      }

      // Register the StoreItem adapter
      if (!Hive.isAdapterRegistered(4)) {
        print('Registering StoreItem adapter...');
        Hive.registerAdapter(StoreItemAdapter());
        print('StoreItem adapter registered successfully');
      }

      try {
        // Open the store box
        print('Opening store box...');
        _storeBox = await Hive.openBox<StoreItem>('store_items');
        print(
          'Store box opened successfully. Items count: ${_storeBox.length}',
        );

        // Initialize default items if empty
        if (_storeBox.isEmpty) {
          print('Store box is empty, initializing default items...');
          await _initializeDefaultItems();
          print(
            'Default items initialized successfully. New count: ${_storeBox.length}',
          );
        } else {
          print('Store already has items: ${_storeBox.length}');
          // Verify items are valid
          final topUpItems = getTopUpItems();
          final powerUpItems = getPowerUpItems();
          print(
            'Found ${topUpItems.length} top-up items and ${powerUpItems.length} power-up items',
          );

          if (topUpItems.isEmpty && powerUpItems.isEmpty) {
            print('No valid items found, resetting store...');
            await resetStore();
          }
        }
      } catch (boxError) {
        print('Error with store box: $boxError');
        print('Attempting to recover...');
        await resetStore();
      }
    } catch (e, stackTrace) {
      print('Critical error in store initialization:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> resetStore() async {
    try {
      print('Starting store reset...');

      // Close the box if it's open
      if (_storeBox != null && _storeBox.isOpen) {
        print('Closing existing store box...');
        await _storeBox.close();
      }

      // Delete the store box from disk
      print('Deleting store box from disk...');
      await Hive.deleteBoxFromDisk('store_items');
      print('Store box deleted successfully');

      // Reopen the box
      print('Reopening store box...');
      _storeBox = await Hive.openBox<StoreItem>('store_items');
      print('Store box reopened successfully');

      // Initialize with default items
      print('Adding default items...');
      await _initializeDefaultItems();
      print('Store reset complete. Store has ${_storeBox.length} items');
    } catch (e, stackTrace) {
      print('Error during store reset:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<void> _initializeDefaultItems() async {
    try {
      print('Getting default items...');
      final defaultItems = StoreItem.getDefaultItems();
      print('Retrieved ${defaultItems.length} default items');

      for (var item in defaultItems) {
        print('Adding item: ${item.id} - ${item.name} (${item.type})');
        await _storeBox.put(item.id, item);
      }

      print('All default items added successfully');
    } catch (e, stackTrace) {
      print('Error initializing default items:');
      print('Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<bool> purchaseTopUp(String itemId) async {
    final user = _authService.currentUser;
    if (user == null) return false;

    final item = _storeBox.get(itemId);
    if (item == null) throw Exception('Item not found');
    if (item.type != 'top_up') throw Exception('Invalid item type');

    // Check if balance would exceed maximum
    if (user.dolarBalance + item.dolarPrice > 100000000) {
      return false;
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

    final item = _storeBox.get(itemId);
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
    final items = _storeBox.values
        .where((item) => item.type == 'top_up')
        .toList();
    print('Found ${items.length} top-up items');
    return items;
  }

  List<StoreItem> getPowerUpItems() {
    final items = _storeBox.values
        .where((item) => item.type == 'power_up')
        .toList();
    print('Found ${items.length} power-up items');
    return items;
  }

  Future<String> getLocalizedPrice(double dolarAmount) async {
    try {
      final idrAmount = CurrencyConverter.dolarToRupiah(dolarAmount);
      final countryCode = await LocalizationHelper.detectCountryCode();
      final dolarText = CurrencyConverter.formatDolar(dolarAmount);
      final localPrice = LocalizationHelper.formatLocalPrice(
        idrAmount.toInt(),
        countryCode,
      );
      return '$dolarText ($localPrice)';
    } catch (e) {
      // If anything fails, just show the dolar amount
      return CurrencyConverter.formatDolar(dolarAmount);
    }
  }
}
