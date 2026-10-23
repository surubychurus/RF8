import 'package:flutter/material.dart';

import 'brand.dart';

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: Brand.primary,
    brightness: Brightness.dark,
  ).copyWith(
    primary: Brand.primary,
    onPrimary: Brand.onPrimary,
    surface: Brand.surface,
    onSurface: Brand.textPrimary,
    surfaceContainerHighest: Brand.surfaceHigh,
    outline: Brand.outline,
  );

  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Brand.background,
    fontFamily: Brand.bodyFont,
  );

  final display = base.textTheme.apply(
    fontFamily: Brand.displayFont ?? Brand.bodyFont,
    bodyColor: Brand.textPrimary,
    displayColor: Brand.textPrimary,
  );

  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: Brand.textPrimary, displayColor: Brand.textPrimary)
        .copyWith(
          displayLarge: display.displayLarge,
          displayMedium: display.displayMedium,
          displaySmall: display.displaySmall,
          headlineLarge: display.headlineLarge?.copyWith(fontWeight: FontWeight.w800),
          headlineMedium: display.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
          headlineSmall: display.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          titleLarge: display.titleLarge?.copyWith(fontWeight: FontWeight.w700),
        ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Brand.background,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      elevation: 0,
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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.outline),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Brand.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: Brand.textPrimary,
        side: const BorderSide(color: Brand.outline),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Brand.surface,
      indicatorColor: Brand.primary.withValues(alpha: 0.18),
      iconTheme: WidgetStateProperty.resolveWith(
        (s) => IconThemeData(
          color: s.contains(WidgetState.selected) ? Brand.primary : Brand.textSecondary,
        ),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (s) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: s.contains(WidgetState.selected) ? Brand.textPrimary : Brand.textSecondary,
        ),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    dividerTheme: const DividerThemeData(color: Brand.outline, space: 1),
  );
}
