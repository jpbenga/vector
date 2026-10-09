import '../../core/di/service_locator.dart';
import '../../core/identity/identity_scope.dart';
import '../../core/sports/domain/sport_feed_repository.dart';
import '../../features/form_radar/data/radar_audience_filter_store.dart';
import '../../features/form_radar/domain/football_radar_selection.dart';
import '../../features/form_radar/domain/radar_scope.dart';
import '../../features/hockey/domain/hockey_radar_selection.dart';
import '../../features/matches/data/match_feed_repository.dart';
import '../../features/matches/data/match_feed_repository_loader.dart';
import 'sport_workspace_registry.dart';

/// Reuse the last displayed scope; only load Radar if it has not been opened.
/// The read is lazy: entering the chat does not download all Radar histories.
Future<Map<String, RadarScope>> loadGeneratorRadarScopes(
  IdentityScope owner,
  DateTime date,
  Iterable<String> sports,
) async {
  final result = <String, RadarScope>{};
  for (final sport in sports) {
    final displayed = RadarScopeSession.read(owner, sport, date);
    if (displayed != null) {
      result[sport] = displayed;
      continue;
    }
    if (sport == 'football' &&
        getIt.isRegistered<MatchFeedRepositoryLoader>()) {
      final repository = await getIt<MatchFeedRepositoryLoader>().loadRadar(
        date,
      );
      if (repository is! SnapshotMatchFeedRepository) {
        continue;
      }
      final matches = repository.allMatches();
      final filter = await const SharedPreferencesRadarAudienceFilterStore()
          .load(owner);
      result[sport] = FootballRadarSelection(
        players: footballRadarPlayerProfiles(matches),
        teams: repository.teamFormRadarProfiles,
        audience: filter,
        nationalTeams: false,
        capturedAt: repository.snapshotMetadata.capturedAt,
        sourceIds: repository.snapshotMetadata.sourceIds,
        competitionNames: {
          for (final m in matches)
            if (m.competition.apiFootballLeagueId case final int id)
              id: m.competition.name,
        },
      ).scope;
    } else if (sport == 'hockey') {
      final repository = SportWorkspaceRegistry.defaults
          .find(sport)
          ?.createFeedRepository
          ?.call();
      if (repository == null) {
        continue;
      }
      final feed = await (repository is ProgressiveSportFeedRepository
          ? repository.loadRadar(date)
          : repository.load(date));
      if (feed.snapshot != null) {
        result[sport] = HockeyRadarSelection(feed.snapshot!, day: date).scope;
      }
    }
    if (result[sport] case final scope?) {
      RadarScopeSession.remember(owner, sport, date, scope);
    }
  }
  return result;
}
