import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/branding_controller.dart';
import '../theme/brand.dart';

/// Logo de RF8. Prioridad: logo subido por el dueño (app de administración) →
/// `assets/branding/logo.png` → placeholder con las letras "RF8".
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<BrandingController?>()?.value.logoUrl;
    final local = Image.asset(
      Brand.logoAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _Placeholder(size: size),
    );
    return SizedBox.square(
      dimension: size,
      child: remote == null
          ? local
          : Image.network(remote, fit: BoxFit.contain, errorBuilder: (_, _, _) => local),
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
