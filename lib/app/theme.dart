import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TRYP Color Palette — Bolt-inspired: black + yellow accent
class TRYPColors {
  // Primary Accent
  static const Color primary = Color(0xFFFFCC00); // TRYP Yellow
  static const Color primaryDark = Color(0xFFE6B800);
  static const Color primaryLight = Color(0xFFFFF0A0);

  // Base
  static const Color black = Color(0xFF000000);
  static const Color secondary = Color(0xFF111111); // Near-black (main text/bg)
  static const Color secondaryLight = Color(0xFF2A2A2A);

  // Neutrals
  static const Color white = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF7F7F7);   // Off-white surface
  static const Color onSurface = Color(0xFF111111);
  static const Color inputFill = Color(0xFFF0F0F0);  // Input background
  static const Color divider = Color(0xFFE8E8E8);

  static const Color grey = Color(0xFF8E8E93);        // Muted label / hint
  static const Color greyLight = Color(0xFFD1D1D6);
  static const Color darkGrey = Color(0xFF3A3A3C);

  // Status
  static const Color success = Color(0xFF30D158);
  static const Color error = Color(0xFFFF3B30);
  static const Color warning = Color(0xFFFF9500);
  static const Color info = Color(0xFF007AFF);

  // Aliases
  static const Color lightGrey = inputFill;
}

/// TRYP Typography — Bolt-style: Inter body, Poppins display, heavy weights
class TRYPTypography {
  // Display / Hero text
  static TextStyle get displayXL => GoogleFonts.poppins(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: TRYPColors.secondary,
        height: 1.1,
        letterSpacing: -0.5,
      );

  static TextStyle get headingXL => GoogleFonts.poppins(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: TRYPColors.secondary,
        height: 1.15,
        letterSpacing: -0.5,
      );

  static TextStyle get headingLarge => GoogleFonts.poppins(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: TRYPColors.secondary,
        height: 1.2,
        letterSpacing: -0.3,
      );

  static TextStyle get headingMedium => GoogleFonts.poppins(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: TRYPColors.secondary,
        height: 1.25,
      );

  static TextStyle get headingSmall => GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: TRYPColors.secondary,
        height: 1.3,
      );

  static TextStyle get titleLarge => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
      );

  static TextStyle get titleMedium => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: TRYPColors.secondary,
      );

  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: TRYPColors.secondary,
        height: 1.5,
      );

  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: TRYPColors.secondary,
        height: 1.5,
      );

  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: TRYPColors.grey,
        height: 1.4,
      );

  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
        letterSpacing: 0.1,
      );

  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: TRYPColors.secondary,
      );

  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: TRYPColors.grey,
        letterSpacing: 0.4,
      );

  static TextStyle get buttonText => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.2,
      );
}

/// TRYP Theme — Bolt-style: clean, minimal, pill buttons
class TRYPTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: TRYPColors.primary,
      onPrimary: TRYPColors.secondary,
      secondary: TRYPColors.secondary,
      onSecondary: TRYPColors.white,
      error: TRYPColors.error,
      onError: TRYPColors.white,
      surface: TRYPColors.white,
      onSurface: TRYPColors.onSurface,
    ),
    scaffoldBackgroundColor: TRYPColors.white,
    appBarTheme: AppBarTheme(
      backgroundColor: TRYPColors.white,
      foregroundColor: TRYPColors.secondary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: const IconThemeData(color: TRYPColors.secondary, size: 24),
      titleTextStyle: TRYPTypography.headingSmall,
    ),
    textTheme: TextTheme(
      displayLarge: TRYPTypography.headingXL,
      displayMedium: TRYPTypography.headingLarge,
      displaySmall: TRYPTypography.headingMedium,
      headlineSmall: TRYPTypography.headingSmall,
      titleLarge: TRYPTypography.titleLarge,
      titleMedium: TRYPTypography.bodyLarge,
      bodyLarge: TRYPTypography.bodyLarge,
      bodyMedium: TRYPTypography.bodyMedium,
      bodySmall: TRYPTypography.bodySmall,
      labelLarge: TRYPTypography.labelLarge,
      labelMedium: TRYPTypography.labelMedium,
      labelSmall: TRYPTypography.labelSmall,
    ),
    // Pill-shaped primary button (Bolt-style)
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TRYPColors.secondary,
        foregroundColor: TRYPColors.white,
        disabledBackgroundColor: TRYPColors.greyLight,
        disabledForegroundColor: TRYPColors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: 0,
        shadowColor: Colors.transparent,
        textStyle: TRYPTypography.buttonText,
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TRYPColors.secondary,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: TRYPTypography.labelMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TRYPColors.secondary,
        side: const BorderSide(color: TRYPColors.divider, width: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
        ),
        elevation: 0,
        textStyle: TRYPTypography.buttonText,
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
    // Flat, borderless input fields (Bolt-style)
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TRYPColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TRYPColors.secondary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TRYPColors.error, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: TRYPColors.error, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      hintStyle: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.grey),
      errorStyle: TRYPTypography.bodySmall.copyWith(color: TRYPColors.error),
      floatingLabelBehavior: FloatingLabelBehavior.never,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TRYPColors.primary,
      foregroundColor: TRYPColors.secondary,
      elevation: 4,
      shape: CircleBorder(),
    ),
    dividerTheme: const DividerThemeData(
      color: TRYPColors.divider,
      thickness: 1,
      space: 1,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: TRYPColors.inputFill,
      selectedColor: TRYPColors.primary,
      labelStyle: TRYPTypography.labelMedium,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(100)),
      side: BorderSide.none,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TRYPColors.secondary,
      contentTextStyle: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.white),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: TRYPColors.primary,
      onPrimary: TRYPColors.secondary,
      secondary: TRYPColors.white,
      onSecondary: TRYPColors.secondary,
      error: TRYPColors.error,
      onError: TRYPColors.white,
      surface: Color(0xFF1C1C1E),
      onSurface: TRYPColors.white,
    ),
    scaffoldBackgroundColor: TRYPColors.secondary,
  );
}
