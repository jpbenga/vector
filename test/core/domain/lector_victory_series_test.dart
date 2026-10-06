import 'package:copilot/core/domain/lector_victory_series.dart';
import 'package:copilot/core/domain/lector_form_reading_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  LectorVictorySeriesAssessment series(
    List<bool?> results, {
    bool complete = false,
  }) => LectorVictorySeries.assess(
    results,
    won: (r) => r,
    home: (_) => true,
    historyComplete: complete,
  );
  test('starts at three, counts past five and marks truncated histories', () {
    expect(series([true, true]).detected, isFalse);
    for (final n in [3, 4, 5, 8]) {
      final lower = series(List.filled(n, true));
      expect(lower.detected, isTrue);
      expect(lower.count, n);
      expect(lower.exact, isFalse);
      expect(lower.label, contains('au moins'));
      expect(series([...List.filled(n, true), false]).exact, isTrue);
      expect(series(List.filled(n, true), complete: true).exact, isTrue);
    }
  });
  test('loss, draw and missing result cannot join runs', () {
    expect(series([true, true, false, true, true, true]).count, 2);
    expect(series([true, true, null, true, true, true]).count, 2);
    expect(series([true, true, null]).sufficient, isFalse);
    expect(series([true, true, false]).sufficient, isTrue);
  });
  test(
    'home and away series are independent of results at the other venue',
    () {
      final games = [
        (true, true),
        (false, false),
        (true, true),
        (false, false),
        (true, true),
        (true, false),
      ];
      LectorVictorySeriesAssessment at(LectorSeriesScope scope) =>
          LectorVictorySeries.assess(
            games,
            won: (g) => g.$1,
            home: (g) => g.$2,
            scope: scope,
          );
      expect(at(LectorSeriesScope.overall).count, 1);
      expect(at(LectorSeriesScope.home).count, 3);
      expect(at(LectorSeriesScope.home).detected, isTrue);
      expect(at(LectorSeriesScope.away).count, 0);
      final unknown = LectorVictorySeries.assess(
        [(true, true), (true, true), (true, null), (true, true)],
        won: (g) => g.$1,
        home: (g) => g.$2,
        scope: LectorSeriesScope.home,
      );
      expect(unknown.count, 2);
      expect(unknown.sufficient, isFalse);
    },
  );
  test(
    'football thresholds are unchanged and hockey scales with its barème',
    () {
      final football = LectorFormWindow([3, 3, 1, 1, 1], maximumPoints: 3);
      expect(football.positive, isTrue);
      expect(football.total, 9);
      expect(football.trend, 2);
      expect(football.improving, isTrue);
      expect(
        LectorFormWindow([3, 3, 0, 3, 3], maximumPoints: 3).positive,
        isFalse,
      );
      expect(
        LectorFormWindow([1, 1, 1, 1, 0], maximumPoints: 3).negative,
        isTrue,
      );
      final hockey = LectorFormWindow([2, 1, 1, 1, 1], maximumPoints: 2);
      expect(hockey.positive, isTrue);
      expect(hockey.positiveMinimum, 6);
      expect(hockey.negativeMaximum, 2);
      expect(
        LectorFormWindow([2, 2, 0, 0, 0], maximumPoints: 2).improving,
        isTrue,
      );
      expect(
        LectorFormWindow([2, 2, 2, 2], maximumPoints: 2).available,
        isFalse,
      );
    },
  );
}
