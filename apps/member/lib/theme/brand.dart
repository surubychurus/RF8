import 'package:flutter/material.dart';

/// Identidad visual de RF8.
///
/// PLACEHOLDERS: reemplazar colores y tipografías por los oficiales.
///  * Logo: colocar `assets/branding/logo.png` (ver assets/branding/README.md).
///  * Tipografías: colocar los .ttf/.otf en `assets/fonts/`, descomentar el
///    bloque `fonts:` de pubspec.yaml y completar [displayFont] / [bodyFont].
class Brand {
  // --- Colores ----------------------------------------------------------------
  static const primary = Color(0xFFE10600); // PLACEHOLDER color principal
  static const onPrimary = Colors.white;
  static const background = Color(0xFF0B0B0C);
  static const surface = Color(0xFF16161A);
  static const surfaceHigh = Color(0xFF202026);
  static const outline = Color(0xFF2E2E36);
  static const textPrimary = Color(0xFFF5F5F5);
  static const textSecondary = Color(0xFF9A9AA2);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF5A623);

  // --- Tipografías ------------------------------------------------------------
  /// Tipografía de títulos (ej. 'RF8 Display'). null = fuente del sistema.
  static const String? displayFont = null; // PLACEHOLDER
  /// Tipografía de textos (ej. 'RF8 Text'). null = fuente del sistema.
  static const String? bodyFont = null; // PLACEHOLDER

  // --- Logo ---------------------------------------------------------------------
  static const logoAsset = 'assets/branding/logo.png'; // PLACEHOLDER
}
