import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'config/gym_config.dart';
import 'data/gym_repository.dart';
import 'screens/auth/invite_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/security_setup_screen.dart';
import 'screens/home/home_shell.dart';
import 'screens/lock/lock_screen.dart';
import 'services/app_icon_service.dart';
import 'services/member_controller.dart';
import 'services/session_controller.dart';
import 'theme/app_theme.dart';

class Rf8App extends StatelessWidget {
  const Rf8App({super.key, required this.repo, required this.session, required this.appIcons});

  final GymRepository repo;
  final SessionController session;
  final AppIconService appIcons;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: repo),
        Provider.value(value: appIcons),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(
        title: GymConfig.gymName,
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _RootGate(),
      ),
    );
  }
}

/// Decide qué mostrar según el estado de la sesión.
class _RootGate extends StatelessWidget {
  const _RootGate();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final child = switch (session.stage) {
      SessionStage.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionStage.signedOut => session.pendingInvite != null
          ? InviteScreen(key: ValueKey(session.pendingInvite), token: session.pendingInvite)
          : const LoginScreen(),
      SessionStage.setupSecurity => const SecuritySetupScreen(),
      SessionStage.locked => const LockScreen(),
      SessionStage.unlocked => ChangeNotifierProvider(
          // Un controlador nuevo por usuario.
          key: ValueKey(session.userId),
          create: (ctx) => MemberController(ctx.read<GymRepository>())..load(),
          child: const HomeShell(),
        ),
    };
    return AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: child);
  }
}
