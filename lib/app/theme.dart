import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TRYP Color Palette
class TRYPColors {
  // Primary Colors
  static const Color primary = Color(0xFFFFCC00); // Bright Yellow
  static const Color primaryDark = Color(0xFFE6B800);
  static const Color primaryLight = Color(0xFFFFE66D);

  // Secondary Colors
  static const Color secondary = Color(0xFF1A1A1A); // Black
  static const Color secondaryLight = Color(0xFF333333);

  // Status Colors
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);

  // Neutral Colors
  static const Color white = Color(0xFFFFFFFF);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color darkGrey = Color(0xFF424242);
  static const Color black = Color(0xFF000000);

  // Semantic
  static const Color surface = Color(0xFFFAFAFA);
  static const Color onSurface = Color(0xFF1A1A1A);
}

/// TRYP Typography
class TRYPTypography {
  static TextStyle get headingXL => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: TRYPColors.secondary,
      );

  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: TRYPColors.secondary,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: TRYPColors.secondary,
      );

  static TextStyle get headingSmall => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: TRYPColors.secondary,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: TRYPColors.secondary,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: TRYPColors.grey,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
      );
}

/// TRYP Theme Data
class TRYPTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: TRYPColors.primary,
      onPrimary: TRYPColors.secondary,
      secondary: TRYPColors.secondary,
      onSecondary: TRYPColors.white,
      error: TRYPColors.error,
      onError: TRYPColors.white,
      surface: TRYPColors.surface,
      onSurface: TRYPColors.onSurface,
    ),
    scaffoldBackgroundColor: TRYPColors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: TRYPColors.white,
      foregroundColor: TRYPColors.secondary,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TRYPTypography.headingSmall,
    ),
    textTheme: TextTheme(
      displayLarge: TRYPTypography.headingXL,
      displayMedium: TRYPTypography.headingLarge,
      displaySmall: TRYPTypography.headingMedium,
      headlineSmall: TRYPTypography.headingSmall,
      titleLarge: TRYPTypography.bodyLarge,
      titleMedium: TRYPTypography.bodyMedium,
      bodyLarge: TRYPTypography.bodyLarge,
      bodyMedium: TRYPTypography.bodyMedium,
      bodySmall: TRYPTypography.bodySmall,
      labelLarge: TRYPTypography.labelLarge,
      labelMedium: TRYPTypography.labelMedium,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TRYPColors.primary,
        foregroundColor: TRYPColors.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TRYPTypography.labelLarge,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TRYPColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: TRYPTypography.labelLarge,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TRYPColors.primary,
        side: const BorderSide(color: TRYPColors.primary),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: TRYPTypography.labelLarge,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TRYPColors.lightGrey,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TRYPColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TRYPColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: TRYPColors.error, width: 2),
      ),
      contentPadding: const EdgeInsets.all(16),
      hintStyle: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: TRYPColors.primary,
      foregroundColor: TRYPColors.secondary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: TRYPColors.primary,
      onPrimary: TRYPColors.secondary,
      secondary: TRYPColors.white,
      onSecondary: TRYPColors.secondary,
      error: TRYPColors.error,
      onError: TRYPColors.secondary,
      surface: TRYPColors.darkGrey,
      onSurface: TRYPColors.white,
    ),
    scaffoldBackgroundColor: TRYPColors.secondary,
  );
}
