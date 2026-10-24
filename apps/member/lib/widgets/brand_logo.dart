import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/branding_controller.dart';
import '../theme/brand.dart';

/// Logo de RF8. Prioridad: logo subido por el dueño (app de administración) →
/// logo de la app (`assets/branding/`) → placeholder con las letras "RF8".
class BrandLogo extends StatelessWidget {
  /// Emblema cuadrado.
  const BrandLogo({super.key, this.size = 96}) : full = false;

  /// Logo completo (emblema + RF8 + "Centro Integral de Entrenamiento"); [size] es el ancho.
  const BrandLogo.full({super.key, this.size = 280}) : full = true;

  final double size;
  final bool full;

  @override
  Widget build(BuildContext context) {
    final remote = context.watch<BrandingController?>()?.value.logoUrl;
    final local = Image.asset(
      full ? Brand.logoFullAsset : Brand.logoAsset,
      fit: BoxFit.contain,
      errorBuilder: (_, _, _) => _Placeholder(size: full ? size * 0.4 : size),
    );
    return SizedBox(
      width: size,
      height: full ? size * 0.44 : size,
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
