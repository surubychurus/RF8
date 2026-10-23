import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/member_controller.dart';
import '../theme/brand.dart';
import '../widgets/content_widgets.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Set<String> _unreadOnOpen;

  @override
  void initState() {
    super.initState();
    final member = context.read<MemberController>();
    _unreadOnOpen = {for (final n in member.notifications) if (!n.read) n.id};
    WidgetsBinding.instance.addPostFrameCallback((_) => member.markAllRead());
  }

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();
    final items = member.notifications;
    return Scaffold(
      appBar: AppBar(title: const Text('Notificaciones')),
      body: RefreshIndicator(
        onRefresh: member.refreshNotifications,
        child: items.isEmpty
            ? ListView(
                children: const [
                  Padding(
                    padding: EdgeInsets.all(48),
                    child: Column(children: [
                      Icon(Icons.notifications_none, size: 48, color: Brand.textSecondary),
                      SizedBox(height: 12),
                      Text('No tenés notificaciones', style: TextStyle(color: Brand.textSecondary)),
                    ]),
                  ),
                ],
              )
            : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final isNew = _unreadOnOpen.contains(n.id);
                  return Card(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(color: isNew ? Brand.primary : Brand.outline),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(16),
                      leading: Icon(n.isGlobal ? Icons.campaign_outlined : Icons.person_outline,
                          color: isNew ? Brand.primary : Brand.textSecondary),
                      title: Text(n.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('${n.body}\n${DateFormat("d MMM · HH:mm", 'es').format(n.createdAt)}'),
                      ),
                      trailing: n.linkUrl == null ? null : const Icon(Icons.open_in_new, size: 18),
                      onTap: n.linkUrl == null ? null : () => openLink(context, n.linkUrl!),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
