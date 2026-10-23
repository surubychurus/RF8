import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';

/// Enviar (o editar) una notificación. [userId] null = global (sólo dueños).
class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key, this.userId, this.recipient, this.edit});

  final String? userId;
  final String? recipient;
  final AppNotification? edit;

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  late final _title = TextEditingController(text: widget.edit?.title);
  late final _body = TextEditingController(text: widget.edit?.body);
  late final _link = TextEditingController(text: widget.edit?.linkUrl);
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      showMessage(context, 'Completá título y mensaje', error: true);
      return;
    }
    setState(() => _saving = true);
    final api = context.read<AdminApi>();
    final edit = widget.edit;
    final ok = await runGuarded(
      context,
      () => edit == null
          ? api.sendNotification(userId: widget.userId, title: _title.text.trim(), body: _body.text.trim(), linkUrl: _link.text)
          : api.updateNotification(edit.id, title: _title.text.trim(), body: _body.text.trim(), linkUrl: _link.text),
      success: edit == null ? 'Notificación enviada' : 'Notificación actualizada',
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final global = widget.userId == null;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.edit != null ? 'Editar notificación' : (global ? 'Notificación global' : 'Notificar'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              global ? 'La reciben todos los socios en la app' : 'Para ${widget.recipient}',
              style: const TextStyle(color: Brand.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(controller: _title, decoration: const InputDecoration(labelText: 'Título')),
            const SizedBox(height: 12),
            TextField(controller: _body, maxLines: 4, decoration: const InputDecoration(labelText: 'Mensaje')),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'Enlace (opcional)', prefixIcon: Icon(Icons.link)),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _saving ? null : _send,
              icon: const Icon(Icons.send),
              label: Text(widget.edit != null ? 'Guardar' : 'Enviar'),
            ),
          ],
        ),
      ),
    );
  }
}
