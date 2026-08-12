import 'package:flutter/widgets.dart';

import 'app/app.dart';
import 'core/auth/supabase_auth_controller.dart';
import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'core/supabase/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);
  await getIt<SupabaseInitializer>().initialize();
  await getIt<SupabaseAuthController>().start();

  runApp(const CopilotApp());
}
