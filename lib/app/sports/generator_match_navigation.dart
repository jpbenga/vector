import 'package:flutter/material.dart';
import '../../core/di/service_locator.dart';
import '../../core/widgets/lector_deferred_content.dart';
import '../../core/sports/domain/sport.dart';
import '../../core/sports/domain/sport_feed_repository.dart';
import '../../features/matches/data/match_feed_repository_loader.dart';
import '../../features/matches/domain/match_board_item.dart';
import '../../features/matches/presentation/match_detail_page.dart';
import '../../features/hockey/presentation/hockey_match_detail_page.dart';
import '../../features/onboarding/domain/decision_profile.dart';
import 'sport_workspace_registry.dart';

/// Composition root resolves IDs into existing sport pages. The generator UI
/// never imports a concrete sport page or duplicates its analytical tabs.
void openGeneratorMatch(
  BuildContext context,
  Map<String, dynamic> pick, {
  DecisionProfile? footballProfile,
}) {
  final date = DateTime.tryParse(pick['kickoff']?.toString() ?? '')?.toLocal();
  if (date == null) return;
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) {
        if (pick['sport'] == 'football') {
          return LectorDeferredContent<MatchBoardItem>(
            title: '${pick['home']} · ${pick['away']}',
            load: () async {
              final loader = getIt<MatchFeedRepositoryLoader>();
              final repository = await loader.load(now: date);
              final match = repository
                  .allMatches()
                  .where((m) => m.id == pick['matchId'])
                  .firstOrNull;
              if (match == null) {
                throw StateError('Cette rencontre n’est plus disponible.');
              }
              final detail =
                  await loader.loadDetails(date, match.id) ?? repository;
              final resolved =
                  detail
                      .allMatches()
                      .where((m) => m.id == pick['matchId'])
                      .firstOrNull ??
                  match;
              return footballProfile == null
                  ? resolved
                  : detail.analyzeFor(footballProfile, resolved);
            },
            builder: (_, match) => MatchDetailPage(
              match: match,
              selectedReadingIds:
                  footballProfile?.optionIdsFor('readings') ?? const [],
            ),
          );
        }
        final repository = SportWorkspaceRegistry.defaults
            .find(SportId.hockey.key)
            ?.createFeedRepository
            ?.call();
        return LectorDeferredContent<SportFeedResult>(
          title: '${pick['away']} · ${pick['home']}',
          load: () async {
            if (repository == null) throw StateError('Sport indisponible');
            return repository is ProgressiveSportFeedRepository
                ? repository.loadMatch(
                    date,
                    pick['matchId'].toString().split(':').last,
                  )
                : repository.load(date);
          },
          builder: (_, result) {
            final fixture = result.snapshot?.items
                .where((f) => f.id.key == pick['matchId'])
                .firstOrNull;
            if (fixture == null) {
              return const Center(
                child: Text('Cette rencontre n’est plus disponible.'),
              );
            }
            return HockeyMatchDetailPage(
              fixture: fixture,
              competition: result.snapshot?.competitions
                  .where((c) => c.id == fixture.competition)
                  .firstOrNull,
            );
          },
        );
      },
    ),
  );
}
