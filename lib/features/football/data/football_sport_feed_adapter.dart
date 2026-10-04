import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_feed_repository.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_snapshot.dart';
import '../../matches/data/match_feed_repository.dart';

/// Migration bridge: reuse the existing published football repository.
/// Never run football analysis twice or reinterpret its historical payloads.
class FootballSportFeedAdapter implements SportFeedRepository {
  const FootballSportFeedAdapter({required this.loadFootball});
  final Future<MatchFeedRepository> Function(DateTime date) loadFootball;
  @override
  SportId get sport => SportId.football;

  @override
  Future<SportFeedResult> load(DateTime selectedDate) async {
    final repository = await loadFootball(selectedDate);
    final metadata = repository.snapshotMetadata;
    if (metadata?.capturedAt == null ||
        metadata?.windowStart == null ||
        metadata?.windowEnd == null) {
      return const SportFeedResult.unavailable(
        SportFeedUnavailableReason.notPublished,
      );
    }
    SportEntityId id(SportEntityKind kind, String value) => SportEntityId(
      sport: sport,
      provider: 'api-football',
      kind: kind,
      value: value,
    );
    final items = repository.allMatches().map((item) {
      final fixture = item.fixture;
      final score = fixture.score;
      return SportFixture(
        id: id(
          SportEntityKind.match,
          fixture.apiFootballFixtureId?.toString() ?? fixture.id,
        ),
        competition: id(
          SportEntityKind.competition,
          fixture.competition.apiFootballLeagueId?.toString() ??
              fixture.competition.id,
        ),
        competitionName: fixture.competition.name,
        season: fixture.competition.season.toString(),
        home: SportParticipant(
          id: id(
            SportEntityKind.team,
            fixture.homeTeam.apiFootballTeamId?.toString() ??
                fixture.homeTeam.id,
          ),
          name: fixture.homeTeam.name,
          logoUrl: fixture.homeTeam.logoUrl,
        ),
        away: SportParticipant(
          id: id(
            SportEntityKind.team,
            fixture.awayTeam.apiFootballTeamId?.toString() ??
                fixture.awayTeam.id,
          ),
          name: fixture.awayTeam.name,
          logoUrl: fixture.awayTeam.logoUrl,
        ),
        startsAt: fixture.kickoff,
        status: SportFixtureStatus.values.byName(fixture.status.name),
        // The legacy envelope does not prove which period produced this score.
        // Preserve it as a final/result score; never invent a regulation score.
        scores: score == null
            ? const {}
            : {
                SportScoreScope.finalResult: SportScore(
                  home: score.home,
                  away: score.away,
                ),
              },
      );
    });
    return SportFeedResult.available(
      SportSnapshot(
        sport: sport,
        schemaVersion: 1,
        capturedAt: metadata!.capturedAt!,
        windowStart: metadata.windowStart!,
        windowEnd: metadata.windowEnd!,
        items: items,
        sportOf: (fixture) => fixture.sport,
      ),
    );
  }
}
