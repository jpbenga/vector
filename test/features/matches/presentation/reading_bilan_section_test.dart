import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/matches/data/match_reading_bilan_repository.dart';
import 'package:copilot/features/matches/domain/reading_bilan_analysis.dart';
import 'package:copilot/features/matches/presentation/reading_bilan_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'Bilan lists every reading and excludes pending/context from the rate ($dark)',
      (tester) async {
        final repository = _FakeBilanRepository([
          _entry(1, 'positive_streak', 'Dynamique positive', 'confirmed'),
          _entry(
            2,
            'positive_streak',
            'Dynamique positive',
            'contradicted',
            league: 39,
          ),
          _entry(3, 'positive_streak', 'Dynamique positive', null),
          _entry(4, 'strong_home_team', 'Solide à domicile', 'confirmed'),
          _entry(5, 'strong_home_team', 'Solide à domicile', 'not_evaluable'),
          _entry(
            6,
            'ranking_superiority',
            'Supériorité au classement',
            'context_only',
            rule: null,
          ),
        ]);
        await _pump(tester, repository, dark: dark);
        expect(find.text('Carte de fiabilité'), findsNothing);
        expect(find.text('Fiabilité observée'), findsNothing);
        expect(
          find.text('2 confirmées sur 3 annonces évaluées'),
          findsOneWidget,
        );
        expect(find.text('67 %'), findsOneWidget);
        expect(find.text('Dynamique positive'), findsOneWidget);
        expect(find.text('Solide à domicile'), findsOneWidget);
        expect(find.text('Supériorité au classement'), findsOneWidget);
        expect(find.text('7 jours'), findsOneWidget);
        expect(find.text('30 jours'), findsOneWidget);
        expect(find.text('90 jours'), findsOneWidget);
        expect(find.text('1 sans règle de résultat'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Bilan crosses league, context and period with the same reading counts',
    (tester) async {
      final repository = _FakeBilanRepository([
        _entry(1, 'positive_streak', 'Dynamique positive', 'confirmed'),
        _entry(
          2,
          'positive_streak',
          'Dynamique positive',
          'contradicted',
          league: 39,
        ),
        _entry(
          3,
          'weak_away_team',
          'Fragile à l’extérieur',
          'confirmed',
          league: 39,
          side: 'away',
        ),
      ]);
      await _pump(tester, repository);
      await tester.ensureVisible(find.text('Par championnat'));
      await tester.tap(find.text('Par championnat'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('bilan-league-39')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('bilan-league-39')));
      await tester.tap(find.byKey(const ValueKey('bilan-league-39')));
      await tester.pumpAndSettle();
      expect(find.text('1 confirmées sur 2 annonces évaluées'), findsOneWidget);
      expect(find.text('Fragile à l’extérieur'), findsOneWidget);

      final contextFilter = find.byType(DropdownButton<String>);
      await tester.ensureVisible(contextFilter);
      await tester.tap(contextFilter);
      await tester.pumpAndSettle();
      await tester.tap(find.text('À domicile').last);
      await tester.pumpAndSettle();
      expect(repository.lastSubjectSide, 'home');
      expect(find.text('0 confirmées sur 1 annonces évaluées'), findsOneWidget);
      expect(find.text('Fragile à l’extérieur'), findsNothing);
      await tester.ensureVisible(find.text('7 jours'));
      await tester.tap(find.text('7 jours'));
      await tester.pumpAndSettle();
      expect(repository.lastUntil!.difference(repository.lastSince!).inDays, 7);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reading sheet shows fixture names, scores, rules and real pagination',
    (tester) async {
      final repository = _FakeBilanRepository([
        for (var i = 1; i <= 13; i++)
          _entry(
            i,
            'positive_streak',
            'Dynamique positive',
            i == 2 ? null : 'confirmed',
          ),
      ]);
      await _pump(tester, repository);
      final reading = find.byKey(
        const ValueKey('bilan-reading-positive_streak'),
      );
      await tester.ensureVisible(reading);
      await tester.tap(reading);
      await tester.pumpAndSettle();
      expect(find.text('LECTURE · RÉSULTATS'), findsOneWidget);
      expect(find.text('Comment la lecture est évaluée'), findsOneWidget);
      expect(repository.offsets, [0]);
      expect(repository.lastLimit, 11);
      await _scrollSheetTo(tester, find.byType(ReadingVerdictCard));
      expect(find.byType(ReadingVerdictCard), findsNWidgets(10));
      expect(find.text('Club 1 – Adversaire 1'), findsOneWidget);
      expect(find.text('Club 2 – Adversaire 2'), findsOneWidget);
      expect(find.text('Score final non disponible'), findsOneWidget);
      expect(find.text('2 – 1'), findsWidgets);
      expect(
        find.text('Critère : L’équipe concernée gagne ou fait match nul.'),
        findsWidgets,
      );
      expect(find.text('Match 1'), findsNothing);

      final next = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byTooltip('Page suivante'),
      );
      await _scrollSheetTo(tester, next);
      expect(next.hitTestable(), findsOneWidget);
      await tester.tap(next.hitTestable());
      await tester.pumpAndSettle();
      expect(repository.offsets, [0, 10]);
      expect(find.byType(ReadingVerdictCard), findsNWidgets(3));
      expect(find.text('Club 11 – Adversaire 11'), findsOneWidget);
      expect(find.text('Club 1 – Adversaire 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Sheet filters preserve the selected competition and away context',
    (tester) async {
      final repository = _FakeBilanRepository([
        _entry(
          1,
          'weak_away_team',
          'Fragile à l’extérieur',
          'contradicted',
          league: 39,
          side: 'away',
          rule: 'team_loss',
        ),
      ]);
      await _pump(tester, repository);
      await tester.tap(find.byType(DropdownButton<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Premier League').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('À l’extérieur').last);
      await tester.pumpAndSettle();
      final reading = find.byKey(
        const ValueKey('bilan-reading-weak_away_team'),
      );
      await tester.ensureVisible(reading);
      await tester.tap(reading);
      await tester.pumpAndSettle();
      expect(repository.lastLeagueId, 39);
      expect(repository.lastReadingSide, 'away');
      final verdictFilter = find.descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(DropdownButton<String>),
      );
      await _scrollSheetTo(tester, verdictFilter);
      await tester.tap(verdictFilter.hitTestable());
      await tester.pumpAndSettle();
      await tester.tap(find.text('En attente').last);
      await tester.pumpAndSettle();
      expect(repository.lastVerdict, 'pending');
      expect(repository.lastLeagueId, 39);
      expect(repository.lastReadingSide, 'away');
      expect(find.text('Aucune annonce pour ce filtre.'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Global percentages are weighted by evaluated announcements', () {
    final summary = combineBilanSummaries(
      [
        const MatchReadingBilanSummary(
          readingId: 'form',
          readingLabel: 'Forme',
          total: 1,
          confirmed: 1,
          contradicted: 0,
          notEvaluable: 0,
          contextOnly: 0,
          pending: 0,
          confirmationRate: 100,
        ),
        const MatchReadingBilanSummary(
          readingId: 'form',
          readingLabel: 'Forme',
          total: 12,
          confirmed: 0,
          contradicted: 9,
          notEvaluable: 1,
          contextOnly: 1,
          pending: 1,
          confirmationRate: 0,
        ),
      ],
      id: 'form',
      label: 'Forme',
    );
    expect(summary.total, 13);
    expect(summary.evaluable, 10);
    expect(summary.confirmationPercent, 10);
    expect(summary.pending, 1);
    expect(summary.contextOnly, 1);
    expect(summary.notEvaluable, 1);
  });
}

Future<void> _scrollSheetTo(WidgetTester tester, Finder target) async {
  final sheetList = find.descendant(
    of: find.byType(DraggableScrollableSheet),
    matching: find.byType(ListView),
  );
  for (var drag = 0; drag < 20; drag++) {
    if (target.evaluate().isNotEmpty &&
        target.hitTestable().evaluate().isNotEmpty) {
      return;
    }
    await tester.drag(sheetList, const Offset(0, -400));
    await tester.pumpAndSettle();
  }
  expect(target.hitTestable(), findsWidgets);
}

Future<void> _pump(
  WidgetTester tester,
  _FakeBilanRepository repository, {
  bool dark = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? CopilotTheme.dark : CopilotTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ReadingBilanSection(repository: repository),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _FakeBilanRepository implements MatchReadingBilanRepository {
  _FakeBilanRepository(this.entries);
  final List<MatchReadingBilanEntry> entries;
  DateTime? lastSince;
  DateTime? lastUntil;
  String? lastSubjectSide;
  String? lastReadingSide;
  String? lastVerdict;
  int? lastLeagueId;
  int? lastLimit;
  final List<int> offsets = [];

  @override
  Future<List<MatchReadingBilanSummary>> loadSummary({
    required DateTime since,
  }) => loadBreakdown(since: since, until: DateTime.now());

  @override
  Future<List<MatchReadingBilanSummary>> loadBreakdown({
    required DateTime since,
    required DateTime until,
    String? subjectSide,
  }) async {
    lastSince = since;
    lastUntil = until;
    lastSubjectSide = subjectSide;
    final groups = <String, List<MatchReadingBilanEntry>>{};
    for (final entry in entries.where(
      (e) =>
          !e.kickoffAt.isBefore(since) &&
          !e.kickoffAt.isAfter(until) &&
          (subjectSide == null || e.subjectSide == subjectSide),
    )) {
      groups
          .putIfAbsent('${entry.readingId}:${entry.leagueId}', () => [])
          .add(entry);
    }
    return [
      for (final group in groups.values)
        MatchReadingBilanSummary(
          readingId: group.first.readingId,
          readingLabel: group.first.readingLabel,
          leagueId: group.first.leagueId,
          competitionName: group.first.competitionName,
          total: group.length,
          confirmed: group.where((e) => e.verdict == 'confirmed').length,
          contradicted: group.where((e) => e.verdict == 'contradicted').length,
          notEvaluable: group.where((e) => e.verdict == 'not_evaluable').length,
          contextOnly: group.where((e) => e.verdict == 'context_only').length,
          pending: group.where((e) => e.verdict == null).length,
          outcomeRules: {
            for (final e in group)
              if (e.outcomeRule != null) e.outcomeRule!,
          }.toList(),
        ),
    ];
  }

  @override
  Future<List<MatchReadingBilanEntry>> loadForReading({
    required String readingId,
    required DateTime since,
    DateTime? until,
    String? verdict,
    required int offset,
    required int limit,
    int? leagueId,
    String? subjectSide,
  }) async {
    offsets.add(offset);
    lastLimit = limit;
    lastLeagueId = leagueId;
    lastReadingSide = subjectSide;
    lastVerdict = verdict;
    return entries
        .where(
          (e) =>
              e.readingId == readingId &&
              !e.kickoffAt.isBefore(since) &&
              (until == null || !e.kickoffAt.isAfter(until)) &&
              (leagueId == null || leagueId == e.leagueId) &&
              (subjectSide == null || e.subjectSide == subjectSide) &&
              (verdict == null ||
                  (verdict == 'pending'
                      ? e.verdict == null
                      : e.verdict == verdict)),
        )
        .skip(offset)
        .take(limit)
        .toList();
  }

  @override
  Future<List<MatchReadingBilanEntry>> loadForFixture(int fixtureId) async =>
      entries.where((e) => e.fixtureId == fixtureId).toList();
}

MatchReadingBilanEntry _entry(
  int fixtureId,
  String id,
  String label,
  String? verdict, {
  int league = 61,
  String side = 'home',
  String? rule = 'team_not_lose',
}) => MatchReadingBilanEntry(
  announcementId: '$fixtureId-$id',
  fixtureId: fixtureId,
  kickoffAt: DateTime.now().subtract(const Duration(days: 1)),
  readingId: id,
  readingLabel: label,
  verdict: verdict,
  explanation: 'Critère figé avant match.',
  announcementKind: 'reading',
  leagueId: league,
  competitionName: league == 61 ? 'Ligue 1' : 'Premier League',
  homeTeamName: 'Club $fixtureId',
  awayTeamName: 'Adversaire $fixtureId',
  subjectSide: side,
  outcomeRule: rule,
  homeGoals: verdict == null ? null : 2,
  awayGoals: verdict == null ? null : 1,
);
