import 'package:get_it/get_it.dart';

import '../auth/supabase_auth_controller.dart';
import '../config/app_config.dart';
import '../supabase/supabase_initializer.dart';
import '../../features/matches/data/match_feed_repository_loader.dart';

final getIt = GetIt.instance;

Future<void> configureDependencies(AppConfig config) async {
  await getIt.reset();

  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<SupabaseInitializer>(
      () => SupabaseInitializer(config),
    )
    ..registerLazySingleton<SupabaseAuthController>(
      () => SupabaseAuthController(getIt<SupabaseInitializer>()),
    )
    ..registerLazySingleton<MatchFeedRepositoryLoader>(
      () => MatchFeedRepositoryLoader(
        config: getIt<AppConfig>(),
        supabaseInitializer: getIt<SupabaseInitializer>(),
      ),
    );
}
