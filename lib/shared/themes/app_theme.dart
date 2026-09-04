import 'package:flutter/material.dart';

/// Global Material 3 theme for Omega Education Centre ERP.
///
/// Primary:   Deep Blue   — professional, trust-inspiring
/// Secondary: Deep Amber  — accent, call-to-action contrast
///
/// Usage:
///   MaterialApp(theme: AppTheme.lightTheme, ...)
class AppTheme {
  AppTheme._();

  // ── Seed Colors ──────────────────────────────────────────────────────────

  static const Color _primarySeed = Color(0xFF1565C0); // Deep blue
  static const Color _secondarySeed = Color(0xFFF57F17); // Deep amber
  static const Color _scaffoldBackground = Color(0xFFF5F7FB);

  // ── Light Theme ──────────────────────────────────────────────────────────

  static ThemeData get lightTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      secondary: _secondarySeed,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _scaffoldBackground,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 3,
          shadowColor: colorScheme.primary.withAlpha(80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFBDBDBD)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: Color(0xFF757575)),
        prefixIconColor: Color(0xFF757575),
      ),

      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primary.withAlpha(30),
        showCheckmark: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
        color: Color(0xFFEEEEEE),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
      ),
    );
  }

  // ── Dark Theme ─────────────────────────────────────────────────────────

  static const Color _darkScaffoldBackground = Color(0xFF121212);
  static const Color _darkCardColor = Color(0xFF1E1E1E);
  static const Color _darkSurfaceVariant = Color(0xFF2C2C2C);

  static ThemeData get darkTheme {
    final ColorScheme colorScheme = ColorScheme.fromSeed(
      seedColor: _primarySeed,
      secondary: _secondarySeed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _darkScaffoldBackground,

      // ── AppBar ────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
      ),

      // ── Card ──────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        elevation: 3,
        shadowColor: Colors.black26,
        surfaceTintColor: _darkCardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: _darkCardColor,
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),

      // ── ElevatedButton ────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          elevation: 3,
          shadowColor: colorScheme.primary.withAlpha(80),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── TextButton ────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // ── OutlinedButton ────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.primary),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),

      // ── Input Decoration ──────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF424242)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.error, width: 2),
        ),
        filled: true,
        fillColor: _darkSurfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        labelStyle: const TextStyle(color: Color(0xFF9E9E9E)),
        prefixIconColor: const Color(0xFF9E9E9E),
      ),

      // ── FloatingActionButton ──────────────────────────────────────────────
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: colorScheme.primary,
        foregroundColor: colorScheme.onPrimary,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),

      // ── Chip ─────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        selectedColor: colorScheme.primary.withAlpha(50),
        showCheckmark: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),

      // ── ListTile ──────────────────────────────────────────────────────────
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),

      // ── SnackBar ──────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        contentTextStyle: const TextStyle(color: Colors.white),
      ),

      // ── Divider ───────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(
        thickness: 1,
        space: 1,
        color: Color(0xFF424242),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: _darkCardColor,
      ),

      // ── Bottom Sheet ──────────────────────────────────────────────────────
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        showDragHandle: true,
        backgroundColor: _darkCardColor,
      ),
    );
  }

  // ── Semantic colors (used directly in widgets) ───────────────────────────

  /// Green badge for "Paid" status.
  static const Color feePaidBackground = Color(0xFFE8F5E9);
  static const Color feePaidText = Color(0xFF2E7D32);

  /// Orange badge for "Partially Paid" status.
  static const Color feePartialBackground = Color(0xFFFFF3E0);
  static const Color feePartialText = Color(0xFFE65100);

  /// Red badge for "Due" status.
  static const Color feeDueBackground = Color(0xFFFFEBEE);
  static const Color feeDueText = Color(0xFFC62828);

  /// Dark mode variants for fee status badges.
  static const Color feePaidBackgroundDark = Color(0xFF1B3A1B);
  static const Color feePartialBackgroundDark = Color(0xFF3E2723);
  static const Color feeDueBackgroundDark = Color(0xFF3E1B1B);

  /// Returns background + text color pair for a given feeStatus label,
  /// respecting the current brightness.
  static (Color background, Color text) feeStatusColors(String status, {Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    switch (status) {
      case 'Paid':
        return (isDark ? feePaidBackgroundDark : feePaidBackground, feePaidText);
      case 'Partially Paid':
        return (isDark ? feePartialBackgroundDark : feePartialBackground, feePartialText);
      default: // Due
        return (isDark ? feeDueBackgroundDark : feeDueBackground, feeDueText);
    }
  }

  // ── High Contrast Theme (Accessibility) ────────────────────────────────

  /// High contrast light theme for users with visual impairments.
  /// WCAG AAA compliant with maximum contrast ratios.
  static ThemeData get highContrastLightTheme {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF000000),        // Pure black for maximum contrast
      onPrimary: Color(0xFFFFFFFF),       // White on black
      primaryContainer: Color(0xFF1A1A1A),
      onPrimaryContainer: Color(0xFFFFFFFF),
      secondary: Color(0xFF0000CC),       // Deep blue for links/accents
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFF000099),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFF006600),        // Deep green for success
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFF004400),
      onTertiaryContainer: Color(0xFFFFFFFF),
      error: Color(0xFFCC0000),           // Deep red for errors
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFF990000),
      onErrorContainer: Color(0xFFFFFFFF),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF000000),       // Black text on white
      onSurfaceVariant: Color(0xFF1A1A1A),
      outline: Color(0xFF000000),
      outlineVariant: Color(0xFF333333),
      shadow: Color(0xFF000000),
      surfaceTint: Color(0xFF000000),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.white,

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: IconThemeData(color: Colors.white),
        actionsIconTheme: IconThemeData(color: Colors.white),
      ),

      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: Colors.black, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w400),
        labelLarge: TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          side: const BorderSide(color: Colors.black, width: 2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.black, width: 3),
        ),
        labelStyle: const TextStyle(color: Colors.black, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: Color(0xFF333333)),
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.black,
        thickness: 2,
        space: 1,
      ),
    );
  }

  /// High contrast dark theme for users with visual impairments.
  /// Maximum contrast on dark backgrounds.
  static ThemeData get highContrastDarkTheme {
    const ColorScheme colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFFFFF),        // Pure white for maximum contrast
      onPrimary: Color(0xFF000000),       // Black on white
      primaryContainer: Color(0xFFE0E0E0),
      onPrimaryContainer: Color(0xFF000000),
      secondary: Color(0xFF6699FF),      // Bright blue for links
      onSecondary: Color(0xFF000000),
      secondaryContainer: Color(0xFF3366CC),
      onSecondaryContainer: Color(0xFFFFFFFF),
      tertiary: Color(0xFF66FF66),       // Bright green for success
      onTertiary: Color(0xFF000000),
      tertiaryContainer: Color(0xFF33CC33),
      onTertiaryContainer: Color(0xFF000000),
      error: Color(0xFFFF6666),           // Bright red for errors
      onError: Color(0xFF000000),
      errorContainer: Color(0xFFFF3333),
      onErrorContainer: Color(0xFF000000),
      surface: Color(0xFF0A0A0A),
      onSurface: Color(0xFFFFFFFF),       // White text on dark
      onSurfaceVariant: Color(0xFFE0E0E0),
      outline: Color(0xFFFFFFFF),
      outlineVariant: Color(0xFFCCCCCC),
      shadow: Color(0xFF000000),
      surfaceTint: Color(0xFFFFFFFF),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF0A0A0A),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
        iconTheme: IconThemeData(color: Colors.black),
        actionsIconTheme: IconThemeData(color: Colors.black),
      ),

      cardTheme: CardThemeData(
        color: const Color(0xFF1A1A1A),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),

      textTheme: const TextTheme(
        headlineLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        headlineMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        headlineSmall: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        bodyMedium: TextStyle(color: Colors.white, fontWeight: FontWeight.w400),
        bodySmall: TextStyle(color: Color(0xFFE0E0E0), fontWeight: FontWeight.w400),
        labelLarge: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          side: const BorderSide(color: Colors.white, width: 2),
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          side: const BorderSide(color: Colors.white, width: 2),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 2),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white, width: 3),
        ),
        labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        hintStyle: const TextStyle(color: Color(0xFFCCCCCC),),
      ),

      dividerTheme: const DividerThemeData(
        color: Colors.white,
        thickness: 2,
        space: 1,
      ),
    );
  }
}
