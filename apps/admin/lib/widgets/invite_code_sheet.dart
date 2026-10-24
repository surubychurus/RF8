import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../data/models.dart';
import '../theme/brand.dart';
import 'common.dart';

/// Muestra el código de invitación para copiarlo o mandarlo por WhatsApp.
Future<void> showInviteCode(BuildContext context, {required InviteCode invite, required String fullName, String? phone}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => _InviteCodeSheet(invite: invite, fullName: fullName, phone: phone),
    );

String inviteMessage(String fullName, InviteCode invite) {
  final first = fullName.trim().split(RegExp(r'\s+')).first;
  final until = DateFormat("d 'de' MMMM", 'es').format(invite.expiresAt);
  return '¡Hola $first! Te damos la bienvenida a RF8 💪\n\n'
      'Descargá la app de RF8, tocá "Tengo una invitación" e ingresá este código:\n\n'
      '${invite.code}\n\n'
      'Vence el $until.';
}

class _InviteCodeSheet extends StatelessWidget {
  const _InviteCodeSheet({required this.invite, required this.fullName, this.phone});

  final InviteCode invite;
  final String fullName;
  final String? phone;

  @override
  Widget build(BuildContext context) {
    final message = inviteMessage(fullName, invite);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Código de invitación', style: Theme.of(context).textTheme.titleLarge),
            Text('Para $fullName', style: const TextStyle(color: Brand.textSecondary)),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: BoxDecoration(
                color: Brand.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Brand.primary, width: 2),
              ),
              child: SelectableText(
                invite.code,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 2),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sirve una sola vez · vence el ${DateFormat('dd/MM HH:mm').format(invite.expiresAt)}.\n'
              'Guardalo ahora: después sólo se puede generar uno nuevo.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Brand.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 20),
            if (whatsappNumber(phone) != null) ...[
              FilledButton.icon(
                style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.black),
                onPressed: () => openWhatsApp(context, phone, text: message),
                icon: const Icon(Icons.chat),
                label: const Text('Enviar por WhatsApp'),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: invite.code));
                showMessage(context, 'Código copiado');
              },
              icon: const Icon(Icons.copy),
              label: const Text('Copiar código'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: message));
                showMessage(context, 'Mensaje copiado');
              },
              icon: const Icon(Icons.notes),
              label: const Text('Copiar mensaje completo'),
            ),
          ],
        ),
      ),
    );
  }
}
