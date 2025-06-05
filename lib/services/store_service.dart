import 'package:hive/hive.dart';
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
    // Register the StoreItem adapter
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(StoreItemAdapter());
    }

    // Open the store box
    _storeBox = await Hive.openBox<StoreItem>('store_items');

    // Initialize default items if empty
    if (_storeBox.isEmpty) {
      await _initializeDefaultItems();
    }
  }

  Future<void> _initializeDefaultItems() async {
    final defaultItems = StoreItem.getDefaultItems();
    for (var item in defaultItems) {
      await _storeBox.put(item.id, item);
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
    return _storeBox.values.where((item) => item.type == 'top_up').toList();
  }

  List<StoreItem> getPowerUpItems() {
    return _storeBox.values.where((item) => item.type == 'power_up').toList();
  }
  Future<String> getLocalizedPrice(double dolarAmount) async {
    final idrAmount = CurrencyConverter.dolarToRupiah(dolarAmount);
    final countryCode = await LocalizationHelper.detectCountryCode();
    return '${CurrencyConverter.formatDolar(dolarAmount)} (${LocalizationHelper.formatLocalPrice(idrAmount.toInt(), countryCode)})';
  }
}
