import 'package:flutter/widgets.dart';
import 'package:flutter_web_plugins/url_strategy.dart';

import 'app/app.dart';
import 'core/auth/supabase_auth_controller.dart';
import 'core/config/app_config.dart';
import 'core/di/service_locator.dart';
import 'core/identity/identity_controller.dart';
import 'core/supabase/supabase_initializer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  usePathUrlStrategy();

  final config = AppConfig.fromEnvironment();
  await configureDependencies(config);
  await getIt<SupabaseInitializer>().initialize();
  await getIt<SupabaseAuthController>().start();
  await getIt<IdentityController>().start();

  runApp(const CopilotApp());
}
