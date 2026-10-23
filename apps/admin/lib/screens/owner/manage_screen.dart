import 'package:flutter/material.dart';

import '../../theme/brand.dart';
import 'announcements_screen.dart';
import 'branding_screen.dart';
import 'global_notifications_screen.dart';
import 'links_screen.dart';
import 'media_screen.dart';
import 'plans_screen.dart';
import 'team_screen.dart';

/// Sólo dueños: contenido y configuración de la app de socios.
class ManageScreen extends StatelessWidget {
  const ManageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <(IconData, String, String, Widget)>[
      (Icons.view_carousel_outlined, 'Banner superior', 'Anuncios que ven los socios arriba', const AnnouncementsScreen()),
      (Icons.campaign_outlined, 'Notificaciones globales', 'Mensajes para todos los socios', const GlobalNotificationsScreen()),
      (Icons.link, 'Enlaces', 'Instagram, WhatsApp, web…', const LinksScreen()),
      (Icons.photo_library_outlined, 'Imágenes', 'Subir, editar y borrar', const MediaScreen()),
      (Icons.auto_awesome_outlined, 'Logo e íconos', 'Marca de la app de socios', const BrandingScreen()),
      (Icons.sell_outlined, 'Planes y precios', 'Precios mensuales de cada plan', const PlansScreen()),
      (Icons.badge_outlined, 'Equipo', 'Usuarios gym y dueños', const TeamScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Gestión')),
      body: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 240,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.1,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final (icon, title, subtitle, screen) = items[i];
          return Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, size: 32, color: Brand.primary),
                    const Spacer(),
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Brand.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
