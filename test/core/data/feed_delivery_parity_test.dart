import 'dart:convert';
import 'dart:io';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('daily projection preserves football card markets and readings', () {
    Map<String, Object?> read(String path) => Map<String, Object?>.from(
      jsonDecode(File(path).readAsStringSync()) as Map,
    );
    final full = SnapshotMatchFeedRepository(
      snapshot: read('test/fixtures/football_calendar_14_days_compact.json'),
    );
    final day = SnapshotMatchFeedRepository(
      snapshot: read('test/fixtures/delivery/football_day.json'),
    );
    for (final card in day.allMatches()) {
      final original = full.allMatches().singleWhere((m) => m.id == card.id);
      expect(card.fixture.homeTeam.id, original.fixture.homeTeam.id);
      expect(card.fixture.awayTeam.id, original.fixture.awayTeam.id);
      expect(card.fixture.score?.home, original.fixture.score?.home);
      expect(card.fixture.score?.away, original.fixture.score?.away);
      expect(
        [
          for (final r in card.analysis.computedReadings)
            [r.id, r.subjectTeamId, r.evidenceLabel, r.evidenceValue],
        ],
        [
          for (final r in original.analysis.computedReadings)
            [r.id, r.subjectTeamId, r.evidenceLabel, r.evidenceValue],
        ],
      );
      expect(
        [
          for (final m in card.availableMarkets)
            [
              m.id,
              for (final s in m.selections) [s.id, s.odds, s.bookmakerId],
            ],
        ],
        [
          for (final m in original.availableMarkets)
            [
              m.id,
              for (final s in m.selections) [s.id, s.odds, s.bookmakerId],
            ],
        ],
      );
      final profile =
          const DecisionProfile(
            onboardingVersion: 'test',
            answers: [],
          ).withOptionIds(
            'readings',
            original.analysis.computedReadings
                .map((r) => r.id)
                .toSet()
                .toList(),
          );
      expect(
        [
          for (final s in day.analyzeFor(profile, card).signals)
            [s.id, s.subjectTeamId, s.summary],
        ],
        [
          for (final s in full.analyzeFor(profile, original).signals)
            [s.id, s.subjectTeamId, s.summary],
        ],
      );
    }
    expect(day.allMatches(), isNotEmpty);
  });
}
