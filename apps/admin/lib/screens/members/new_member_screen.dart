import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/invite_code_sheet.dart';

/// Alta de socio: se le envía un mail (Resend) para que cree su usuario y clave.
class NewMemberScreen extends StatefulWidget {
  const NewMemberScreen({super.key});

  @override
  State<NewMemberScreen> createState() => _NewMemberScreenState();
}

class _NewMemberScreenState extends State<NewMemberScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  late final Future<List<Plan>> _plans = context.read<AdminApi>().plans(onlyActive: true);
  String? _planId;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final api = context.read<AdminApi>();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    InviteCode? invite;
    await runGuarded(context, () async {
      invite = await api.inviteMember(
        fullName: _name.text.trim(),
        email: opt(_email),
        phone: opt(_phone),
        planId: _planId,
      );
    });
    if (!mounted) return;
    setState(() => _saving = false);
    final created = invite;
    if (created == null) return;
    await showInviteCode(context, invite: created, fullName: _name.text.trim(), phone: opt(_phone));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo socio')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Se genera un código de invitación para que cree su usuario y contraseña en la app '
              'de socios. Se lo podés mandar por WhatsApp o copiarlo.',
              style: TextStyle(color: Brand.textSecondary),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo'),
              validator: (v) => (v ?? '').trim().length < 3 ? 'Ingresá el nombre completo' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email (opcional)',
                helperText: 'Si lo dejás vacío, el socio lo completa al crear su usuario',
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return null;
                return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(t) ? null : 'Email inválido';
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'WhatsApp',
                helperText: 'Ej: 099 123 456 o +598 99 123 456',
                prefixIcon: Icon(Icons.chat_outlined),
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Plan>>(
              future: _plans,
              builder: (context, snap) => DropdownButtonFormField<String?>(
                initialValue: _planId,
                decoration: const InputDecoration(labelText: 'Plan (opcional)'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('Sin plan por ahora')),
                  for (final p in snap.data ?? const <Plan>[]) DropdownMenuItem(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _planId = v),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Si elegís un plan, arranca el día que el socio cree su usuario y dura un mes.',
                style: TextStyle(color: Brand.textSecondary, fontSize: 12)),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.key),
              label: Text(_saving ? 'Generando…' : 'Generar código de invitación'),
            ),
          ],
        ),
      ),
    );
  }
}
