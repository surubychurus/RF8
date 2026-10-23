import 'dart:async';

import 'package:app_links/app_links.dart';

import '../config/app_config.dart';

/// Escucha los links de invitación:
///  * https://app.rf8.com.ar/invite?token=XXXX  (App Links / Universal Links)
///  * rf8gym://invite?token=XXXX               (esquema propio)
class DeepLinkService {
  DeepLinkService() : _links = AppLinks();

  final AppLinks _links;
  StreamSubscription<Uri>? _sub;

  Future<void> start(void Function(String token) onInvite) async {
    void handle(Uri? uri) {
      final token = inviteTokenFrom(uri);
      if (token != null) onInvite(token);
    }

    try {
      handle(await _links.getInitialLink());
      _sub = _links.uriLinkStream.listen(handle, onError: (_) {});
    } catch (_) {
      // Plataforma sin soporte de deep links (tests, desktop): se ignora.
    }
  }

  void dispose() => _sub?.cancel();

  static String? inviteTokenFrom(Uri? uri) {
    if (uri == null) return null;
    final isScheme = uri.scheme == AppConfig.deepLinkScheme && uri.host == 'invite';
    final isHttps = uri.scheme == 'https' &&
        uri.host == AppConfig.appLinkHost &&
        uri.path.startsWith('/invite');
    if (!isScheme && !isHttps) return null;
    final token = uri.queryParameters['token'];
    return (token == null || token.isEmpty) ? null : token;
  }
}
