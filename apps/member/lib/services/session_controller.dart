import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config/gym_config.dart';
import '../data/gym_repository.dart';
import 'local_security.dart';

enum SessionStage {
  /// Arrancando.
  loading,

  /// Sin sesión: login con usuario y clave (o crear usuario por invitación).
  signedOut,

  /// Primera vez en el dispositivo: biometría + PIN de 6 dígitos.
  setupSecurity,

  /// Sesión guardada pero bloqueada: biometría o PIN.
  locked,

  /// Adentro.
  unlocked,
}

class SessionController extends ChangeNotifier with WidgetsBindingObserver {
  SessionController({required this.repo, required this.security});

  final GymRepository repo;
  final LocalSecurity security;

  SessionStage _stage = SessionStage.loading;
  SessionStage get stage => _stage;

  /// Token de invitación recibido por deep link, pendiente de usar.
  String? _pendingInvite;
  String? get pendingInvite => _pendingInvite;

  bool _unlocked = false;
  bool _authPromptOpen = false;
  DateTime? _backgroundedAt;
  StreamSubscription<void>? _sub;

  String? get userId => repo.currentUserId;

  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);
    _sub = repo.sessionChanges.listen((_) => _evaluate());
    await _evaluate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _evaluate() async {
    final uid = repo.currentUserId;
    SessionStage next;
    if (uid == null) {
      _unlocked = false;
      next = SessionStage.signedOut;
    } else if (!await security.hasPin(uid)) {
      next = SessionStage.setupSecurity;
    } else {
      next = _unlocked ? SessionStage.unlocked : SessionStage.locked;
    }
    if (next != _stage) {
      _stage = next;
      notifyListeners();
    }
  }

  // --- Invitaciones -----------------------------------------------------------

  void receiveInvite(String token) {
    _pendingInvite = token;
    notifyListeners();
  }

  void clearInvite() {
    _pendingInvite = null;
    notifyListeners();
  }

  // --- Login ------------------------------------------------------------------

  /// Login con usuario y clave. Al ser una autenticación fuerte, no pide PIN.
  Future<void> signIn(String user, String password) async {
    await repo.signIn(user, password);
    _unlocked = true;
    await _evaluate();
  }

  Future<void> acceptInvite({
    required String token,
    required String username,
    required String password,
    String? email,
  }) async {
    await repo.acceptInvite(token: token, username: username, password: password, email: email);
    _pendingInvite = null;
    _unlocked = true;
    await _evaluate();
  }

  Future<void> signOut({bool forgetDevice = false}) async {
    final uid = userId;
    if (forgetDevice && uid != null) await security.clear(uid);
    _unlocked = false;
    await repo.signOut();
    await _evaluate();
  }

  // --- Seguridad local --------------------------------------------------------

  Future<void> completeSecuritySetup({required String pin, required bool biometrics}) async {
    final uid = userId!;
    await security.setPin(uid, pin);
    await security.setBiometricsEnabled(uid, biometrics);
    _unlocked = true;
    await _evaluate();
  }

  Future<bool> biometricsEnabled() async {
    final uid = userId;
    return uid != null && await security.biometricsEnabled(uid);
  }

  Future<bool> unlockWithBiometrics() async {
    final ok = await runAuthPrompt(() => security.authenticate('Ingresá a RF8'));
    if (ok) {
      await security.resetFailedAttempts(userId!);
      _unlock();
    }
    return ok;
  }

  /// Devuelve los intentos restantes (0 = se cerró la sesión) o null si el PIN es correcto.
  Future<int?> unlockWithPin(String pin) async {
    final uid = userId!;
    if (await security.verifyPin(uid, pin)) {
      _unlock();
      return null;
    }
    final left = GymConfig.maxPinAttempts - await security.failedAttempts(uid);
    if (left <= 0) await signOut(forgetDevice: true);
    return left.clamp(0, GymConfig.maxPinAttempts);
  }

  /// Ejecuta un diálogo del sistema (biometría) sin que la app se re-bloquee
  /// por el cambio de ciclo de vida que provoca.
  Future<T> runAuthPrompt<T>(Future<T> Function() prompt) async {
    _authPromptOpen = true;
    try {
      return await prompt();
    } finally {
      _authPromptOpen = false;
      _backgroundedAt = null;
    }
  }

  void _unlock() {
    _unlocked = true;
    _stage = SessionStage.unlocked;
    notifyListeners();
  }

  void lock() {
    if (_stage != SessionStage.unlocked) return;
    _unlocked = false;
    _stage = SessionStage.locked;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_authPromptOpen) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _backgroundedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final since = _backgroundedAt;
        _backgroundedAt = null;
        if (since != null && DateTime.now().difference(since) >= GymConfig.relockAfter) {
          lock();
        }
      default:
        break;
    }
  }
}
