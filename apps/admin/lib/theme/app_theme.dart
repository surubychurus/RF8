import 'package:flutter/material.dart';

import 'brand.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: Brand.primary, brightness: Brightness.dark).copyWith(
    primary: Brand.primary,
    onPrimary: Brand.onPrimary,
    surface: Brand.surface,
    onSurface: Brand.textPrimary,
    surfaceContainerHighest: Brand.surfaceHigh,
    outline: Brand.outline,
    error: Brand.danger,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    fontFamily: Brand.bodyFont,
  );
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: c, width: w),
      );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: Brand.displayFont ?? Brand.bodyFont,
      bodyColor: Brand.textPrimary,
      displayColor: Brand.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: Brand.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Brand.outline),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Brand.surface,
      border: border(Brand.outline),
      enabledBorder: border(Brand.outline),
      focusedBorder: border(Brand.primary, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 50),
        foregroundColor: Brand.textPrimary,
        side: const BorderSide(color: Brand.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Brand.surface,
      indicatorColor: Brand.primary.withValues(alpha: 0.25),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: Brand.outline, space: 1),
  );
}
