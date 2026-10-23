import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../config/gym_config.dart';
import '../../services/app_icon_service.dart';
import '../../services/branding_controller.dart';
import '../../services/member_controller.dart';
import '../../services/session_controller.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/content_widgets.dart';
import 'app_icon_screen.dart';
import 'change_password_screen.dart';
import 'change_pin_screen.dart';
import 'edit_profile_screen.dart';
import 'plans_screen.dart';

/// Sección Mi cuenta: configuración de la app y de la cuenta.
class CuentaScreen extends StatefulWidget {
  const CuentaScreen({super.key});

  @override
  State<CuentaScreen> createState() => _CuentaScreenState();
}

class _CuentaScreenState extends State<CuentaScreen> {
  bool? _bioAvailable;
  bool _bioEnabled = false;
  AppIconVariant _icon = AppIconVariant.all.first;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final session = context.read<SessionController>();
    final icons = context.read<AppIconService>();
    final available = await session.security.biometricsAvailable();
    final enabled = await session.biometricsEnabled();
    final icon = await icons.current();
    if (!mounted) return;
    setState(() {
      _bioAvailable = available;
      _bioEnabled = enabled;
      _icon = icon;
    });
  }

  Future<void> _toggleBiometrics(bool value) async {
    final session = context.read<SessionController>();
    if (value) {
      final ok = await session.runAuthPrompt(
        () => session.security.authenticate('Confirmá para activar el ingreso rápido'),
      );
      if (!ok) return;
    }
    await session.security.setBiometricsEnabled(session.userId!, value);
    if (mounted) setState(() => _bioEnabled = value);
  }

  Future<void> _signOut() async {
    final session = context.read<SessionController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('Vas a tener que ingresar de nuevo con tu usuario y contraseña.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cerrar sesión')),
        ],
      ),
    );
    if (ok == true) await session.signOut();
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();
    final p = member.profile;
    final m = member.membership;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi cuenta'), actions: const [NotificationsButton()]),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          // --- Perfil -------------------------------------------------------
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Brand.primary,
                    child: Text(
                      _initials(p?.fullName ?? ''),
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(p?.fullName ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('@${p?.username ?? ''}', style: const TextStyle(color: Brand.textSecondary)),
                        Text(p?.email ?? '', style: const TextStyle(color: Brand.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // --- Plan ---------------------------------------------------------
          const SectionTitle('Mi plan'),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined, color: Brand.primary),
                  title: Text(m?.plan.name ?? 'Sin plan activo'),
                  subtitle: Text(
                    m == null
                        ? 'Consultá en recepción'
                        : 'Mensual · ${DateFormat('dd/MM/yyyy').format(m.startsOn)} al ${DateFormat('dd/MM/yyyy').format(m.endsOn)}',
                  ),
                ),
                const Divider(),
                _Tile(
                  icon: Icons.sell_outlined,
                  title: 'Planes y precios',
                  onTap: () => _push(const PlansScreen()),
                ),
              ],
            ),
          ),

          // --- App ----------------------------------------------------------
          const SectionTitle('App'),
          Card(
            child: _Tile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: _iconPreview(context, _icon, 32),
              ),
              title: 'Ícono de la app',
              subtitle: _icon.label,
              onTap: () async {
                await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AppIconScreen()));
                _loadSettings();
              },
            ),
          ),

          // --- Seguridad ----------------------------------------------------
          const SectionTitle('Seguridad'),
          Card(
            child: Column(
              children: [
                if (_bioAvailable == true) ...[
                  SwitchListTile(
                    secondary: const Icon(Icons.fingerprint),
                    title: const Text('Ingreso con biometría'),
                    subtitle: const Text('Huella o Face ID'),
                    value: _bioEnabled,
                    onChanged: _toggleBiometrics,
                  ),
                  const Divider(),
                ],
                _Tile(icon: Icons.pin_outlined, title: 'Cambiar PIN', onTap: () => _push(const ChangePinScreen())),
                const Divider(),
                _Tile(
                  icon: Icons.password,
                  title: 'Cambiar contraseña',
                  onTap: () => _push(const ChangePasswordScreen()),
                ),
                const Divider(),
                _Tile(
                  icon: Icons.lock_clock_outlined,
                  title: 'Bloquear ahora',
                  onTap: () => context.read<SessionController>().lock(),
                ),
              ],
            ),
          ),

          // --- Enlaces (los carga el dueño) ------------------------------------
          if (member.links.isNotEmpty) ...[
            const SectionTitle('Enlaces'),
            Card(
              child: Column(
                children: [
                  for (final (i, l) in member.links.indexed) ...[
                    if (i > 0) const Divider(),
                    ListTile(
                      leading: Icon(l.iconData),
                      title: Text(l.label),
                      trailing: const Icon(Icons.open_in_new, size: 18, color: Brand.textSecondary),
                      onTap: () => openLink(context, l.url),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // --- Cuenta -------------------------------------------------------
          const SectionTitle('Cuenta'),
          Card(
            child: Column(
              children: [
                _Tile(
                  icon: Icons.person_outline,
                  title: 'Datos personales',
                  onTap: () => _push(const EditProfileScreen()),
                ),
                const Divider(),
                _Tile(
                  icon: Icons.logout,
                  title: 'Cerrar sesión',
                  color: Theme.of(context).colorScheme.error,
                  onTap: _signOut,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            '${GymConfig.gymName} · ${GymConfig.instagram}',
            textAlign: TextAlign.center,
            style: TextStyle(color: Brand.textSecondary, fontSize: 12),
          ),
        ],
      ),
    );
  }

  static Widget _iconPreview(BuildContext context, AppIconVariant v, double size) {
    final remote = context.watch<BrandingController>().value.iconUrls[v.id];
    final local = Image.asset(v.previewAsset, width: size, height: size);
    return remote == null
        ? local
        : Image.network(remote, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, _, _) => local);
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

class _Tile extends StatelessWidget {
  const _Tile({this.icon, this.leading, required this.title, this.subtitle, this.onTap, this.color});

  final IconData? icon;
  final Widget? leading;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: leading ?? Icon(icon, color: color),
        title: Text(title, style: TextStyle(color: color)),
        subtitle: subtitle == null ? null : Text(subtitle!),
        trailing: const Icon(Icons.chevron_right, color: Brand.textSecondary),
        onTap: onTap,
      );
}
