import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// Logo de RF8. Mientras no exista `assets/branding/logo.png` muestra un
/// placeholder con las letras "RF8".
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        Brand.logoAsset,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _Placeholder(size: size),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Brand.surface,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(color: Brand.primary, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        'RF8',
        style: TextStyle(
          fontFamily: Brand.displayFont,
          fontSize: size * 0.32,
          fontWeight: FontWeight.w900,
          letterSpacing: size * 0.02,
          color: Brand.textPrimary,
        ),
      ),
    );
  }
}
