import 'package:flutter/material.dart';
import '../../../core/theme/app_components.dart';
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
  bool completeResult(String book) => quotes
      .where((q) => q.bookmaker == book && q.marketCode == 'result_regulation')
      .map((q) => q.selectionCode)
      .toSet()
      .containsAll(['home', 'draw', 'away']);
  // A complete 1N2 takes priority over a book with many total-goal lines.
  // The entire detail still uses this single book, including other markets.
  bookmakers.sort((a, b) {
    if (completeResult(a) != completeResult(b)) {
      return completeResult(a) ? -1 : 1;
    }
    final count = quotes
        .where((q) => q.bookmaker == b)
        .length
        .compareTo(quotes.where((q) => q.bookmaker == a).length);
    return count != 0 ? count : a.compareTo(b);
  });
  final groups = <String, List<SportMarketQuote>>{};
  for (final q in quotes.where((q) => q.bookmaker == bookmakers.first)) {
    groups.putIfAbsent('${q.marketCode}:${q.line ?? ''}', () => []).add(q);
  }
  final ordered = groups.values.toList()
    ..sort((a, b) {
      final ids = HockeyModule.definition.markets.map((m) => m.id).toList();
      final rank = ids
          .indexOf(a.first.marketCode)
          .compareTo(ids.indexOf(b.first.marketCode));
      return rank != 0
          ? rank
          : (a.first.line ?? 0).compareTo(b.first.line ?? 0);
    });
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
    for (final group in ordered)
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

/// Matches hockey's away/home team order: 2, N, then 1. The scope is always
/// visible, so a regulation price cannot be confused with the final winner.
class HockeyCardOdds extends StatelessWidget {
  const HockeyCardOdds({required this.fixture, this.now, super.key});
  final SportFixture fixture;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (fixture.status != SportFixtureStatus.scheduled) {
      return const SizedBox.shrink();
    }
    final result = hockeyOddsMarkets(fixture, now ?? DateTime.now().toUtc())
        .where((m) => m.label == HockeyModule.definition.markets.first.label)
        .firstOrNull;
    final selections =
        result?.selections ?? const <({String label, double odds})>[];
    final labels = [
      (code: '2', team: fixture.away.name),
      (code: 'N', team: 'Nul'),
      (code: '1', team: fixture.home.name),
    ];
    if (!labels.every((l) => selections.any((q) => q.label == l.team))) {
      return const SizedBox.shrink();
    }
    return Tooltip(
      message: '${result!.label} · ${result.bookmaker}',
      child: SizedBox(
        width: 65,
        child: Column(
          key: ValueKey('hockey-card-odds-${fixture.id.value}'),
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '60 min',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
              ),
            ),
            for (final label in labels)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Semantics(
                  label: '${label.team}, résultat à 60 minutes',
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${label.code} ',
                          style: TextStyle(color: context.textColors.secondary),
                        ),
                        TextSpan(
                          text: selections
                              .firstWhere((q) => q.label == label.team)
                              .odds
                              .toStringAsFixed(2),
                        ),
                      ],
                    ),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
