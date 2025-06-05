import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocalizationHelper {
  static const Map<String, double> currencyRates = {
    'US': 0.000064, // 1 IDR = 0.000064 USD
    'MY': 0.00030, // 1 IDR = 0.00030 MYR
    'SG': 0.000086, // 1 IDR = 0.000086 SGD
    'ID': 1.0, // Base currency
    'CN': 0.00044, // 1 IDR = 0.00044 CNY (Chinese Yuan)
    'JP': 0.0097,  // 1 IDR = 0.0097 JPY (Japanese Yen)
  };

  static const Map<String, int> timezoneOffsets = {
    // Indonesia
    'WIB': 7,    // UTC+7 (Western Indonesia)
    'WITA': 8,   // UTC+8 (Central Indonesia)
    'WIT': 9,    // UTC+9 (Eastern Indonesia)
    
    // Other countries
    'PST': -7,
    'CST': -5,
    'EST': -4,   // UTC-4 (Eastern Standard Time)
    'MST': -6,   // UTC-4 (EDT - Eastern Daylight Time)
    'MY': 8,     // UTC+8 (Malaysia Time)
    'SG': 8,     // UTC+8 (Singapore Time)
    'CN': 8,     // UTC+8 (China Standard Time)
    'JP': 9,     // UTC+9 (Japan Standard Time)
  };

  // Format time based on Indonesian timezone
  static String formatLocalTime(DateTime time, String timezone) {
    try {
      final offset = timezoneOffsets[timezone] ?? 7; // Default to WIB
    
      // Get the current UTC offset of the input time
      final currentOffset = time.timeZoneOffset.inHours;
    
      // Calculate the difference between desired timezone and current timezone
      final offsetDiff = offset - currentOffset;
    
      // Add the difference to get the correct local time
      final localTime = time.add(Duration(hours: offsetDiff));
    
      // Format with the timezone suffix
      return '${DateFormat('dd MMM yyyy HH:mm').format(localTime)} $timezone';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Format currency based on country code
  static String formatLocalPrice(int idrAmount, String countryCode) {
    try {
      final rate = currencyRates[countryCode] ?? 1.0; // Default to IDR
      final localAmount = idrAmount * rate;

      return NumberFormat.currency(
        symbol: _getCurrencySymbol(countryCode),
        decimalDigits: 2,
      ).format(localAmount);
    } catch (e) {
      return NumberFormat.currency(symbol: 'IDR ').format(idrAmount);
    }
  }

  // Get currency symbol based on country code
  static String _getCurrencySymbol(String code) {
    switch (code) {
      case 'MY':
        return 'RM ';
      case 'SG':
        return 'SGD ';
      case 'US':
        return '\$';
      case 'CN': 
        return 'CN¥ '; // Updated to clearly indicate Chinese Yuan
      case 'JP':
        return '¥ ';   // Japanese Yen symbol
      default:
        return 'IDR ';
    }
  }

  // Detect timezone based on location
  static Future<String> detectTimezone() async {
    try {
      // Request location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return 'WIB';
        }
      }

      final position = await Geolocator.getCurrentPosition();
      final locations = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (locations.isEmpty) return 'WIB';

      // Get country code and use coordinates for precise detection
      final countryCode = locations.first.isoCountryCode ?? 'ID';

      // US timezone detection based on longitude
      if (countryCode == 'US') {
        if (position.longitude < -115) return 'PST';       // Pacific Time
        if (position.longitude < -100) return 'MST';       // Mountain Time
        if (position.longitude < -87) return 'CST';        // Central Time
        return 'EST';                                      // Eastern Time
      }

      // China timezone detection (all China uses one timezone)
      if (countryCode == 'CN') return 'CN';

      // Japan timezone detection
      if (countryCode == 'JP') return 'JP';

      // Malaysia and Singapore (same timezone)
      if (countryCode == 'MY' || countryCode == 'SG') return 'SGT';

      // Indonesia timezone detection based on longitude
      if (countryCode == 'ID') {
        if (position.longitude >= 120) return 'WIT';       // East Indonesia
        if (position.longitude >= 110) return 'WITA';      // Central Indonesia
        return 'WIB';                                      // West Indonesia
      }

      return 'WIB'; // Default fallback
    } catch (e) {
      return 'WIB'; // Error fallback
    }
  }

  // Format date and time with timezone
  static Future<String> formatDateTimeWithTimezone(DateTime dateTime) async {
    final timezone = await detectTimezone();
    return formatLocalTime(dateTime, timezone);
  }

  // Detect country code based on location
  static Future<String> detectCountryCode() async {
    try {
      final position = await Geolocator.getCurrentPosition();
      final locations = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      if (locations.isEmpty) return 'ID';

      final countryCode = locations.first.isoCountryCode ?? 'ID';
      return currencyRates.containsKey(countryCode) ? countryCode : 'ID';
    } catch (e) {
      return 'ID'; // Fallback to Indonesia
    }
  }
}
