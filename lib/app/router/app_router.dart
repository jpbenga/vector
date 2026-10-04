import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../sports/sport_workspace_registry.dart';
import '../../features/admin/presentation/operations_page.dart';
import '../../core/sports/domain/sport.dart';
import '../../features/sports/presentation/sport_workspace_page.dart';

GoRouter createAppRouter(AppConfig config, {SportWorkspaceRegistry? sports}) {
  final registry = sports ?? SportWorkspaceRegistry.defaults;
  if (registry.find(SportId.football.key) == null) {
    throw ArgumentError(
      'The existing football root workspace must be registered.',
    );
  }
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: AppRoute.root.name,
        builder: (context, state) {
          return SportWorkspacePage(
            sport: SportId.football,
            registry: registry,
          );
        },
      ),
      GoRoute(
        path: '/sports/:sport',
        name: AppRoute.sport.name,
        builder: (context, state) {
          final entry = registry.find(state.pathParameters['sport']!);
          if (entry == null) {
            return Scaffold(
              appBar: AppBar(title: const Text('Sport indisponible')),
              body: Center(
                child: TextButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Revenir au football'),
                ),
              ),
            );
          }
          return SportWorkspacePage(
            sport: entry.definition.sport,
            registry: registry,
          );
        },
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
