import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/session_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/pin_pad.dart';

class ChangePinScreen extends StatefulWidget {
  const ChangePinScreen({super.key});

  @override
  State<ChangePinScreen> createState() => _ChangePinScreenState();
}

enum _Step { current, next, confirm }

class _ChangePinScreenState extends State<ChangePinScreen> {
  _Step _step = _Step.current;
  String? _newPin;
  String? _error;

  Future<void> _onPin(String pin) async {
    final session = context.read<SessionController>();
    final uid = session.userId!;
    switch (_step) {
      case _Step.current:
        if (await session.security.verifyPin(uid, pin)) {
          setState(() {
            _step = _Step.next;
            _error = null;
          });
        } else {
          setState(() => _error = 'PIN incorrecto');
        }
      case _Step.next:
        setState(() {
          _newPin = pin;
          _step = _Step.confirm;
          _error = null;
        });
      case _Step.confirm:
        if (pin != _newPin) {
          setState(() {
            _step = _Step.next;
            _error = 'Los PIN no coinciden, empezá de nuevo';
          });
          return;
        }
        await session.security.setPin(uid, pin);
        if (!mounted) return;
        showMessage(context, 'PIN actualizado');
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.current => 'Ingresá tu PIN actual',
      _Step.next => 'Elegí tu nuevo PIN',
      _Step.confirm => 'Repetí tu nuevo PIN',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar PIN')),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text('6 dígitos', style: TextStyle(color: Brand.textSecondary)),
              const SizedBox(height: 32),
              PinPad(key: ValueKey(_step), onCompleted: _onPin, error: _error),
            ],
          ),
        ),
      ),
    );
  }
}
