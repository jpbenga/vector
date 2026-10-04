import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/admin/presentation/operations_page.dart';
import '../../core/sports/domain/sport.dart';
import '../../features/sports/presentation/sport_workspace_page.dart';

GoRouter createAppRouter(AppConfig config) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.root.name,
        builder: (context, state) {
          return const SportWorkspacePage(sport: SportId.football);
        },
      ),
      GoRoute(
        path:
            '/sports/:sport(football|hockey|basketball|baseball|american-football)',
        name: AppRoute.sport.name,
        builder: (context, state) => SportWorkspacePage(
          sport: SportId.parse(state.pathParameters['sport']!),
        ),
      ),
      GoRoute(
        path: '/admin',
        name: AppRoute.admin.name,
        builder: (context, state) {
          return const OperationsPage();
        },
      ),
    ],
  );
}

enum AppRoute { root, sport, admin }
