import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/media_picker.dart';

/// Logo de la app de socios y sus íconos (estilo Discord Nitro).
class BrandingScreen extends StatefulWidget {
  const BrandingScreen({super.key});

  @override
  State<BrandingScreen> createState() => _BrandingScreenState();
}

class _BrandingScreenState extends State<BrandingScreen> {
  // Deben coincidir con AppIconVariant.all de la app de socios.
  static const variants = {
    'Default': 'Clásico',
    'Night': 'Noche',
    'Gold': 'Oro',
    'Neon': 'Neón',
    'Light': 'Blanco',
    'Fire': 'Fuego',
  };

  Future<Map<String, dynamic>>? _settings;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _settings = context.read<AdminApi>().settings());

  Future<void> _save(String key, Object? value, String success) async {
    final api = context.read<AdminApi>();
    if (await runGuarded(context, () => api.setSetting(key, value), success: success)) _load();
  }

  Future<void> _changeLogo() async {
    final url = await pickMediaUrl(context, folder: 'logos', square: true, maxSize: 1024, png: true);
    if (url != null) await _save('logo_url', url, 'Logo actualizado');
  }

  Future<void> _changeIcon(Map<String, dynamic> icons, String id) async {
    final url = await pickMediaUrl(context, folder: 'icons', square: true, maxSize: 1024, png: true);
    if (url != null) await _save('app_icons', {...icons, id: url}, 'Ícono actualizado');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logo e íconos')),
      body: AsyncView(
        future: _settings,
        onRetry: _load,
        builder: (context, s) {
          final logo = s['logo_url'] as String?;
          final icons = Map<String, dynamic>.from((s['app_icons'] as Map?) ?? const {});
          final enabled = List<String>.from((s['enabled_icons'] as List?) ?? variants.keys);
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              const SectionTitle('Logo'),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _Thumb(url: logo, fallback: 'RF8', size: 88),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Se muestra en el login y en la app de socios.',
                                style: TextStyle(color: Brand.textSecondary)),
                            const SizedBox(height: 8),
                            Wrap(spacing: 8, children: [
                              FilledButton(onPressed: _changeLogo, child: const Text('Cambiar')),
                              if (logo != null)
                                TextButton(
                                  onPressed: () => _save('logo_url', null, 'Logo restablecido'),
                                  child: const Text('Quitar'),
                                ),
                            ]),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SectionTitle('Íconos de la app'),
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 12),
                child: Text(
                  'Los socios eligen entre los íconos habilitados en Mi cuenta. La imagen nueva se ve '
                  'enseguida en el selector; el ícono del teléfono se actualiza con la próxima versión '
                  'de la app (GitHub Actions toma estas imágenes al compilar).',
                  style: TextStyle(color: Brand.textSecondary, fontSize: 13),
                ),
              ),
              for (final e in variants.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      leading: _Thumb(url: icons[e.key] as String?, fallback: e.value[0], size: 52),
                      title: Text(e.value),
                      subtitle: Text(icons[e.key] == null ? 'Imagen original' : 'Imagen personalizada'),
                      onTap: () => _changeIcon(icons, e.key),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (icons[e.key] != null)
                            IconButton(
                              tooltip: 'Volver a la original',
                              icon: const Icon(Icons.restart_alt),
                              onPressed: () => _save('app_icons', {...icons, e.key: null}, 'Ícono restablecido'),
                            ),
                          Switch(
                            value: enabled.contains(e.key),
                            onChanged: e.key == 'Default'
                                ? null // el clásico siempre disponible
                                : (v) => _save(
                                      'enabled_icons',
                                      v ? [...enabled, e.key] : enabled.where((x) => x != e.key).toList(),
                                      v ? 'Ícono habilitado' : 'Ícono deshabilitado',
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.url, required this.fallback, required this.size});

  final String? url;
  final String fallback;
  final double size;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Brand.surfaceHigh,
      alignment: Alignment.center,
      child: Text(fallback, style: TextStyle(fontWeight: FontWeight.w900, fontSize: size * 0.3)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child: url == null
            ? placeholder
            : Image.network(url!, fit: BoxFit.cover, errorBuilder: (_, _, _) => placeholder),
      ),
    );
  }
}
