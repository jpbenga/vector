import 'package:copilot/features/matches/data/match_reading_bilan_repository.dart';
import 'package:copilot/features/matches/presentation/reading_bilan_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeBilanRepository implements MatchReadingBilanRepository {
  _FakeBilanRepository(this.entries);
  final List<MatchReadingBilanEntry> entries;

  @override
  Future<List<MatchReadingBilanSummary>> loadSummary({
    required DateTime since,
  }) async => [
    for (final entry in entries)
      MatchReadingBilanSummary(
        readingId: entry.readingId,
        readingLabel: entry.readingLabel,
        total: 1,
        confirmed: entry.verdict == 'confirmed' ? 1 : 0,
        contradicted: entry.verdict == 'contradicted' ? 1 : 0,
        notEvaluable: entry.verdict == 'not_evaluable' ? 1 : 0,
        contextOnly: entry.verdict == 'context_only' ? 1 : 0,
        pending: entry.verdict == null ? 1 : 0,
      ),
  ];

  @override
  Future<List<MatchReadingBilanEntry>> loadForReading({
    required String readingId,
    required DateTime since,
    String? verdict,
    required int offset,
    required int limit,
  }) async => entries
      .where(
        (entry) =>
            entry.readingId == readingId &&
            (verdict == null || entry.verdict == verdict),
      )
      .skip(offset)
      .take(limit)
      .toList();

  @override
  Future<List<MatchReadingBilanEntry>> loadForFixture(int fixtureId) async =>
      entries.where((entry) => entry.fixtureId == fixtureId).toList();
}

void main() {
  testWidgets('Bilan uses only verifiable readings as its rate denominator', (
    tester,
  ) async {
    final repository = _FakeBilanRepository([
      _entry('over', 'Plus de 2,5 buts', 'confirmed'),
      _entry('btts', 'Les deux équipes marquent', 'contradicted'),
      _entry('form', 'Dynamique positive', 'context_only'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadingBilanSection(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Carte de fiabilité'), findsOneWidget);
    expect(find.text('2 résultats évaluables · 1 confirmés'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Dynamique positive'), findsNothing);
  });

  testWidgets('A reliability bubble opens its reading detail sheet', (
    tester,
  ) async {
    final repository = _FakeBilanRepository([
      _entry('over', 'Plus de 2,5 buts', 'confirmed'),
    ]);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ReadingBilanSection(repository: repository),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('bilan-reading-over')));
    await tester.pumpAndSettle();

    expect(find.text('LECTURE · PERFORMANCE'), findsOneWidget);
    expect(find.text('Comment la lecture est évaluée'), findsOneWidget);
  });
}

MatchReadingBilanEntry _entry(String id, String label, String verdict) =>
    MatchReadingBilanEntry(
      announcementId: id,
      fixtureId: 123,
      kickoffAt: DateTime.utc(2026, 9, 16),
      readingId: id,
      readingLabel: label,
      verdict: verdict,
      explanation: 'Critère figé avant match.',
      announcementKind: 'reading',
      homeTeamName: 'Équipe A',
      awayTeamName: 'Équipe B',
      homeGoals: 2,
      awayGoals: 1,
    );
