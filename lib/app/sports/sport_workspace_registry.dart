import 'package:flutter/material.dart';

import '../../core/sports/domain/sport.dart';
import '../../core/sports/domain/sport_module.dart';
import '../../core/sports/domain/sport_feed_repository.dart';
import '../../core/di/service_locator.dart';
import '../../core/config/app_config.dart';
import '../../core/sports/data/published_sport_feed_repository.dart';
import '../../features/football/data/football_sport_feed_adapter.dart';
import '../../features/matches/data/match_feed_repository_loader.dart';
import '../../features/hockey/presentation/hockey_workspace.dart';
import '../../features/sports/domain/sport_module_registry.dart';
import '../view/copilot_flow_page.dart';

class SportWorkspaceRegistration {
  const SportWorkspaceRegistration({
    required this.definition,
    required this.icon,
    required this.builder,
    this.createFeedRepository,
  });
  final SportModuleDefinition definition;
  final IconData icon;
  final WidgetBuilder builder;
  final SportFeedRepository Function()? createFeedRepository;
}

/// Only this composition root imports the discipline workspaces. Shared
/// navigation knows no concrete engines, repositories or provider endpoints.
class SportWorkspaceRegistry {
  SportWorkspaceRegistry(Iterable<SportWorkspaceRegistration> entries)
    : entries = List.unmodifiable(entries),
      catalog = SportModuleCatalog(entries.map((entry) => entry.definition));

  final List<SportWorkspaceRegistration> entries;
  final SportModuleCatalog catalog;

  static final defaults = SportWorkspaceRegistry([
    for (final module in SportModuleRegistry.modules)
      SportWorkspaceRegistration(
        definition: module,
        createFeedRepository: module.sport == SportId.football
            ? () => FootballSportFeedAdapter(
                loadFootball: (date) =>
                    getIt<MatchFeedRepositoryLoader>().load(now: date),
              )
            : module.sport == SportId.hockey
            ? _hockeyFeed
            : null,
        icon: switch (module.sport.key) {
          'football' => Icons.sports_soccer_rounded,
          'hockey' => Icons.sports_hockey_rounded,
          'basketball' => Icons.sports_basketball_rounded,
          'baseball' => Icons.sports_baseball_rounded,
          _ => Icons.sports_football_rounded,
        },
        builder: switch (module.sport.key) {
          'football' => (_) => const CopilotFlowPage(),
          'hockey' => (_) => HockeyWorkspace(repository: _hockeyFeed()),
          _ => (_) => PlannedSportWorkspace(sport: module.sport),
        },
      ),
  ]);

  static SportFeedRepository _hockeyFeed() {
    final config = getIt.isRegistered<AppConfig>() ? getIt<AppConfig>() : null;
    final url = config?.sportFeedBaseUrl;
    return ValidatedSportFeedRepository(
      delegate: PublishedSportFeedRepository(
        sport: SportId.hockey,
        source: url != null
            ? HttpSportPublicationSource(url)
            : config?.isSupabaseConfigured == true
            ? SupabaseSportPublicationSource(
                projectUrl: config!.supabaseUrl!,
                publicKey: config.supabaseAnonKey!,
              )
            : null,
      ),
      policy: SportModuleRegistry.forSport(SportId.hockey).dataPolicy,
    );
  }

  Future<SportFeedResult> loadFeed(String sportKey, DateTime selectedDate) {
    final entry = find(sportKey);
    if (entry == null) {
      throw ArgumentError('Sport is not registered: $sportKey');
    }
    final create = entry.createFeedRepository;
    if (create == null) {
      return Future.value(
        const SportFeedResult.unavailable(
          SportFeedUnavailableReason.notConnected,
        ),
      );
    }
    final repository = create();
    if (repository.sport != entry.definition.sport) {
      throw StateError('Module is bound to another sport repository.');
    }
    return ValidatedSportFeedRepository(
      delegate: repository,
      policy: entry.definition.dataPolicy,
    ).load(selectedDate);
  }

  SportWorkspaceRegistration? find(String key) {
    for (final entry in entries) {
      if (entry.definition.sport.key == key) return entry;
    }
    return null;
  }
}

class PlannedSportWorkspace extends StatelessWidget {
  const PlannedSportWorkspace({required this.sport, super.key});
  final SportId sport;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        '${sport.label} · À venir',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ),
  );
}
