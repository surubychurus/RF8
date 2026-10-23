import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/gym_repository.dart';
import '../../widgets/common.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.read<GymRepository>();
    final ok = await runGuarded(
      context,
      () => repo.changePassword(currentPassword: _current.text, newPassword: _new.text),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showMessage(context, 'Contraseña actualizada');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cambiar contraseña')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              validator: (v) => (v ?? '').isEmpty ? 'Ingresá tu contraseña actual' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _new,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Nueva contraseña', helperText: 'Mínimo 8 caracteres'),
              validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Repetí la nueva contraseña'),
              validator: (v) => v != _new.text ? 'Las contraseñas no coinciden' : null,
            ),
            const SizedBox(height: 24),
            LoadingButton(label: 'Guardar', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
