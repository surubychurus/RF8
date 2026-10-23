/// Configuración de entorno.
///
/// Por defecto la app se conecta al backend de RF8 en Supabase
/// (proyecto archivo-natacion). Se puede pisar al compilar:
///
///   flutter run --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_KEY=...
///
/// Modo demo (datos en memoria, sin backend):
///
///   flutter run --dart-define=DEMO=true
class AppConfig {
  static const supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://pnamtuhhettqgkfugzik.supabase.co',
  );

  /// Publishable key del proyecto. Es pública por diseño (los permisos los da RLS).
  static const supabaseKey = String.fromEnvironment(
    'SUPABASE_KEY',
    defaultValue: 'sb_publishable_3-satDb7Co-YxlTscEPNgQ_ht_F19lE',
  );

  static const _demo = bool.fromEnvironment('DEMO');

  static bool get isDemo => _demo || supabaseUrl.isEmpty || supabaseKey.isEmpty;

  /// Esquema propio para deep links (rf8gym://invite?token=...).
  static const deepLinkScheme = 'rf8gym';

  /// Host de los App Links / Universal Links (https://app.rf8.com.ar/invite?token=...).
  /// PLACEHOLDER: reemplazar por el dominio real de RF8.
  static const appLinkHost = 'app.rf8.com.ar';
}
