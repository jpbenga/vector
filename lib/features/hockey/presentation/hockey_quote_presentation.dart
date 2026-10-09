import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/sports/domain/sport_market_quote.dart';
import '../../../core/widgets/lector_match_odds.dart';
import '../domain/hockey_module.dart';

/// The same quote component as football. The adapter supplies regulation labels
/// and one coherent bookmaker; it never blends prices from different books.
List<LectorOddsMarket> hockeyOddsMarkets(SportFixture fixture, DateTime now) {
  final quotes = fixture.quotes
      .where(
        (q) =>
            q.scope == SportScoreScope.regulation &&
            fixture.startsAt != null &&
            q.capturedAt.isBefore(fixture.startsAt!) &&
            !q.capturedAt.isAfter(now.add(const Duration(minutes: 1))) &&
            (fixture.status != SportFixtureStatus.scheduled ||
                now.difference(q.capturedAt) <= const Duration(hours: 48)) &&
            HockeyModule.definition.markets.any((m) => m.id == q.marketCode),
      )
      .toList();
  final bookmakers = quotes.map((q) => q.bookmaker).toSet().toList()..sort();
  if (bookmakers.isEmpty) return const [];
  // Prefer the most complete quoted book; deterministic name order breaks ties.
  bookmakers.sort(
    (a, b) => quotes
        .where((q) => q.bookmaker == b)
        .length
        .compareTo(quotes.where((q) => q.bookmaker == a).length),
  );
  final groups = <String, List<SportMarketQuote>>{};
  for (final q in quotes.where((q) => q.bookmaker == bookmakers.first)) {
    groups.putIfAbsent('${q.marketCode}:${q.line ?? ''}', () => []).add(q);
  }
  String label(SportMarketQuote q) => switch (q.selectionCode) {
    'home' => fixture.home.name,
    'away' => fixture.away.name,
    'draw' => 'Nul',
    'home_draw' => '${fixture.home.name} ou nul',
    'draw_away' => 'Nul ou ${fixture.away.name}',
    'home_away' => '${fixture.home.name} ou ${fixture.away.name}',
    'over' => 'Plus de ${q.line?.toString().replaceAll('.', ',')}',
    'under' => 'Moins de ${q.line?.toString().replaceAll('.', ',')}',
    _ => q.selectionCode,
  };
  return [
    for (final group in groups.values)
      LectorOddsMarket(
        label: HockeyModule.definition.markets
            .firstWhere((m) => m.id == group.first.marketCode)
            .label,
        selections: [
          for (final q in group) (label: label(q), odds: q.decimalOdds),
        ],
        bookmaker: group.first.bookmaker,
        recordedAt: group
            .map((q) => q.capturedAt)
            .reduce((a, b) => a.isBefore(b) ? a : b),
      ),
  ];
}
