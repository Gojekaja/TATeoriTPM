class CurrencyConverter {
  // Static conversion rates (based on IDR)
  static const double dolarToIdr = 50; // 1 dolar = 50 IDR (game currency)
  static const double idrToMyr = 0.00029; // Malaysian Ringgit
  static const double idrToSgd = 0.000087; // Singapore Dollar
  static const double idrToEur = 0.000060; // Euro
  static const double idrToGbp = 0.000052; // British Pound
  static const double idrToJpy = 0.0097; // Japanese Yen
  static const double idrToAud = 0.000099; // Australian Dollar
  static const double idrToCny = 0.00047; // Chinese Yuan
  static const double idrToKrw = 0.086; // South Korean Won
  static const double idrToInr = 0.0054; // Indian Rupee
  static const double idrToUsd = 0.000064; // US Dollar
  static const double idrToCad = 0.000087; // Canadian Dollar
  static const double idrToNzd = 0.00011; // New Zealand Dollar
  static const double idrToChf = 0.000058; // Swiss Franc
  static const double idrToHkd = 0.00050; // Hong Kong Dollar

  // Convert game dolar to IDR
  static double dolarToRupiah(double dolar) => dolar * dolarToIdr;

  // Convert IDR to other currencies
  static double toMyr(double idr) => idr * idrToMyr;
  static double toSgd(double idr) => idr * idrToSgd;
  static double toEur(double idr) => idr * idrToEur;
  static double toGbp(double idr) => idr * idrToGbp;
  static double toJpy(double idr) => idr * idrToJpy;
  static double toAud(double idr) => idr * idrToAud;
  static double toCny(double idr) => idr * idrToCny;
  static double toKrw(double idr) => idr * idrToKrw;
  static double toInr(double idr) => idr * idrToInr;
  static double toUsd(double idr) => idr * idrToUsd;
  static double toCad(double idr) => idr * idrToCad;
  static double toNzd(double idr) => idr * idrToNzd;
  static double toChf(double idr) => idr * idrToChf;
  static double toHkd(double idr) => idr * idrToHkd;

  // Format currency with symbol following local conventions
  static String formatIdr(double amount) {
    final formatted = amount.toStringAsFixed(0);
    final parts = [];
    for (var i = formatted.length; i > 0; i -= 3) {
      parts.add(formatted.substring(i < 3 ? 0 : i - 3, i));
    }
    return 'Rp ${parts.reversed.join('.')}';
  }

  static String formatMyr(double amount) {
    return 'RM ${amount.toStringAsFixed(2)}';
  }

  static String formatSgd(double amount) {
    return 'S\$ ${amount.toStringAsFixed(2)}';
  }

  static String formatEur(double amount) {
    return '€${amount.toStringAsFixed(2)}';
  }

  static String formatGbp(double amount) {
    return '£${amount.toStringAsFixed(2)}';
  }

  static String formatJpy(double amount) {
    return '¥${amount.toStringAsFixed(0)}';
  }

  static String formatAud(double amount) {
    return 'A\$ ${amount.toStringAsFixed(2)}';
  }

  static String formatCny(double amount) {
    return 'CN¥${amount.toStringAsFixed(2)}';
  }

  static String formatKrw(double amount) {
    return '₩${amount.toStringAsFixed(0)}';
  }

  static String formatInr(double amount) {
    final String amountStr = amount.toStringAsFixed(2);
    final List<String> parts = amountStr.split('.');
    final String wholePart = parts[0].replaceAllMapped(
      RegExp(r'(\d)(?=(\d\d)+\d$)'),
      (Match m) => '${m[1]},',
    );
    return '₹$wholePart.${parts[1]}';
  }

  static String formatUsd(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  static String formatCad(double amount) {
    return 'C\$${amount.toStringAsFixed(2)}';
  }

  static String formatNzd(double amount) {
    return 'NZ\$${amount.toStringAsFixed(2)}';
  }

  static String formatChf(double amount) {
    return 'CHF ${amount.toStringAsFixed(2)}';
  }

  static String formatHkd(double amount) {
    return 'HK\$${amount.toStringAsFixed(2)}';
  }

  static String formatDolar(double amount) {
    return '${amount.toStringAsFixed(0)} Dolar';
  }

  // Get all currency conversions for a dolar amount
  static Map<String, String> getAllConversions(double dolarAmount) {
    final idrAmount = dolarToRupiah(dolarAmount);
    return {
      'Dolar': formatDolar(dolarAmount),
      'IDR': formatIdr(idrAmount),
      'USD': formatUsd(toUsd(idrAmount)),
      'EUR': formatEur(toEur(idrAmount)),
      'GBP': formatGbp(toGbp(idrAmount)),
      'JPY': formatJpy(toJpy(idrAmount)),
      'AUD': formatAud(toAud(idrAmount)),
      'CAD': formatCad(toCad(idrAmount)),
      'SGD': formatSgd(toSgd(idrAmount)),
      'CHF': formatChf(toChf(idrAmount)),
      'HKD': formatHkd(toHkd(idrAmount)),
      'CNY': formatCny(toCny(idrAmount)),
      'NZD': formatNzd(toNzd(idrAmount)),
      'MYR': formatMyr(toMyr(idrAmount)),
      'KRW': formatKrw(toKrw(idrAmount)),
      'INR': formatInr(toInr(idrAmount)),
    };
  }

  // For game amounts with IDR conversion
  static String formatGameDolar(double dolarAmount) {
    return '${dolarAmount.toStringAsFixed(0)} Dolar';
  }
}
