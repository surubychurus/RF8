import 'package:flutter/material.dart';

/// Identidad visual de RF8 (colores tomados del logo).
///
///  * Logo: `assets/branding/logo.png` (emblema) y `logo_full.png` (completo),
///    generados con `branding/generate_app_assets.py`. El dueño puede
///    reemplazarlo desde la app de administración.
///  * Tipografías: PLACEHOLDER. Colocar los .ttf/.otf en `assets/fonts/`,
///    descomentar el bloque `fonts:` de pubspec.yaml y completar
///    [displayFont] / [bodyFont].
class Brand {
  // --- Colores de RF8 -------------------------------------------------------------
  static const orange = Color(0xFFEE6E31); // naranja del logo
  static const navy = Color(0xFF101A33); // azul marino del logo

  static const primary = orange;
  static const onPrimary = Colors.white;
  static const background = navy;
  static const surface = Color(0xFF18233F);
  static const surfaceHigh = Color(0xFF22305A);
  static const outline = Color(0xFF2E3D66);
  static const textPrimary = Color(0xFFF5F6FA);
  static const textSecondary = Color(0xFF9AA4BF);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF5C33B);

  // --- Tipografías ------------------------------------------------------------
  /// Tipografía de títulos (ej. 'RF8 Display'). null = fuente del sistema.
  static const String? displayFont = null; // PLACEHOLDER
  /// Tipografía de textos (ej. 'RF8 Text'). null = fuente del sistema.
  static const String? bodyFont = null; // PLACEHOLDER

  // --- Logo ---------------------------------------------------------------------
  static const logoAsset = 'assets/branding/logo.png';
  static const logoFullAsset = 'assets/branding/logo_full.png';
}
