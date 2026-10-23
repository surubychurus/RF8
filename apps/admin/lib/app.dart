import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/admin_api.dart';
import 'data/session.dart';
import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'theme/app_theme.dart';

class AdminApp extends StatelessWidget {
  const AdminApp({super.key, required this.api, required this.session});

  final AdminApi api;
  final AdminSession session;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: api),
        ChangeNotifierProvider.value(value: session),
      ],
      child: MaterialApp(
        title: 'RF8 Admin',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        themeMode: ThemeMode.dark,
        locale: const Locale('es'),
        supportedLocales: const [Locale('es'), Locale('en')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();

  @override
  Widget build(BuildContext context) {
    final session = context.watch<AdminSession>();
    return switch (session.state) {
      SessionState.loading => const Scaffold(body: Center(child: CircularProgressIndicator())),
      SessionState.signedOut => const LoginScreen(),
      SessionState.ready => HomeShell(key: ValueKey(session.me!.id)),
    };
  }
}
