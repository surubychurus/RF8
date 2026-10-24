import 'package:flutter/material.dart';

/// Colores de la app de administración (los del logo de RF8).
class Brand {
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
  static const danger = Color(0xFFE5484D);
  static const whatsapp = Color(0xFF25D366);

  /// PLACEHOLDER tipografías (ver assets/fonts y pubspec.yaml).
  static const String? displayFont = null;
  static const String? bodyFont = null;

  static const logoAsset = 'assets/branding/logo.png';
  static const logoFullAsset = 'assets/branding/logo_full.png';
}
