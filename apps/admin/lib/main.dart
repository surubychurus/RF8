import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'config/app_config.dart';
import 'data/admin_api.dart';
import 'data/session.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'es';
  await initializeDateFormatting('es');
  await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);

  final api = AdminApi(Supabase.instance.client);
  final session = AdminSession(api);
  await session.init();
  runApp(AdminApp(api: api, session: session));
}
