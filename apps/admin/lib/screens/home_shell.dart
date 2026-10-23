import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/session.dart';
import 'account_screen.dart';
import 'members/members_screen.dart';
import 'owner/manage_screen.dart';
import 'validate/validate_screen.dart';

/// Gym: Validar · Socios · Cuenta
/// Dueño: Validar · Socios · Gestión · Cuenta
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final owner = context.watch<AdminSession>().isOwner;
    final pages = <(Widget, NavigationDestination)>[
      (
        const ValidateScreen(),
        const NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Validar'),
      ),
      (
        const MembersScreen(),
        const NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'Socios'),
      ),
      if (owner)
        (
          const ManageScreen(),
          const NavigationDestination(icon: Icon(Icons.tune), label: 'Gestión'),
        ),
      (
        const AccountScreen(),
        const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Cuenta'),
      ),
    ];
    final index = _index.clamp(0, pages.length - 1);
    return Scaffold(
      body: IndexedStack(index: index, children: [for (final p in pages) p.$1]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [for (final p in pages) p.$2],
      ),
    );
  }
}
