import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_compact_match_card.dart';
import 'package:copilot/core/widgets/lector_reading_pill.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/compact_football_match_adapter.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const evidenceThesis = MatchThesis(
  id: 'ranking_gap',
  title: 'Avantage classement',
  summary: 'Résumé brut du classement',
  status: MatchThesisStatus.watchlist,
  confidence: 0,
  supportingEvidence: [],
  limits: [],
  profileReasons: [],
  arguments: [
    CopilotArgument(
      id: 'structural_level_gap',
      type: CopilotArgumentType.rankingGap,
      family: CopilotArgumentFamily.hierarchy,
      severity: CopilotArgumentSeverity.strong,
      subjectName: 'Madrid',
      parameters: {},
      evidence: [],
      evidenceAction: CopilotEvidenceAction.standings,
    ),
  ],
);
const selectedForm = MatchSignal(
  id: 'positive_streak',
  title: 'Dynamique positive',
  summary: 'Dynamique choisie',
  proofs: [],
);
void main() {
  test(
    'Unselected thesis arguments do not add badges or inflate the configured count',
    () {
      final m = appearancePreviewMatch.copyWith(
        signals: [selectedForm],
        thesis: evidenceThesis,
        profileRelevance: const MatchProfileRelevance(readingMatches: 1),
      );
      final card = compactFootballMatch(
        match: m,
        analyzedMatch: m,
        showReadings: true,
      );
      expect(card.readings.map((r) => r.id), ['positive_streak']);
      expect(card.readingCount, 1);
      expect(publishedMatchCardReadings(m).map((r) => r.label), ['Forme']);
      final scenarioOnly = m.copyWith(
        signals: const [
          MatchSignal(
            id: 'scenario:ranking_gap:home',
            title: 'Écarts de niveau',
            summary: 'Scénario choisi',
            proofs: ['structural_level_gap'],
          ),
        ],
        profileRelevance: const MatchProfileRelevance(scenarioMatches: 1),
      );
      final scenarioCard = compactFootballMatch(
        match: scenarioOnly,
        showReadings: true,
      );
      expect(scenarioCard.readings, isEmpty);
      expect(scenarioCard.readingCount, isNull);
      expect(scenarioCard.signals.single.label, 'Écarts de niveau');
      final removed = m.copyWith(
        profileStatus: MatchProfileStatus.outOfProfile,
      );
      expect(
        compactFootballMatch(match: removed, showReadings: true).readings,
        isEmpty,
      );
      expect(publishedMatchCardScenarios(removed), isEmpty);
      expect(publishedMatchCardReadingCount(removed), 0);
    },
  );
  test(
    'Real repository personalization keeps only configured readings across all detected evidence',
    () {
      final raw =
          jsonDecode(
                File('assets/design_preview/league.json').readAsStringSync(),
              )
              as Map<String, dynamic>;
      final repo = SnapshotMatchFeedRepository(snapshot: raw);
      final source = repo.allMatches().single;
      expect(source.analysis.computedReadings, isNotEmpty);
      DecisionProfile profile(List<String> readings) => DecisionProfile(
        onboardingVersion: 'test',
        answers: [
          OnboardingAnswer(
            questionId: 'competitions',
            orderedOptionIds: [source.competition.id],
          ),
          OnboardingAnswer(questionId: 'readings', orderedOptionIds: readings),
        ],
      );
      for (final chosen in [
        <String>[],
        ['positive_streak'],
        ['declining_form'],
      ]) {
        final personalized = repo.analyzeFor(profile(chosen), source);
        final card = compactFootballMatch(
          match: source,
          analyzedMatch: personalized,
          showReadings: true,
        );
        expect(card.readings.every((r) => chosen.contains(r.id)), isTrue);
        if (chosen.isNotEmpty) {
          expect(card.readings, isNotEmpty);
          expect(card.readingCount, greaterThan(0));
        }
        if (chosen.isEmpty) {
          expect(card.readings, isEmpty);
          expect(card.signals, isEmpty);
          expect(card.readingCount, isNull);
        }
      }
      expect(
        compactFootballMatch(match: source, showReadings: true).readings,
        isEmpty,
      );
    },
  );
  testWidgets(
    'Raw player Radar signals require the selected player reading on cards',
    (tester) async {
      Future<void> render(List<MatchSignal> signals, bool allowed) =>
          tester.pumpWidget(
            MaterialApp(
              theme: CopilotTheme.dark,
              home: Scaffold(
                body: MatchFeedCard(
                  match: appearancePreviewMatch.copyWith(signals: signals),
                  showReadings: allowed,
                  radarEntries: appearancePreviewPlayers,
                  onTap: () {},
                ),
              ),
            ),
          );
      await render([selectedForm], true);
      await tester.pumpAndSettle();
      expect(find.text('Signaux Form Radar'), findsNothing);
      const player = MatchSignal(
        id: 'standout_decisive_player',
        title: 'Joueurs décisifs',
        summary: '',
        proofs: [],
      );
      await render([selectedForm, player], true);
      await tester.pumpAndSettle();
      expect(find.text('Signaux Form Radar'), findsOneWidget);
      await render([selectedForm, player], false);
      await tester.pumpAndSettle();
      expect(find.text('Signaux Form Radar'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Reading badges hug their text and wrap without stretching beside odds',
    (tester) async {
      for (final width in [320.0, 375.0, 390.0, 430.0, 768.0]) {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        for (final signal in [
          selectedForm,
          const MatchSignal(
            id: 'structural_level_gap',
            title: 'Écart de niveau structurel',
            summary: '',
            proofs: [],
          ),
        ]) {
          final m = appearancePreviewMatch.copyWith(signals: [signal]);
          await tester.pumpWidget(
            MaterialApp(
              theme: CopilotTheme.dark,
              home: Scaffold(
                body: LectorCompactMatchCard(
                  data: compactFootballMatch(match: m, showReadings: true),
                  onOpen: () {},
                  preparationAction: const SizedBox.shrink(),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final pill = find.byType(LectorReadingPill);
          expect(pill, findsOneWidget);
          final label = tester.widget<LectorReadingPill>(pill).label;
          expect(
            tester.getSize(pill).width,
            lessThan(tester.getSize(find.text(label)).width + 40),
          );
          expect(tester.getSize(pill).width, lessThan(width * .65));
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
