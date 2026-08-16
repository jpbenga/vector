import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../features/admin/presentation/admin_cockpit_page.dart';
import '../view/copilot_flow_page.dart';

GoRouter createAppRouter(AppConfig config) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.root.name,
        builder: (context, state) {
          return const CopilotFlowPage();
        },
      ),
      GoRoute(
        path: '/admin',
        name: AppRoute.admin.name,
        builder: (context, state) {
          return const AdminCockpitPage();
        },
      ),
    ],
  );
}

enum AppRoute { root, admin }
