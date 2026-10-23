import 'dart:async';

import 'package:flutter/foundation.dart';

import 'admin_api.dart';
import 'models.dart';

enum SessionState { loading, signedOut, ready }

/// Sesión del staff. Sólo deja entrar a usuarios con rol gym u owner.
class AdminSession extends ChangeNotifier {
  AdminSession(this.api);

  final AdminApi api;

  SessionState state = SessionState.loading;
  Member? me;
  StreamSubscription<dynamic>? _sub;

  Role get role => me?.role ?? Role.member;
  bool get isOwner => role == Role.owner;

  Future<void> init() async {
    _sub = api.auth.onAuthStateChange.listen((s) {
      if (api.userId == null && state != SessionState.signedOut) {
        me = null;
        state = SessionState.signedOut;
        notifyListeners();
      }
    });
    if (api.userId == null) {
      state = SessionState.signedOut;
    } else {
      try {
        await _loadMe();
      } on AppException {
        state = SessionState.signedOut;
      }
    }
    notifyListeners();
  }

  Future<void> signIn(String login, String password) async {
    await api.signIn(login, password);
    await _loadMe();
    notifyListeners();
  }

  Future<void> _loadMe() async {
    final m = await api.me();
    if (m.role == Role.member || !m.active) {
      await api.signOut();
      me = null;
      state = SessionState.signedOut;
      throw const AppException('Esta cuenta no tiene acceso a la administración');
    }
    me = m;
    state = SessionState.ready;
  }

  Future<void> signOut() async {
    await api.signOut();
    me = null;
    state = SessionState.signedOut;
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
