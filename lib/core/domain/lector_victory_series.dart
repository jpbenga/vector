enum LectorSeriesScope { overall, home, away }

extension LectorSeriesScopePresentation on LectorSeriesScope {
  String get label => switch (this) {
    LectorSeriesScope.overall => 'générale',
    LectorSeriesScope.home => 'à domicile',
    LectorSeriesScope.away => 'à l’extérieur',
  };
  String get readingId => switch (this) {
    LectorSeriesScope.overall => 'winning_streak',
    LectorSeriesScope.home => 'home_winning_streak',
    LectorSeriesScope.away => 'away_winning_streak',
  };
}

/// Sport adapters supply completed, deduplicated, newest-first games in one
/// competition/season/phase. Unknown results or venues interrupt the proof,
/// rather than silently joining wins on either side of a missing game.
abstract final class LectorVictorySeries {
  static const threshold = 3;
  static LectorVictorySeriesAssessment assess<T>(
    Iterable<T> newestFirst, {
    required bool? Function(T) won,
    required bool? Function(T) home,
    LectorSeriesScope scope = LectorSeriesScope.overall,
    bool historyComplete = false,
  }) {
    final run = LectorResultSeries.assess(
      newestFirst,
      matches: won,
      home: home,
      scope: scope,
      historyComplete: historyComplete,
    );
    return LectorVictorySeriesAssessment(run.count, run.sample, run.exact);
  }
}

class LectorVictorySeriesAssessment {
  const LectorVictorySeriesAssessment(this.count, this.sample, this.exact);
  final int count, sample;
  final bool exact;
  bool get detected => count >= LectorVictorySeries.threshold;
  bool get sufficient => detected || exact;
  String get label =>
      '${exact ? '' : 'au moins '}$count victoire${count == 1 ? '' : 's'} consécutive${count == 1 ? '' : 's'}';
  String get radarLabel => 'En série · ${exact ? '' : '≥'}$count V';
  String get milestone => count == 3
      ? 'Une quatrième victoire en jeu.'
      : count == 4
      ? 'Une cinquième victoire en jeu.'
      : count == 5
      ? 'Le jalon des cinq victoires est atteint.'
      : count > 5
      ? 'La série se prolonge au-delà de cinq victoires.'
      : '';
}

/// Counts a consecutive result independently of the points awarded by a sport.
/// In football a draw matches neither a win nor a loss and ends both runs.
abstract final class LectorResultSeries {
  static LectorVictorySeriesAssessment assess<T>(
    Iterable<T> newestFirst, {
    required bool? Function(T) matches,
    required bool? Function(T) home,
    LectorSeriesScope scope = LectorSeriesScope.overall,
    bool historyComplete = false,
  }) {
    var count = 0, sample = 0;
    for (final game in newestFirst) {
      if (scope != LectorSeriesScope.overall) {
        final atHome = home(game);
        if (atHome == null) {
          return LectorVictorySeriesAssessment(count, sample, false);
        }
        if (atHome != (scope == LectorSeriesScope.home)) continue;
      }
      sample++;
      final result = matches(game);
      if (result != true) {
        return LectorVictorySeriesAssessment(count, sample, result == false);
      }
      count++;
    }
    return LectorVictorySeriesAssessment(count, sample, historyComplete);
  }
}

/// Former venue win-series preferences now name the same momentum reading.
String canonicalVenueReadingId(String id) => switch (id) {
  'home_winning_streak' => 'strong_home_team',
  'away_winning_streak' => 'strong_away_team',
  _ => id,
};
