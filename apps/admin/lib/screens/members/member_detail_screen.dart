import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../data/session.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import 'notification_sheet.dart';
import 'plan_sheet.dart';

class MemberDetailScreen extends StatefulWidget {
  const MemberDetailScreen({super.key, required this.memberId});

  final String memberId;

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen> {
  Future<(Member, List<DayBooking>, List<AppNotification>)>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final api = context.read<AdminApi>();
    final from = DateTime.now().subtract(const Duration(days: 30));
    setState(() {
      _data = Future.wait([
        api.member(widget.memberId),
        api.memberBookings(widget.memberId, from: from),
        api.notifications(userId: widget.memberId),
      ]).then((r) => (r[0] as Member, r[1] as List<DayBooking>, r[2] as List<AppNotification>));
    });
  }

  Future<void> _plan(Member m, {Membership? edit}) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => PlanSheet(member: m, membership: edit),
    );
    if (changed == true) _load();
  }

  Future<void> _notify(Member m) async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => NotificationSheet(userId: m.id, recipient: m.fullName),
    );
    if (sent == true) _load();
  }

  Future<void> _edit(Member m) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: Brand.surface,
      builder: (_) => _EditSheet(member: m),
    );
    if (changed == true) _load();
  }

  Future<void> _setRole(Member m) async {
    final api = context.read<AdminApi>();
    final role = await showDialog<Role>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Rol'),
        children: [
          for (final r in Role.values)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, r),
              child: Row(
                children: [
                  Icon(r == m.role ? Icons.radio_button_checked : Icons.radio_button_off, size: 20),
                  const SizedBox(width: 12),
                  Text(switch (r) {
                    Role.member => 'Socio',
                    Role.gym => 'Gym (validación y socios)',
                    Role.owner => 'Dueño (acceso total)',
                  }),
                ],
              ),
            ),
        ],
      ),
    );
    if (role == null || role == m.role || !mounted) return;
    if (await runGuarded(context, () => api.setRole(m.id, role), success: 'Rol actualizado')) _load();
  }

  Future<void> _delete(Member m) async {
    final api = context.read<AdminApi>();
    final nav = Navigator.of(context);
    if (!await confirm(context,
        title: 'Eliminar usuario',
        message: 'Se borra la cuenta de ${m.fullName}, sus turnos y sus planes. No se puede deshacer.',
        action: 'Eliminar',
        danger: true)) {
      return;
    }
    if (!mounted) return;
    if (await runGuarded(context, () => api.deleteUser(m.id), success: 'Usuario eliminado')) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    return Scaffold(
      appBar: AppBar(title: const Text('Socio')),
      body: AsyncView(
        future: _data,
        onRetry: _load,
        builder: (context, data) {
          final (m, bookings, notes) = data;
          final isMe = m.id == session.me?.id;
          final current = m.currentMembership;
          return RefreshIndicator(
            onRefresh: () async => _load(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              children: [
                // --- Encabezado ---------------------------------------------------
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Avatar(m.fullName, radius: 30),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(m.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                                  Text('@${m.username}', style: const TextStyle(color: Brand.textSecondary)),
                                  const SizedBox(height: 6),
                                  Wrap(spacing: 6, children: [
                                    Tag(m.role.label, color: m.role == Role.member ? Brand.primary : Brand.warning),
                                    if (!m.active) const Tag('Inactivo', color: Brand.danger),
                                  ]),
                                ],
                              ),
                            ),
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _edit(m)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.icon(
                                style: FilledButton.styleFrom(backgroundColor: Brand.whatsapp, foregroundColor: Colors.black),
                                onPressed: m.phone == null ? null : () => openWhatsApp(context, m.phone),
                                icon: const Icon(Icons.chat),
                                label: const Text('WhatsApp'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _notify(m),
                                icon: const Icon(Icons.notifications_outlined),
                                label: const Text('Notificar'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // --- Contacto -----------------------------------------------------
                const SectionTitle('Contacto'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: Text(m.phone ?? 'Sin WhatsApp'),
                        subtitle: m.phone == null ? null : Text('wa.me/${whatsappNumber(m.phone)}'),
                        onTap: m.phone == null ? () => _edit(m) : () => openWhatsApp(context, m.phone),
                      ),
                      const Divider(),
                      ListTile(leading: const Icon(Icons.mail_outline), title: Text(m.email)),
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.calendar_today_outlined),
                        title: Text('Socio desde ${DateFormat('dd/MM/yyyy').format(m.createdAt.toLocal())}'),
                      ),
                      if ((m.notes ?? '').isNotEmpty) ...[
                        const Divider(),
                        ListTile(leading: const Icon(Icons.sticky_note_2_outlined), title: Text(m.notes!)),
                      ],
                    ],
                  ),
                ),

                // --- Plan ---------------------------------------------------------
                SectionTitle(
                  'Plan',
                  trailing: TextButton.icon(
                    onPressed: () => _plan(m),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(current == null ? 'Asignar' : 'Renovar'),
                  ),
                ),
                if (m.memberships.isEmpty)
                  const Card(child: ListTile(leading: Icon(Icons.info_outline), title: Text('Sin planes asignados')))
                else
                  Card(
                    child: Column(
                      children: [
                        for (final (i, ms) in (m.memberships.toList()..sort((a, b) => b.startsOn.compareTo(a.startsOn))).indexed) ...[
                          if (i > 0) const Divider(),
                          ListTile(
                            leading: Icon(
                              Icons.workspace_premium_outlined,
                              color: ms.isCurrent ? Brand.success : Brand.textSecondary,
                            ),
                            title: Text(ms.plan.name),
                            subtitle: Text(
                              '${DateFormat('dd/MM/yyyy').format(ms.startsOn)} → ${DateFormat('dd/MM/yyyy').format(ms.endsOn)}',
                            ),
                            trailing: ms.isCurrent
                                ? const Tag('Vigente', color: Brand.success)
                                : ms.endsOn.isBefore(DateTime.now())
                                    ? const Tag('Vencido')
                                    : const Tag('Próximo', color: Brand.warning),
                            onTap: () => _plan(m, edit: ms),
                          ),
                        ],
                      ],
                    ),
                  ),

                // --- Turnos -------------------------------------------------------
                const SectionTitle('Turnos (últimos 30 días y próximos)'),
                if (bookings.isEmpty)
                  const Card(child: ListTile(title: Text('Sin turnos')))
                else
                  Card(
                    child: Column(
                      children: [
                        for (final (i, b) in bookings.indexed) ...[
                          if (i > 0) const Divider(),
                          ListTile(
                            dense: true,
                            title: Text(DateFormat("EEE d/MM", 'es').format(b.date)),
                            subtitle: Text(b.slot.label),
                            trailing: b.attended
                                ? const Tag('Asistió', color: Brand.success)
                                : b.date.isBefore(DateUtils.dateOnly(DateTime.now()))
                                    ? const Tag('Faltó', color: Brand.danger)
                                    : const Tag('Reservado'),
                          ),
                        ],
                      ],
                    ),
                  ),

                // --- Notificaciones -----------------------------------------------
                const SectionTitle('Notificaciones enviadas'),
                if (notes.isEmpty)
                  const Card(child: ListTile(title: Text('Ninguna todavía')))
                else
                  Card(
                    child: Column(
                      children: [
                        for (final (i, n) in notes.indexed) ...[
                          if (i > 0) const Divider(),
                          ListTile(
                            title: Text(n.title),
                            subtitle: Text('${n.body}\n${DateFormat('dd/MM HH:mm').format(n.createdAt)}'),
                            isThreeLine: true,
                          ),
                        ],
                      ],
                    ),
                  ),

                // --- Sólo dueños ----------------------------------------------------
                if (session.isOwner && !isMe) ...[
                  const SectionTitle('Administración'),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.admin_panel_settings_outlined),
                          title: const Text('Cambiar rol'),
                          subtitle: Text(m.role.label),
                          onTap: () => _setRole(m),
                        ),
                        const Divider(),
                        ListTile(
                          leading: const Icon(Icons.delete_outline, color: Brand.danger),
                          title: const Text('Eliminar usuario', style: TextStyle(color: Brand.danger)),
                          onTap: () => _delete(m),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.member});

  final Member member;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.member.fullName);
  late final _phone = TextEditingController(text: widget.member.phone);
  late final _notes = TextEditingController(text: widget.member.notes);
  late bool _active = widget.member.active;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().length < 3) return;
    setState(() => _saving = true);
    final api = context.read<AdminApi>();
    String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final ok = await runGuarded(
      context,
      () => api.updateMember(
        widget.member.id,
        fullName: _name.text.trim(),
        phone: opt(_phone),
        notes: opt(_notes),
        active: _active,
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Editar socio', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nombre completo')),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'WhatsApp'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notas internas (no las ve el socio)'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Cuenta activa'),
              subtitle: const Text('Si está inactiva no puede reservar turnos'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _saving ? null : _save, child: const Text('Guardar')),
          ],
        ),
      ),
    );
  }
}
