import 'dart:convert';

import 'package:crypto/crypto.dart';

/// QR dinámico de entrada. Cambia cada [period] para que una captura de
/// pantalla no sirva más tarde. El servidor lo valida en `public.check_in`.
///
/// Formato: `RF8|1|{booking_id}|{step}|{code}`
///   step = floor(epoch_segundos / 30)
///   code = primeros 16 hex de HMAC-SHA256(key: qrSecret, msg: "{booking_id}:{step}")
class QrToken {
  static const period = Duration(seconds: 30);

  static int stepAt(DateTime t) => t.millisecondsSinceEpoch ~/ period.inMilliseconds;

  static String payload({required String bookingId, required String qrSecret, DateTime? at}) {
    final step = stepAt(at ?? DateTime.now());
    final mac = Hmac(sha256, utf8.encode(qrSecret)).convert(utf8.encode('$bookingId:$step'));
    final code = mac.toString().substring(0, 16);
    return 'RF8|1|$bookingId|$step|$code';
  }

  /// Tiempo que falta para que cambie el código.
  static Duration remaining([DateTime? now]) {
    final ms = (now ?? DateTime.now()).millisecondsSinceEpoch % period.inMilliseconds;
    return Duration(milliseconds: period.inMilliseconds - ms);
  }
}
