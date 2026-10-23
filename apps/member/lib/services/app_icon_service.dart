import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Ícono alternativo de la app (estilo Discord Nitro).
///
/// Para agregar uno nuevo:
///  1. Agregar la variante acá.
///  2. Android: `<activity-alias android:name=".Icon<Id>">` en AndroidManifest.xml
///     y los mipmaps `ic_launcher_<id>`.
///  3. iOS: un `AppIcon-<Id>.appiconset` en Assets.xcassets y su nombre en
///     ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES (project.pbxproj).
class AppIconVariant {
  const AppIconVariant({
    required this.id,
    required this.label,
    required this.description,
    this.iosName,
  });

  /// Identificador usado por Android (sufijo del activity-alias).
  final String id;
  final String label;
  final String description;

  /// Nombre del ícono alternativo en iOS; null = ícono principal.
  final String? iosName;

  String get previewAsset => 'assets/app_icons/${id.toLowerCase()}.png';

  static const all = [
    AppIconVariant(id: 'Default', label: 'Clásico', description: 'El original de RF8'),
    AppIconVariant(id: 'Night', label: 'Noche', description: 'Negro total', iosName: 'AppIcon-Night'),
    AppIconVariant(id: 'Gold', label: 'Oro', description: 'Para los de siempre', iosName: 'AppIcon-Gold'),
    AppIconVariant(id: 'Neon', label: 'Neón', description: 'Modo cardio', iosName: 'AppIcon-Neon'),
    AppIconVariant(id: 'Light', label: 'Blanco', description: 'Minimalista', iosName: 'AppIcon-Light'),
    AppIconVariant(id: 'Fire', label: 'Fuego', description: 'Día de piernas', iosName: 'AppIcon-Fire'),
  ];

  static AppIconVariant byId(String? id) =>
      all.firstWhere((v) => v.id == id, orElse: () => all.first);
}

class AppIconService {
  static const _channel = MethodChannel('ar.rf8.app/app_icon');

  bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<AppIconVariant> current() async {
    if (!isSupported) return AppIconVariant.all.first;
    try {
      return AppIconVariant.byId(await _channel.invokeMethod<String>('getIcon'));
    } on PlatformException {
      return AppIconVariant.all.first;
    } on MissingPluginException {
      return AppIconVariant.all.first;
    }
  }

  Future<void> set(AppIconVariant variant) async {
    if (!isSupported) throw UnsupportedError('Cambiar el ícono no está disponible en esta plataforma');
    await _channel.invokeMethod<void>('setIcon', {'id': variant.id, 'iosName': variant.iosName});
  }
}
