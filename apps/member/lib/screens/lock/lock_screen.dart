import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../services/session_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/pin_pad.dart';

/// Desbloqueo rápido: biometría o PIN de 6 dígitos.
class LockScreen extends StatefulWidget {
  const LockScreen({super.key});

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _bioEnabled = false;
  bool _faceId = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final session = context.read<SessionController>();
    final enabled = await session.biometricsEnabled() && await session.security.biometricsAvailable();
    final types = await session.security.availableBiometrics();
    if (!mounted) return;
    setState(() {
      _bioEnabled = enabled;
      _faceId = types.contains(BiometricType.face);
    });
    if (enabled) _biometric();
  }

  Future<void> _biometric() => context.read<SessionController>().unlockWithBiometrics();

  Future<void> _pin(String pin) async {
    final left = await context.read<SessionController>().unlockWithPin(pin);
    if (!mounted || left == null) return;
    setState(() => _error = left == 1 ? 'PIN incorrecto. Te queda 1 intento' : 'PIN incorrecto. Te quedan $left intentos');
  }

  Future<void> _forgot() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Olvidaste tu PIN?'),
        content: const Text(
          'Vas a tener que ingresar de nuevo con tu usuario y contraseña y crear un PIN nuevo.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Continuar')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<SessionController>().signOut(forgetDevice: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const BrandLogo(size: 72),
                const SizedBox(height: 24),
                Text('Ingresá tu PIN', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 32),
                PinPad(
                  onCompleted: _pin,
                  error: _error,
                  onBiometric: _bioEnabled ? _biometric : null,
                  biometricIcon: _faceId ? Icons.face : Icons.fingerprint,
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _forgot,
                  child: const Text('Olvidé mi PIN', style: TextStyle(color: Brand.textSecondary)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
