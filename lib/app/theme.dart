import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// TRYP passenger palette — black, TRYP red, and white with neutral shades.
class TRYPColors {
  // Brand and action colors.
  static const Color primary = Color(0xFFE31B23);
  static const Color primaryAlt = Color(0xFFB5121B);
  static const Color secondary = Color(0xFF0B0B0B);
  static const Color accent = Color(0xFFC9151E);
  static const Color accentSoft = Color(0xFFFCEBED);

  // Surfaces.
  static const Color surface = Color(0xFFF7F7F7);
  static const Color background = Color(0xFFFFFFFF);
  static const Color dark = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color divider = Color(0xFFE5E5E5);

  // Supporting colors.
  static const Color grey = Color(0xFF6B6B6B);
  static const Color muted = Color(0xFF8A8A8A);
  static const Color secondaryLight = Color(0xFFBDBDBD);
  static const Color greyLight = Color(0xFFE5E5E5);
  static const Color lightGrey = Color(0xFFF1F1F1);
  // Status colors stay within the TRYP brand palette.
  static const Color success = Color(0xFF0B0B0B);
  static const Color liveTracking = Color(0xFFE31B23);
  static const Color error = Color(0xFFC9151E);
  static const Color warning = Color(0xFFC9151E);

  // Backward-compatible alias used by existing screens.
  static const Color amber = accent;
}

/// TRYP Typography — clean, neutral, and highly legible.
class TRYPTypography {
  static TextStyle get headingXL => GoogleFonts.inter(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: TRYPColors.dark,
    letterSpacing: -0.9,
  );

  static TextStyle get headingLarge => GoogleFonts.inter(
    fontSize: 29,
    fontWeight: FontWeight.w700,
    color: TRYPColors.dark,
    letterSpacing: -0.5,
  );

  static TextStyle get headingMedium => GoogleFonts.inter(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    color: TRYPColors.dark,
    letterSpacing: -0.3,
  );

  static TextStyle get headingSmall => GoogleFonts.inter(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: TRYPColors.dark,
  );

  static TextStyle get titleLarge => GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: TRYPColors.dark,
  );

  static TextStyle get titleMedium => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: TRYPColors.dark,
  );

  static TextStyle get bodyLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: TRYPColors.dark,
  );

  static TextStyle get bodyMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: TRYPColors.secondary,
  );

  static TextStyle get bodySmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: TRYPColors.muted,
  );

  static TextStyle get labelLarge => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: TRYPColors.primary,
  );

  static TextStyle get labelMedium => GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w700,
    color: TRYPColors.primary,
  );

  static TextStyle get labelSmall => GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: TRYPColors.grey,
  );

  static TextStyle get buttonText => GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: TRYPColors.white,
    letterSpacing: 0.1,
  );
}

/// TRYP Theme — white canvas, black actions, and red brand highlights.
class TRYPTheme {
  static const ColorScheme lightColorScheme = ColorScheme.light(
    primary: TRYPColors.primary,
    onPrimary: TRYPColors.white,
    secondary: TRYPColors.secondary,
    onSecondary: TRYPColors.white,
    tertiary: TRYPColors.primaryAlt,
    onTertiary: TRYPColors.white,
    surface: TRYPColors.white,
    onSurface: TRYPColors.dark,
    error: TRYPColors.error,
    onError: TRYPColors.white,
  );

