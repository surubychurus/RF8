import 'package:flutter_test/flutter_test.dart';
import 'package:rf8_app/services/qr_token.dart';

void main() {
  test('genera el payload con el mismo HMAC que valida public.check_in', () {
    // step 57000000 * 30 s
    final at = DateTime.fromMillisecondsSinceEpoch(57000000 * 30 * 1000);
    final payload = QrToken.payload(bookingId: 'b-123', qrSecret: 'secreto-de-prueba', at: at);
    // Vector calculado con: hmac.new(b'secreto-de-prueba', b'b-123:57000000', sha256).hexdigest()[:16]
    expect(payload, 'RF8|1|b-123|57000000|848bde8a15b11c74');
  });

  test('el código cambia cada 30 segundos', () {
    final t = DateTime.fromMillisecondsSinceEpoch(57000000 * 30 * 1000);
    final a = QrToken.payload(bookingId: 'b', qrSecret: 's', at: t);
    final b = QrToken.payload(bookingId: 'b', qrSecret: 's', at: t.add(const Duration(seconds: 29)));
    final c = QrToken.payload(bookingId: 'b', qrSecret: 's', at: t.add(const Duration(seconds: 30)));
    expect(a, b);
    expect(a, isNot(c));
  });
}
