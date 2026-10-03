import '../../form_radar/domain/player_form_radar.dart';
import '../../matches/domain/match_board_item.dart';

/// Isolated visual examples. Never passed to a feed repository or published.
const appearancePreviewMatch = MatchBoardItem(
  fixture: NormalizedFixture(
    id: 'appearance-preview',
    competition: CompetitionInfo(
      id: 'appearance-liga',
      name: 'LaLiga',
      country: CountryInfo(code: 'ES', name: 'Espagne'),
      season: 2026,
      logoUrl: 'https://media.api-sports.io/football/leagues/140.png',
    ),
    homeTeam: TeamInfo(
      id: 'appearance-madrid',
      name: 'Real Madrid',
      logoUrl: 'https://media.api-sports.io/football/teams/541.png',
    ),
    awayTeam: TeamInfo(
      id: 'appearance-barcelona',
      name: 'FC Barcelone',
      logoUrl: 'https://media.api-sports.io/football/teams/529.png',
    ),
    kickoffLabel: '21:00',
    round: 'Regular Season - 28',
    status: FixtureStatus.scheduled,
    venue: FixtureVenue(name: 'Santiago Bernabéu', city: 'Madrid'),
  ),
  primaryMarket: MarketOdds(id: 'preview-home', label: 'Home', odds: 2.10),
  compatibility: 0,
  availableMarkets: [
    MatchMarket(
      id: 'matchResult',
      label: '1 N 2',
      selections: [
        MarketOdds(id: 'preview-home', label: 'Home', odds: 2.10),
        MarketOdds(id: 'preview-draw', label: 'Draw', odds: 3.40),
        MarketOdds(id: 'preview-away', label: 'Away', odds: 3.20),
      ],
    ),
  ],
  signals: [
    MatchSignal(
      id: 'positive_streak',
      title: 'Dynamique positive',
      summary: 'Une série sans défaite sur les dernières rencontres.',
      proofs: ['4 victoires et 1 nul sur 5 matchs'],
    ),
    MatchSignal(
      id: 'prolific_attack',
      title: 'Attaque efficace',
      summary: 'L’équipe marque régulièrement.',
      proofs: ['12 buts sur 5 matchs'],
    ),
    MatchSignal(
      id: 'strong_home_team',
      title: 'Solide à domicile',
      summary: 'Les derniers résultats à domicile sont favorables.',
      proofs: ['4 matchs sans défaite à domicile'],
    ),
  ],
);

final appearancePreviewPlayers = PlayerFormRadarRanker.rank([
  _player('K. Mbappé', 541, 'Real Madrid', 278, [1, 0, 1, 2, 1]),
  _player('L. Yamal', 529, 'FC Barcelone', 1100, [0, 1, 1, 0, 2]),
]);

PlayerFormRadarProfile _player(
  String name,
  int teamId,
  String teamName,
  int photoId,
  List<int> goals,
) => PlayerFormRadarProfile(
  playerId: -photoId,
  playerName: name,
  teamId: teamId,
  teamName: teamName,
  leagueId: 140,
  photoUrl: 'https://media.api-sports.io/football/players/$photoId.png',
  teamLogoUrl: 'https://media.api-sports.io/football/teams/$teamId.png',
  activity: [
    for (final item in goals.indexed)
      PlayerFormRadarMatchSnapshot(
        fixtureId: -item.$1 - 1,
        playedAt: DateTime(2026, 1, item.$1 + 1),
        appeared: true,
        starter: true,
        substitute: false,
        minutes: 90,
        goals: item.$2,
        assists: 0,
      ),
  ],
);