  static const ColorScheme darkColorScheme = ColorScheme.dark(
    primary: TRYPColors.white,
    onPrimary: TRYPColors.dark,
    secondary: TRYPColors.white,
    onSecondary: TRYPColors.dark,
    tertiary: TRYPColors.primaryAlt,
    onTertiary: TRYPColors.white,
    surface: Color(0xFF111111),
    onSurface: TRYPColors.white,
    error: TRYPColors.error,
    onError: TRYPColors.white,
  );

  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: lightColorScheme,
    textTheme: TextTheme(
      displayLarge: TRYPTypography.headingXL,
      displayMedium: TRYPTypography.headingLarge,
      displaySmall: TRYPTypography.headingMedium,
      headlineSmall: TRYPTypography.headingSmall,
      titleLarge: TRYPTypography.titleLarge,
      titleMedium: TRYPTypography.titleMedium,
      bodyLarge: TRYPTypography.bodyLarge,
      bodyMedium: TRYPTypography.bodyMedium,
      bodySmall: TRYPTypography.bodySmall,
      labelLarge: TRYPTypography.labelLarge,
      labelMedium: TRYPTypography.labelMedium,
      labelSmall: TRYPTypography.labelSmall,
    ),
    scaffoldBackgroundColor: TRYPColors.background,
    canvasColor: TRYPColors.background,
    appBarTheme: const AppBarTheme(
      backgroundColor: TRYPColors.background,
      foregroundColor: TRYPColors.primary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: TRYPColors.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TRYPColors.divider),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TRYPColors.primary,
        foregroundColor: TRYPColors.white,
        disabledBackgroundColor: TRYPColors.greyLight,
        disabledForegroundColor: TRYPColors.grey,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TRYPTypography.buttonText,
        elevation: 0,
        shadowColor: Colors.transparent,
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TRYPColors.primary,
        side: const BorderSide(color: TRYPColors.primary, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: TRYPTypography.buttonText.copyWith(
          color: TRYPColors.primary,
        ),
        minimumSize: const Size(double.infinity, 56),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TRYPColors.primary,
        textStyle: TRYPTypography.labelMedium,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TRYPColors.inputFill,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TRYPColors.primary, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TRYPColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TRYPColors.error, width: 1.4),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      labelStyle: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.grey),
      floatingLabelStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.primary,
      ),
      hintStyle: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.muted),
      errorStyle: TRYPTypography.bodySmall.copyWith(color: TRYPColors.error),
      prefixIconColor: TRYPColors.grey,
      suffixIconColor: TRYPColors.grey,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TRYPColors.white,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TRYPTypography.titleLarge,
      contentTextStyle: TRYPTypography.bodyMedium,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TRYPColors.white,
      surfaceTintColor: Colors.transparent,
    ),
    dividerTheme: const DividerThemeData(
      color: TRYPColors.divider,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TRYPColors.primary,
      contentTextStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.white,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: darkColorScheme,
    textTheme: TextTheme(
      displayLarge: TRYPTypography.headingXL.copyWith(color: TRYPColors.white),
      displayMedium: TRYPTypography.headingLarge.copyWith(
        color: TRYPColors.white,
      ),
      displaySmall: TRYPTypography.headingMedium.copyWith(
        color: TRYPColors.white,
      ),
      headlineSmall: TRYPTypography.headingSmall.copyWith(
        color: TRYPColors.white,
      ),
      titleLarge: TRYPTypography.titleLarge.copyWith(color: TRYPColors.white),
      titleMedium: TRYPTypography.titleMedium.copyWith(color: TRYPColors.white),
      bodyLarge: TRYPTypography.bodyLarge.copyWith(color: TRYPColors.white),
      bodyMedium: TRYPTypography.bodyMedium.copyWith(color: TRYPColors.white),
      bodySmall: TRYPTypography.bodySmall.copyWith(
        color: TRYPColors.secondaryLight,
      ),
      labelLarge: TRYPTypography.labelLarge.copyWith(color: TRYPColors.white),
      labelMedium: TRYPTypography.labelMedium.copyWith(color: TRYPColors.white),
      labelSmall: TRYPTypography.labelSmall.copyWith(
        color: TRYPColors.secondaryLight,
      ),
    ),
    scaffoldBackgroundColor: TRYPColors.dark,
    appBarTheme: const AppBarTheme(
      backgroundColor: TRYPColors.dark,
      foregroundColor: TRYPColors.white,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TRYPColors.white,
        foregroundColor: TRYPColors.dark,
        disabledBackgroundColor: TRYPColors.accent,
        disabledForegroundColor: TRYPColors.secondaryLight,
        textStyle: TRYPTypography.buttonText.copyWith(color: TRYPColors.dark),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TRYPColors.white,
        side: const BorderSide(color: TRYPColors.white),
        textStyle: TRYPTypography.buttonText.copyWith(color: TRYPColors.white),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TRYPColors.secondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: TRYPColors.white, width: 1.4),
      ),
      labelStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.secondaryLight,
      ),
      floatingLabelStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.white,
      ),
      hintStyle: TRYPTypography.bodyLarge.copyWith(
        color: TRYPColors.secondaryLight,
      ),
      prefixIconColor: TRYPColors.secondaryLight,
      suffixIconColor: TRYPColors.secondaryLight,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TRYPColors.white,
      contentTextStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.dark,
      ),
      behavior: SnackBarBehavior.floating,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TRYPColors.secondary,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: TRYPColors.secondary,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TRYPTypography.titleLarge.copyWith(
        color: TRYPColors.white,
      ),
      contentTextStyle: TRYPTypography.bodyMedium.copyWith(
        color: TRYPColors.white,
      ),
    ),
  );
}
