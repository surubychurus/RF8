import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/member_controller.dart';
import '../../theme/brand.dart';
import '../cuenta/cuenta_screen.dart';
import '../go/go_screen.dart';
import '../turnos/turnos_screen.dart';

/// Las 3 secciones: Turnos · GO · Mi cuenta.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 1; // Arranca en GO: lo que se usa en la puerta del gimnasio.

  @override
  Widget build(BuildContext context) {
    final member = context.watch<MemberController>();

    if (member.profile == null) {
      return Scaffold(
        body: Center(
          child: member.error == null
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(member.error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: member.load, child: const Text('Reintentar')),
                    ],
                  ),
                ),
        ),
      );
    }

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const TurnosScreen(),
          GoScreen(onGoToTurnos: () => setState(() => _index = 0)),
          const CuentaScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Turnos',
          ),
          NavigationDestination(
            icon: _GoIcon(selected: false),
            selectedIcon: _GoIcon(selected: true),
            label: 'GO',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Mi cuenta',
          ),
        ],
      ),
    );
  }
}

class _GoIcon extends StatelessWidget {
  const _GoIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? Brand.primary : Brand.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(Icons.qr_code_2, color: selected ? Colors.white : Brand.textSecondary, size: 22),
      );
}
