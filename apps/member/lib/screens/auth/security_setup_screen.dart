import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../../services/session_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/pin_pad.dart';

/// Primer ingreso en el dispositivo:
///  1. Pide permiso para usar los datos biométricos (huella / Face ID).
///  2. El socio define un PIN de 6 dígitos (respaldo si la biometría falla).
class SecuritySetupScreen extends StatefulWidget {
  const SecuritySetupScreen({super.key});

  @override
  State<SecuritySetupScreen> createState() => _SecuritySetupScreenState();
}

enum _Step { checking, biometrics, pin, confirmPin }

class _SecuritySetupScreenState extends State<SecuritySetupScreen> {
  _Step _step = _Step.checking;
  bool _biometricsOn = false;
  bool _faceId = false;
  String? _firstPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _detect();
  }

  Future<void> _detect() async {
    final security = context.read<SessionController>().security;
    final available = await security.biometricsAvailable();
    final types = await security.availableBiometrics();
    if (!mounted) return;
    setState(() {
      _faceId = types.contains(BiometricType.face);
      _step = available ? _Step.biometrics : _Step.pin;
    });
  }

  String get _bioName => _faceId ? 'Face ID' : 'huella';

  Future<void> _enableBiometrics() async {
    final session = context.read<SessionController>();
    final ok = await session.runAuthPrompt(
      () => session.security.authenticate('Confirmá para activar el ingreso rápido a RF8'),
    );
    if (!mounted) return;
    if (ok) {
      setState(() {
        _biometricsOn = true;
        _step = _Step.pin;
      });
    } else {
      showMessage(context, 'No se pudo verificar. Podés intentarlo de nuevo o seguir sin $_bioName.');
    }
  }

  Future<void> _onPin(String pin) async {
    if (_step == _Step.pin) {
      setState(() {
        _firstPin = pin;
        _error = null;
        _step = _Step.confirmPin;
      });
      return;
    }
    if (pin != _firstPin) {
      setState(() {
        _error = 'Los PIN no coinciden, empezá de nuevo';
        _firstPin = null;
        _step = _Step.pin;
      });
      return;
    }
    await context.read<SessionController>().completeSecuritySetup(pin: pin, biometrics: _biometricsOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: switch (_step) {
                _Step.checking => const CircularProgressIndicator(),
                _Step.biometrics => _biometricsStep(),
                _Step.pin || _Step.confirmPin => _pinStep(),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _biometricsStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Brand.primary.withValues(alpha: 0.12),
              ),
              child: Icon(_faceId ? Icons.face : Icons.fingerprint, size: 64, color: Brand.primary),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ingreso rápido con $_bioName',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          const Text(
            'RF8 quiere usar tus datos biométricos para que entres a la app sin escribir tu contraseña. '
            'Tus datos biométricos nunca salen del teléfono.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.textSecondary),
          ),
          const SizedBox(height: 32),
          FilledButton(onPressed: _enableBiometrics, child: Text('Permitir $_bioName')),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => setState(() => _step = _Step.pin),
            child: const Text('Ahora no, usar sólo PIN'),
          ),
        ],
      );

  Widget _pinStep() {
    final confirming = _step == _Step.confirmPin;
    return Column(
      children: [
        Text(
          confirming ? 'Repetí tu PIN' : 'Creá tu PIN de 6 dígitos',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          _biometricsOn
              ? 'Lo vas a usar si la $_bioName no funciona.'
              : 'Lo vas a usar para entrar rápido a la app.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Brand.textSecondary),
        ),
        const SizedBox(height: 32),
        PinPad(key: ValueKey(_step), onCompleted: _onPin, error: _error),
      ],
    );
  }
}
