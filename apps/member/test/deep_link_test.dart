import 'package:flutter_test/flutter_test.dart';
import 'package:rf8_app/services/deep_link_service.dart';

void main() {
  test('extrae el token de los links de invitación', () {
    expect(DeepLinkService.inviteTokenFrom(Uri.parse('rf8gym://invite?token=abc')), 'abc');
    expect(DeepLinkService.inviteTokenFrom(Uri.parse('https://app.rf8.com.ar/invite?token=xyz')), 'xyz');
  });

  test('ignora otros links', () {
    expect(DeepLinkService.inviteTokenFrom(Uri.parse('https://otro.com/invite?token=abc')), isNull);
    expect(DeepLinkService.inviteTokenFrom(Uri.parse('rf8gym://otra-cosa?token=abc')), isNull);
    expect(DeepLinkService.inviteTokenFrom(Uri.parse('rf8gym://invite')), isNull);
    expect(DeepLinkService.inviteTokenFrom(null), isNull);
  });
}
