/// Configuración de entorno. Se pasa con --dart-define al compilar:
///
///   flutter run \
///     --dart-define=SUPABASE_URL=https://xxxx.supabase.co \
///     --dart-define=SUPABASE_KEY=sb_publishable_...
///
/// Sin esos valores la app arranca en **modo demo** con datos en memoria.
class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  /// Publishable key (o la anon key legacy) del proyecto.
  static const supabaseKey = String.fromEnvironment('SUPABASE_KEY');

  static bool get isDemo => supabaseUrl.isEmpty || supabaseKey.isEmpty;

  /// Esquema propio para deep links (rf8gym://invite?token=...).
  static const deepLinkScheme = 'rf8gym';

  /// Host de los App Links / Universal Links (https://app.rf8.com.ar/invite?token=...).
  /// PLACEHOLDER: reemplazar por el dominio real de RF8.
  static const appLinkHost = 'app.rf8.com.ar';
}
