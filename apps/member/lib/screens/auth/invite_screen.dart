import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/gym_repository.dart';
import '../../models/models.dart';
import '../../services/session_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/brand_logo.dart';
import '../../widgets/common.dart';

/// Crear usuario a partir del link/código recibido por correo.
class InviteScreen extends StatefulWidget {
  const InviteScreen({super.key, this.token});

  /// Token del deep link. Si es null se pide el código a mano.
  final String? token;

  @override
  State<InviteScreen> createState() => _InviteScreenState();
}

class _InviteScreenState extends State<InviteScreen> {
  final _code = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  String? _token;
  InviteInfo? _invite;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.token != null) {
      _code.text = widget.token!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    }
  }

  @override
  void dispose() {
    for (final c in [_code, _user, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _check() async {
    final token = _code.text.trim();
    if (token.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await context.read<GymRepository>().getInvite(token);
      setState(() {
        _token = token;
        _invite = info;
      });
    } on AppException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _create() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    final session = context.read<SessionController>();
    final nav = Navigator.of(context);
    try {
      await session.acceptInvite(token: _token!, username: _user.text, password: _pass.text);
      // La raíz pasa a "configurar seguridad": cerramos esta pantalla.
      nav.popUntil((r) => r.isFirst);
    } on AppException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final invite = _invite;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            context.read<SessionController>().clearInvite();
            Navigator.of(context).maybePop();
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: invite == null ? _codeStep() : _accountStep(invite),
            ),
          ),
        ),
      ),
    );
  }

  Widget _codeStep() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Center(child: BrandLogo(size: 80)),
          const SizedBox(height: 24),
          Text('Activá tu cuenta', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          const Text(
            'Abrí el link del correo que te enviamos desde RF8, o pegá acá el código que figura en el mail.',
            style: TextStyle(color: Brand.textSecondary),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _code,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Código de invitación',
              prefixIcon: Icon(Icons.key_outlined),
            ),
            onSubmitted: (_) => _check(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 24),
          LoadingButton(label: 'Continuar', loading: _loading, onPressed: _check),
        ],
      );

  Widget _accountStep(InviteInfo invite) => Form(
        key: _form,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Hola, ${invite.fullName.split(' ').first} 👋',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Creá tu usuario y contraseña para ${invite.email}',
              style: const TextStyle(color: Brand.textSecondary),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _user,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newUsername],
              decoration: const InputDecoration(
                labelText: 'Usuario',
                helperText: 'Letras, números, punto o guion bajo (3 a 20)',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: (v) => RegExp(r'^[a-z0-9._]{3,20}$').hasMatch((v ?? '').trim().toLowerCase())
                  ? null
                  : 'Usuario inválido',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pass,
              obscureText: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: const InputDecoration(
                labelText: 'Contraseña',
                helperText: 'Mínimo 8 caracteres',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => (v ?? '').length < 8 ? 'Mínimo 8 caracteres' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _pass2,
              obscureText: true,
              onFieldSubmitted: (_) => _create(),
              decoration: const InputDecoration(
                labelText: 'Repetí la contraseña',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (v) => v != _pass.text ? 'Las contraseñas no coinciden' : null,
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ],
            const SizedBox(height: 24),
            LoadingButton(label: 'Crear usuario', loading: _loading, onPressed: _create),
          ],
        ),
      );
}
