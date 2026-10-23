import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../members/notification_sheet.dart';

class GlobalNotificationsScreen extends StatefulWidget {
  const GlobalNotificationsScreen({super.key});

  @override
  State<GlobalNotificationsScreen> createState() => _GlobalNotificationsScreenState();
}

class _GlobalNotificationsScreenState extends State<GlobalNotificationsScreen> {
  Future<List<AppNotification>>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() => _items = context.read<AdminApi>().notifications(global: true));

  Future<void> _compose([AppNotification? edit]) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => NotificationSheet(edit: edit),
    );
    if (ok == true) _load();
  }

  Future<void> _delete(AppNotification n) async {
    final api = context.read<AdminApi>();
    if (!await confirm(context, title: 'Borrar notificación', message: 'Deja de verse para todos los socios.', action: 'Borrar', danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => api.deleteNotification(n.id), success: 'Notificación borrada')) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones globales')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(),
        icon: const Icon(Icons.campaign),
        label: const Text('Nueva'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _load(),
        child: AsyncView(
          future: _items,
          onRetry: _load,
          builder: (context, items) => items.isEmpty
              ? ListView(children: const [EmptyState(icon: Icons.notifications_none, text: 'Todavía no enviaste notificaciones globales')])
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = items[i];
                    return Card(
                      child: ListTile(
                        title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text('${n.body}\n${DateFormat('dd/MM/yyyy HH:mm').format(n.createdAt)}'),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'edit' ? _compose(n) : _delete(n),
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit', child: Text('Editar')),
                            PopupMenuItem(value: 'delete', child: Text('Borrar')),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
