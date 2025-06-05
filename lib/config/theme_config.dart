import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ThemeConfig {
  // Colors
  static const primaryColor = Color(0xFF1E88E5);
  static const backgroundColor = Color(0xFF121212);
  static const surfaceColor = Color(0xFF1A1A1A);
  static const errorColor = Colors.red;
  static const successColor = Colors.green;
  static const warningColor = Colors.orange;
  static const disabledColor = Color(0xFF666666);

  // Text Styles
  static TextStyle get headingStyle => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  static TextStyle get titleStyle => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  static TextStyle get bodyStyle => GoogleFonts.inter(
        fontSize: 16,
        color: Colors.white,
      );

  static TextStyle get subtitleStyle => GoogleFonts.inter(
        fontSize: 14,
        color: Colors.grey[400],
      );

  static TextStyle get buttonTextStyle => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      );

  // Input Decoration
  static InputDecoration getInputDecoration({
    required String label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool isDense = false,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: isDense,
      labelStyle: GoogleFonts.inter(color: primaryColor),
      hintStyle: GoogleFonts.inter(color: Colors.grey[600]),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: primaryColor.withAlpha(128)),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: primaryColor),
        borderRadius: BorderRadius.circular(8),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: errorColor),
        borderRadius: BorderRadius.circular(8),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: const BorderSide(color: errorColor),
        borderRadius: BorderRadius.circular(8),
      ),
      filled: true,
      fillColor: surfaceColor,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: isDense ? 8 : 16,
      ),
    );
  }

  // Button Styles
  static ButtonStyle get primaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: buttonTextStyle,
        elevation: 2,
      );

  static ButtonStyle get secondaryButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: surfaceColor,
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: buttonTextStyle.copyWith(color: primaryColor),
        elevation: 1,
      );

  static ButtonStyle get dangerButtonStyle => ElevatedButton.styleFrom(
        backgroundColor: errorColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: buttonTextStyle,
        elevation: 2,
      );

  // Card Style
  static BoxDecoration get cardDecoration => BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      );

  // Common Spacing
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 400);
  static const Duration longAnimation = Duration(milliseconds: 800);

  // Common Border Radius
  static final BorderRadius borderRadius = BorderRadius.circular(8);
  static final BorderRadius borderRadiusLarge = BorderRadius.circular(12);

  // Common Paddings
  static const EdgeInsets paddingAll = EdgeInsets.all(spacingMd);
  static const EdgeInsets paddingHorizontal =
      EdgeInsets.symmetric(horizontal: spacingMd);
  static const EdgeInsets paddingVertical =
      EdgeInsets.symmetric(vertical: spacingMd);
}
