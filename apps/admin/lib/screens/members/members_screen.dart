import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../../widgets/invite_code_sheet.dart';
import 'member_detail_screen.dart';
import 'new_member_screen.dart';

enum _Filter { all, withPlan, noPlan, team }

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;
  _Filter _filter = _Filter.all;
  Future<(List<Member>, List<Invitation>)>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _load() {
    final api = context.read<AdminApi>();
    setState(() {
      _data = Future.wait([api.members(search: _search.text), api.pendingInvitations()])
          .then((r) => (r[0] as List<Member>, r[1] as List<Invitation>));
    });
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    _load();
  }

  bool _matches(Member m) => switch (_filter) {
        _Filter.all => true,
        _Filter.withPlan => m.role == Role.member && m.currentMembership?.isCurrent == true,
        _Filter.noPlan => m.role == Role.member && m.currentMembership?.isCurrent != true,
        _Filter.team => m.role != Role.member,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Socios')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(const NewMemberScreen()),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Nuevo socio'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, usuario, email o teléfono',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), _load);
              },
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final (f, label) in const [
                  (_Filter.all, 'Todos'),
                  (_Filter.withPlan, 'Con plan'),
                  (_Filter.noPlan, 'Sin plan'),
                  (_Filter.team, 'Equipo'),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(label),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _load(),
              child: AsyncView(
                future: _data,
                onRetry: _load,
                builder: (context, data) {
                  final (members, invites) = data;
                  final list = members.where(_matches).toList();
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                    children: [
                      if (invites.isNotEmpty && _filter == _Filter.all && _search.text.isEmpty) ...[
                        const SectionTitle('Invitaciones pendientes'),
                        Card(
                          child: Column(
                            children: [
                              for (var i = 0; i < invites.length; i++) ...[
                                if (i > 0) const Divider(),
                                _InviteTile(invite: invites[i], onChanged: _load),
                              ],
                            ],
                          ),
                        ),
                        SectionTitle('Socios (${list.length})'),
                      ],
                      if (list.isEmpty) const EmptyState(icon: Icons.person_search, text: 'No hay resultados'),
                      for (final m in list)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Card(
                            child: ListTile(
                              leading: Avatar(m.fullName),
                              title: Text(m.fullName),
                              subtitle: Text(_subtitle(m)),
                              trailing: _badge(m),
                              onTap: () => _open(MemberDetailScreen(memberId: m.id)),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(Member m) {
    final ms = m.currentMembership;
    if (m.role != Role.member) return '@${m.username} · ${m.role.label}';
    if (ms == null) return '@${m.username} · Sin plan';
    return '@${m.username} · ${ms.plan.name} · vence ${DateFormat('dd/MM').format(ms.endsOn)}';
  }

  Widget? _badge(Member m) {
    if (!m.active) return const Tag('Inactivo', color: Brand.danger);
    if (m.role != Role.member) return Tag(m.role.label, color: Brand.warning);
    final ms = m.currentMembership;
    if (ms == null || !ms.isCurrent) return const Tag('Sin plan', color: Brand.textSecondary);
    final days = ms.endsOn.difference(DateUtils.dateOnly(DateTime.now())).inDays;
    if (days <= 5) return Tag('Vence en $days d', color: Brand.warning);
    return const Tag('Activo', color: Brand.success);
  }
}

class _InviteTile extends StatelessWidget {
  const _InviteTile({required this.invite, required this.onChanged});

  final Invitation invite;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final api = context.read<AdminApi>();
    final contact = invite.phone ?? invite.email ?? 'Sin contacto';
    return ListTile(
      leading: const Icon(Icons.key_outlined),
      title: Text(invite.fullName),
      subtitle: Text(
        invite.expired
            ? '$contact · código vencido'
            : '$contact · vence ${DateFormat('dd/MM HH:mm').format(invite.expiresAt.toLocal())}',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (v) async {
          if (v == 'code') {
            InviteCode? code;
            await runGuarded(context, () async => code = await api.regenerateInviteCode(invite.id));
            final created = code;
            if (created == null || !context.mounted) return;
            await showInviteCode(context, invite: created, fullName: invite.fullName, phone: invite.phone);
            onChanged();
          } else if (v == 'delete') {
            if (await runGuarded(context, () => api.deleteInvitation(invite.id), success: 'Invitación eliminada')) {
              onChanged();
            }
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'code', child: Text('Generar nuevo código')),
          PopupMenuItem(value: 'delete', child: Text('Eliminar invitación')),
        ],
      ),
    );
  }
}
