import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/member_controller.dart';
import '../../widgets/common.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = context.read<MemberController>().profile;
    _name = TextEditingController(text: p?.fullName);
    _phone = TextEditingController(text: p?.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final member = context.read<MemberController>();
    final ok = await runGuarded(
      context,
      () => member.updateProfile(
        fullName: _name.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      showMessage(context, 'Datos guardados');
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MemberController>().profile;
    return Scaffold(
      appBar: AppBar(title: const Text('Datos personales')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Ingresá tu nombre completo' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Teléfono (opcional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: '@${p?.username ?? ''}',
              enabled: false,
              decoration: const InputDecoration(labelText: 'Usuario'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              initialValue: p?.email,
              enabled: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                helperText: 'Para cambiar tu email o usuario consultá en recepción',
              ),
            ),
            const SizedBox(height: 24),
            LoadingButton(label: 'Guardar', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
