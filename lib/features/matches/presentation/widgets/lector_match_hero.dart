import 'package:flutter/material.dart';
import '../../../../core/widgets/lector_match_hero_view.dart';
import '../../domain/match_board_item.dart';
import '../../domain/live_match_state.dart';

/// Football adapter; the complete visual component belongs to core.
class LectorMatchHero extends StatelessWidget {
  const LectorMatchHero({required this.match, this.state, super.key});
  final MatchBoardItem match;
  final LiveMatchState? state;
  @override
  Widget build(BuildContext context) => LectorMatchHeroView(
    match: LectorMatchHeroData(
      competitionName: match.competition.name,
      competitionLogoUrl: match.competition.logoUrl,
      dateLabel: _matchDateTimeLabel(match),
      roundLabel: _fixtureRoundLabel(match.fixture.round),
      venueLabel: _venueValue(match.fixture.venue),
      temporal: state?.temporal,
      scoreSubtitle: state?.halftimeLabel,
      firstTeam: LectorMatchTeamData(
        name: match.homeTeam.name,
        role: 'Domicile',
        logoUrl: match.homeTeam.logoUrl,
      ),
      secondTeam: LectorMatchTeamData(
        name: match.awayTeam.name,
        role: 'Extérieur',
        logoUrl: match.awayTeam.logoUrl,
      ),
      isLive: match.fixture.status == FixtureStatus.live,
      isFinished: match.fixture.status == FixtureStatus.finished,
      statusLabel: match.fixture.status == FixtureStatus.live
          ? 'EN COURS'
          : match.fixture.status == FixtureStatus.finished
          ? 'TERMINÉ'
          : 'Avant-match',
      scoreLabel: match.fixture.score == null
          ? null
          : '${match.fixture.score!.home} - ${match.fixture.score!.away}',
    ),
  );
}

String _matchDateTimeLabel(MatchBoardItem match) {
  final label = match.fixture.kickoffLabel.trim();
  return label.isEmpty ? 'Aujourd’hui' : 'Aujourd’hui · $label';
}

String _venueValue(FixtureVenue? venue) {
  if (venue == null) {
    return 'Stade à confirmer';
  }
  final name = venue.name?.trim();
  final city = venue.city?.trim();
  return [
    if (name != null && name.isNotEmpty) name,
    if (city != null && city.isNotEmpty) city,
  ].join(' · ');
}

String? _fixtureRoundLabel(String? rawRound) {
  final round = rawRound?.trim();
  if (round == null || round.isEmpty) {
    return null;
  }

  final match = RegExp(
    r'^(?:regular\s+season\s*-\s*)?(\d+)$',
    caseSensitive: false,
  ).firstMatch(round);
  final number = match?.group(1);
  return number == null ? null : 'Journée $number';
}
