import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocalizationHelper {
  static const Map<String, double> currencyRates = {
    'US': 0.000064, // USD
    'MY': 0.00030, // MYR
    'SG': 0.000086, // SGD
    'ID': 1.0, // Base currency (IDR)
    'CN': 0.00044, // CNY
    'JP': 0.0097, // JPY
    'GB': 0.000052, // GBP
    'EU': 0.000060, // EUR
    'AU': 0.000099, // AUD
    'CA': 0.000087, // CAD
    'NZ': 0.00011, // NZD
    'CH': 0.000058, // CHF
    'HK': 0.00050, // HKD
    'KR': 0.086, // KRW
    'IN': 0.0054, // INR
  };

  static const Map<String, String> currencySymbols = {
    'US': '\$',
    'MY': 'RM',
    'SG': 'SGD',
    'ID': 'Rp',
    'CN': 'CN¥',
    'JP': '¥',
    'GB': '£',
    'EU': '€',
    'AU': 'A\$',
    'CA': 'C\$',
    'NZ': 'NZ\$',
    'CH': 'CHF',
    'HK': 'HK\$',
    'KR': '₩',
    'IN': '₹',
  };

  static const Map<String, int> timezoneOffsets = {
    // Indonesia
    'WIB': 7, // UTC+7 (Western Indonesia)
    'WITA': 8, // UTC+8 (Central Indonesia)
    'WIT': 9, // UTC+9 (Eastern Indonesia)
    // Other countries
    'PST': -7, // UTC-7 (Pacific Standard Time)
    'MST': -6, // UTC-6 (Mountain Standard Time)
    'CST': -5, // UTC-5 (Central Standard Time)
    'EST': -4, // UTC-4 (Eastern Standard Time)
    'AST': -4, // UTC-4 (Atlantic Standard Time)
    'BRT': -3, // UTC-3 (Brasília Time)
    'GMT': 0, // UTC+0 (Greenwich Mean Time)
    'CET': 1, // UTC+1 (Central European Time)
    'EET': 2, // UTC+2 (Eastern European Time)
    'MSK': 3, // UTC+3 (Moscow Standard Time)
    'GST': 4, // UTC+4 (Gulf Standard Time)
    'PKT': 5, // UTC+5 (Pakistan Standard Time)
    'BDT': 6, // UTC+6 (Bangladesh Standard Time)
    'MY': 8, // UTC+8 (Malaysia Time - SGT)
    'SG': 8, // UTC+8 (Singapore Time - SGT)
    'CST_CN': 8, // UTC+8 (China Standard Time)
    'JP': 9, // UTC+9 (Japan Standard Time)
    'KST': 9, // UTC+9 (Korea Standard Time)
    'AEST': 10, // UTC+10 (Australian Eastern Standard Time)
    'NZDT': 13, // UTC+13 (New Zealand Daylight Time, during DST)
    'NZST': 12, // UTC+12 (New Zealand Standard Time)
  };

  // Format time based on Indonesian timezone
  static String formatLocalTime(DateTime time, String timezone) {
    try {
      // Convert the input time to UTC first
      final utcTime = time.toUtc();

      // Get the target timezone offset (in hours)
      final targetOffset = timezoneOffsets[timezone] ?? 7; // Default to WIB

      // Apply the target timezone offset to get the correct local time
      final localTime = utcTime.add(Duration(hours: targetOffset));

      // Format with the timezone suffix
      return '${DateFormat('dd MMM yyyy HH:mm').format(localTime)} $timezone';
    } catch (e) {
      return 'Invalid Date';
    }
  }

  // Format currency based on country code
  static String formatLocalPrice(int idrAmount, String countryCode) {
    try {
      final rate = currencyRates[countryCode] ?? currencyRates['ID']!;
      final symbol = currencySymbols[countryCode] ?? currencySymbols['ID']!;
      final localAmount = idrAmount * rate;

      // Special formatting for certain currencies
      if (countryCode == 'JP' || countryCode == 'KR') {
        return '$symbol${localAmount.toInt()}';
      }

      return NumberFormat.currency(
        symbol: '$symbol ',
        decimalDigits: 2,
      ).format(localAmount);
    } catch (e) {
      // Fallback to IDR format
      return NumberFormat.currency(
        symbol: 'Rp ',
        decimalDigits: 0,
      ).format(idrAmount);
    }
  }

  // Get currency symbol based on country code
  static String _getCurrencySymbol(String code) {
    return currencySymbols[code] ?? currencySymbols['ID']!;
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
        if (position.longitude < -115) return 'PST'; // Pacific Time
        if (position.longitude < -100) return 'MST'; // Mountain Time
        if (position.longitude < -87) return 'CST'; // Central Time
        return 'EST'; // Eastern Time
      }

      // China timezone detection (all China uses one timezone)
      if (countryCode == 'CN') return 'CN';

      // Japan timezone detection
      if (countryCode == 'JP') return 'JP';

      // Malaysia and Singapore (same timezone)
      if (countryCode == 'MY' || countryCode == 'SG') return 'SGT';

      // Indonesia timezone detection based on longitude
      if (countryCode == 'ID') {
        if (position.longitude >= 120) return 'WIT'; // East Indonesia
        if (position.longitude >= 110) return 'WITA'; // Central Indonesia
        return 'WIB'; // West Indonesia
      }

      return 'WIB'; // Default fallback
    } catch (e) {
      return 'WIB'; // Error fallback
    }
  }

  // Format date and time with timezone
  static Future<String> formatDateTimeWithTimezone(DateTime dateTime) async {
    try {
      final timezone = await detectTimezone();
      return formatLocalTime(dateTime, timezone);
    } catch (e) {
      // Fallback to WIB if timezone detection fails
      return formatLocalTime(dateTime, 'WIB');
    }
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
