import 'package:hive/hive.dart';

part 'store_item.g.dart';

@HiveType(typeId: 4)
class StoreItem extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final double dolarPrice;

  @HiveField(3)
  final String type;

  @HiveField(4)
  final String? iconName;

  @HiveField(5)
  final int maxQuantity;

  StoreItem({
    required this.id,
    required this.name,
    required this.dolarPrice,
    required this.type,
    this.iconName,
    this.maxQuantity = 30,
  });
  // Helper method to convert dolar to IDR
  int get idrPrice => (dolarPrice * 30).toInt(); // 1 dolar = 3000 IDR / 100

  // Predefined store items
  static List<StoreItem> getDefaultItems() {
    return [
      // Top-up items with varied amounts
      StoreItem(
        id: 'top_up_starter',
        name: '500 Dolar',
        dolarPrice: 500, // 15,000,000 IDR
        type: 'top_up',
        maxQuantity: 5,
      ),
      StoreItem(
        id: 'top_up_small',
        name: '1,000 Dolar',
        dolarPrice: 1000, // 30,000,000 IDR
        type: 'top_up',
        maxQuantity: 5,
      ),
      StoreItem(
        id: 'top_up_medium',
        name: '2,500 Dolar',
        dolarPrice: 2500, // 75,000,000 IDR
        type: 'top_up',
        maxQuantity: 5,
      ),
      StoreItem(
        id: 'top_up_large',
        name: '5,000 Dolar',
        dolarPrice: 5000, // 150,000,000 IDR
        type: 'top_up',
        maxQuantity: 5,
      ),
      StoreItem(
        id: 'top_up_xl',
        name: '10,000 Dolar',
        dolarPrice: 10000, // 300,000,000 IDR
        type: 'top_up',
        maxQuantity: 5,
      ),
      StoreItem(
        id: 'top_up_premium',
        name: '25,000 Dolar',
        dolarPrice: 25000, // 750,000,000 IDR
        type: 'top_up',
        maxQuantity: 3,
      ),
      StoreItem(
        id: 'top_up_ultimate',
        name: '50,000 Dolar',
        dolarPrice: 50000, // 1,500,000,000 IDR
        type: 'top_up',
        maxQuantity: 2,
      ),

      // Power-up items with updated prices
      StoreItem(
        id: 'power_up_fifty_fifty',
        name: '50:50',
        dolarPrice: 5000, // 150,000,000 IDR
        type: 'power_up',
        iconName: 'percent',
        maxQuantity: 10,
      ),
      StoreItem(
        id: 'power_up_call_friend',
        name: 'Call a Friend',
        dolarPrice: 10000, // 300,000,000 IDR
        type: 'power_up',
        iconName: 'phone',
        maxQuantity: 10,
      ),
      StoreItem(
        id: 'power_up_audience',
        name: 'Audience Vote',
        dolarPrice: 15000, // 450,000,000 IDR
        type: 'power_up',
        iconName: 'people',
        maxQuantity: 10,
      ),
    ];
  }
}
