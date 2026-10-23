/// Reglas del gimnasio que la app usa para mostrar información.
/// La validación real se hace en el servidor (supabase/migrations).
class GymConfig {
  static const gymName = 'RF8 Gimnasio';
  static const instagram = '@rf8.gimnasio';

  static const slotCapacity = 15;
  static const slotDuration = Duration(hours: 1, minutes: 30);

  /// Cuántos días hacia adelante se puede reservar.
  static const bookingWindowDays = 7;

  /// Bloques horarios (sólo informativo, la grilla real viene de `time_slots`).
  static const openingBlocks = ['08:00 – 12:30', '13:30 – 16:30', '17:00 – 21:00'];

  /// Símbolo de moneda para los precios.
  static const currencySymbol = r'$';

  /// Tiempo en segundo plano tras el cual la app pide biometría/PIN otra vez.
  static const relockAfter = Duration(minutes: 1);

  /// Intentos de PIN antes de cerrar la sesión.
  static const maxPinAttempts = 5;
}
