import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../matches/data/match_reading_bilan_repository.dart';
import '../../matches/domain/live_match_state.dart';
import '../../matches/domain/match_board_item.dart';
import '../../matches/presentation/widgets/match_feed_card.dart';
import '../data/appearance_preview_fixture.dart';

/// Interactive example using the production card, isolated from actual scores.
class AppearanceLivePreview extends StatefulWidget {
  const AppearanceLivePreview({super.key});
  @override
  State<AppearanceLivePreview> createState() => _AppearanceLivePreviewState();
}

class _AppearanceLivePreviewState extends State<AppearanceLivePreview> {
  int _step = 0;
  @override
  Widget build(BuildContext context) {
    final fixture = appearancePreviewMatch.fixture;
    final match = appearancePreviewMatch.copyWith(
      fixture: NormalizedFixture(
        id: fixture.id,
        apiFootballFixtureId: 90000001,
        competition: fixture.competition,
        homeTeam: fixture.homeTeam,
        awayTeam: fixture.awayTeam,
        kickoffLabel: fixture.kickoffLabel,
        status: fixture.status,
        venue: fixture.venue,
      ),
      signals: const [
        MatchSignal(
          id: 'positive_streak',
          title: 'Dynamique positive',
          summary: 'FC Barcelone reste invaincu sur cinq rencontres.',
          proofs: ['4 victoires et 1 nul'],
          subjectTeamId: 'appearance-barcelona',
        ),
        MatchSignal(
          id: 'both_teams_score',
          title: 'Les deux marquent',
          summary: 'Les deux attaques marquent régulièrement.',
          proofs: ['4 matchs sur 5'],
        ),
        MatchSignal(
          id: 'under_25',
          title: 'Moins de 2,5 buts',
          summary: 'Des matchs récents avec peu de buts.',
          proofs: ['4 matchs sur 5'],
        ),
      ],
    );
    final finalState = _step == 2;
    final entries = finalState
        ? [
            for (final reading in [
              (
                'positive_streak',
                'Dynamique positive',
                'team_not_lose',
                'confirmed',
              ),
              ('both_teams_score', 'Les deux marquent', 'btts', 'confirmed'),
              ('under_25', 'Moins de 2,5 buts', 'under_25', 'contradicted'),
            ])
              MatchReadingBilanEntry(
                explanation: null,
                announcementId: 'preview-${reading.$1}',
                fixtureId: 90000001,
                kickoffAt: DateTime(2026, 10, 4, 21),
                readingId: reading.$1,
                readingLabel: reading.$2,
                verdict: reading.$4,
                announcementKind: 'reading',
                outcomeRule: reading.$3,
                subjectSide: reading.$1 == 'positive_streak' ? 'away' : 'match',
                homeTeamName: 'Real Madrid',
                awayTeamName: 'FC Barcelone',
                homeGoals: 1,
                awayGoals: 3,
                competitionName: 'LaLiga',
                leagueId: 140,
                evidence: [
                  {'label': 'Exemple de lecture annoncée avant le match'},
                ],
              ),
          ]
        : <MatchReadingBilanEntry>[];
    final state = LiveMatchState(
      fixtureId: 90000001,
      status: finalState
          ? 'FT'
          : _step == 1
          ? '2H'
          : 'NS',
      capturedAt: _step == 0 ? null : DateTime.now(),
      elapsed: _step == 1 ? 67 : null,
      homeGoals: _step == 0 ? null : 1,
      awayGoals: finalState
          ? 3
          : _step == 1
          ? 2
          : null,
      readings: entries,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Simulation · scores et résultats fictifs',
          style: TextStyle(color: context.textColors.secondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          children: [
            for (final step in [
              (0, 'Avant-match'),
              (1, 'En direct'),
              (2, 'Terminé'),
            ])
              ChoiceChip(
                label: Text(step.$2),
                selected: _step == step.$1,
                onSelected: (_) => setState(() => _step = step.$1),
              ),
          ],
        ),
        const SizedBox(height: 12),
        MatchFeedCard(
          match: match,
          liveState: state,
          radarEntries: const [],
          onTap: () {},
        ),
      ],
    );
  }
}
