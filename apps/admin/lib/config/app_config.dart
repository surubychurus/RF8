/// Configuración de entorno. Se puede pisar al compilar:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
///
/// La publishable key es pública por diseño (los permisos los da RLS).
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pnamtuhhettqgkfugzik.supabase.co',
  );
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY', defaultValue: _defaultKey);

  static const _defaultKey = 'sb_publishable_3-satDb7Co-YxlTscEPNgQ_ht_F19lE';

  /// Bucket de Storage con las imágenes de la app.
  static const mediaBucket = 'media';

  /// Código de país para armar links de WhatsApp si el número no lo tiene.
  static const defaultCountryCode = '54'; // Argentina
}
