import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/admin_api.dart';
import '../../data/models.dart';
import '../../theme/brand.dart';
import '../../widgets/common.dart';
import '../members/member_detail_screen.dart';

/// Usuarios con acceso a la administración. Para sumar a alguien al equipo,
/// primero se lo invita como socio y después se le cambia el rol.
class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  Future<List<Member>>? _team;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() => setState(() {
        _team = context.read<AdminApi>().members().then((all) => all.where((m) => m.role != Role.member).toList());
      });

  Future<void> _open(Member m) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => MemberDetailScreen(memberId: m.id)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Equipo')),
      body: AsyncView(
        future: _team,
        onRetry: _load,
        builder: (context, team) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Gym: valida turnos y gestiona socios.\nDueño: acceso total.\n\n'
              'Para sumar a alguien: invitalo como socio, y cuando cree su usuario abrí su ficha → Cambiar rol.',
              style: TextStyle(color: Brand.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 16),
            for (final m in team)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  child: ListTile(
                    leading: Avatar(m.fullName),
                    title: Text(m.fullName),
                    subtitle: Text('@${m.username}'),
                    trailing: Tag(m.role.label, color: m.role == Role.owner ? Brand.warning : Brand.primary),
                    onTap: () => _open(m),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
