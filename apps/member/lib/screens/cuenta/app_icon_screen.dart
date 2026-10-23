import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/app_icon_service.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// Elegir el ícono de la app (estilo Discord Nitro).
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  AppIconVariant? _current;
  String? _changing;

  @override
  void initState() {
    super.initState();
    context.read<AppIconService>().current().then((v) {
      if (mounted) setState(() => _current = v);
    });
  }

  Future<void> _select(AppIconVariant v) async {
    if (v.id == _current?.id || _changing != null) return;
    final service = context.read<AppIconService>();
    if (!service.isSupported) {
      showMessage(context, 'Cambiar el ícono sólo está disponible en Android y iOS', error: true);
      return;
    }
    setState(() => _changing = v.id);
    try {
      await service.set(v);
      if (!mounted) return;
      setState(() => _current = v);
      showMessage(context, 'Ícono cambiado a ${v.label}');
    } catch (_) {
      if (mounted) showMessage(context, 'No se pudo cambiar el ícono', error: true);
    } finally {
      if (mounted) setState(() => _changing = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ícono de la app')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF5B0A91), Brand.primary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Personalizá tu RF8',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                      SizedBox(height: 4),
                      Text('Elegí cómo se ve la app en tu pantalla de inicio.',
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppIconVariant.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.78,
            ),
            itemBuilder: (_, i) {
              final v = AppIconVariant.all[i];
              return _IconTile(
                variant: v,
                selected: v.id == _current?.id,
                loading: v.id == _changing,
                onTap: () => _select(v),
              );
            },
          ),
          const SizedBox(height: 24),
          const Text(
            'En algunos teléfonos Android el ícono puede tardar unos segundos en actualizarse '
            'y la app puede cerrarse al aplicarlo.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.variant, required this.selected, required this.loading, required this.onTap});

  final AppIconVariant variant;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(color: selected ? Brand.primary : Colors.transparent, width: 3),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(variant.previewAsset, fit: BoxFit.cover),
                    ),
                  ),
                ),
                if (loading)
                  const Positioned.fill(child: Center(child: CircularProgressIndicator())),
                if (selected)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Brand.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Brand.background, width: 3),
                      ),
                      padding: const EdgeInsets.all(2),
                      child: const Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(variant.label, style: const TextStyle(fontWeight: FontWeight.w700)),
          Text(
            variant.description,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Brand.textSecondary, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
