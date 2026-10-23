import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/session.dart';
import '../theme/brand.dart';
import '../widgets/common.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    final me = session.me!;
    return Scaffold(
      appBar: AppBar(title: const Text('Cuenta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: Avatar(me.fullName, radius: 26),
              title: Text(me.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text('@${me.username} · ${me.email}'),
              trailing: Tag(me.role.label, color: session.isOwner ? Brand.warning : Brand.primary),
            ),
          ),
          const SectionTitle('Permisos'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                session.isOwner
                    ? 'Dueño: acceso total. Validación de turnos, socios, contenido de la app '
                        '(imágenes, logo, íconos, banner, enlaces), precios, notificaciones globales, '
                        'equipo y eliminación de usuarios.'
                    : 'Gym: validación de turnos y gestión de socios (alta, planes, notificaciones '
                        'y WhatsApp).',
                style: const TextStyle(color: Brand.textSecondary, height: 1.4),
              ),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout, color: Brand.danger),
            label: const Text('Cerrar sesión', style: TextStyle(color: Brand.danger)),
            onPressed: () async {
              if (await confirm(context, title: 'Cerrar sesión', message: '¿Querés salir de la cuenta?', action: 'Salir')) {
                await session.signOut();
              }
            },
          ),
        ],
      ),
    );
  }
}
