import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/demo_gym_repository.dart';
import 'data/gym_repository.dart';
import 'data/supabase_gym_repository.dart';
import 'services/app_icon_service.dart';
import 'services/deep_link_service.dart';
import 'services/local_security.dart';
import 'services/session_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');

  final GymRepository repo;
  if (AppConfig.isDemo) {
    repo = DemoGymRepository();
  } else {
    await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
    repo = SupabaseGymRepository(Supabase.instance.client);
  }

  final session = SessionController(repo: repo, security: LocalSecurity());
  await session.init();
  DeepLinkService().start(session.receiveInvite);

  runApp(Rf8App(repo: repo, session: session, appIcons: AppIconService()));
}
