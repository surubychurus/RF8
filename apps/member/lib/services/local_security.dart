import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Desbloqueo rápido en el dispositivo: biometría (huella / Face ID) o un PIN
/// de 6 dígitos definido por el socio. Todo se guarda cifrado en el
/// Keychain / Keystore y por usuario.
class LocalSecurity {
  LocalSecurity({FlutterSecureStorage? storage, LocalAuthentication? auth})
      : _storage = storage ?? const FlutterSecureStorage(),
        _auth = auth ?? LocalAuthentication();

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  static const pinLength = 6;

  String _k(String userId, String key) => 'rf8.$userId.$key';

  Future<bool> hasPin(String userId) async =>
      await _storage.read(key: _k(userId, 'pin_hash')) != null;

  Future<void> setPin(String userId, String pin) async {
    assert(pin.length == pinLength);
    final salt = _randomSalt();
    await _storage.write(key: _k(userId, 'pin_salt'), value: salt);
    await _storage.write(key: _k(userId, 'pin_hash'), value: _hash(pin, salt));
    await resetFailedAttempts(userId);
  }

  Future<bool> verifyPin(String userId, String pin) async {
    final salt = await _storage.read(key: _k(userId, 'pin_salt'));
    final hash = await _storage.read(key: _k(userId, 'pin_hash'));
    if (salt == null || hash == null) return false;
    final ok = _hash(pin, salt) == hash;
    if (ok) {
      await resetFailedAttempts(userId);
    } else {
      final n = await failedAttempts(userId) + 1;
      await _storage.write(key: _k(userId, 'pin_failed'), value: '$n');
    }
    return ok;
  }

  Future<int> failedAttempts(String userId) async =>
      int.tryParse(await _storage.read(key: _k(userId, 'pin_failed')) ?? '') ?? 0;

  Future<void> resetFailedAttempts(String userId) =>
      _storage.delete(key: _k(userId, 'pin_failed'));

  Future<bool> biometricsEnabled(String userId) async =>
      await _storage.read(key: _k(userId, 'bio')) == '1';

  Future<void> setBiometricsEnabled(String userId, bool enabled) =>
      _storage.write(key: _k(userId, 'bio'), value: enabled ? '1' : '0');

  /// Elimina PIN y preferencias del usuario en este dispositivo.
  Future<void> clear(String userId) async {
    for (final key in ['pin_salt', 'pin_hash', 'pin_failed', 'bio']) {
      await _storage.delete(key: _k(userId, key));
    }
  }

  /// ¿El dispositivo tiene biometría configurada?
  Future<bool> biometricsAvailable() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (!await _auth.canCheckBiometrics) return false;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      // PlatformException, LocalAuthException o plugin no disponible.
      return false;
    }
  }

  Future<List<BiometricType>> availableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } catch (_) {
      return const [];
    }
  }

  /// Muestra el diálogo del sistema. Devuelve true si se autenticó.
  Future<bool> authenticate(String reason) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  static String _randomSalt() {
    final r = Random.secure();
    return base64Url.encode(List.generate(16, (_) => r.nextInt(256)));
  }

  /// PBKDF-like: SHA-256 iterado con sal, suficiente para un PIN local que
  /// además está protegido por el Keychain/Keystore y por límite de intentos.
  static String _hash(String pin, String salt) {
    List<int> digest = utf8.encode('$salt:$pin');
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }
}
