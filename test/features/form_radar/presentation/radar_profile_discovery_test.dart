import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/features/form_radar/presentation/form_radar_signal_panel.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/matches/presentation/matches_home_page.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Radar discovers account readings in unfollowed leagues for players, teams and details',
    (tester) async {
      final repository = _repository();
      final profile = _profile();
      expect(repository.personalizedFor(profile), isEmpty);
      await _pumpHome(tester, repository: repository, profile: profile);
      expect(find.byType(MatchFeedCard), findsNothing);

      await tester.tap(find.text('Radar'));
      await tester.pumpAndSettle();
      _expectAccountReadings(tester);
      expect(find.byType(FormRadarSignalPanel), findsOneWidget);

      await tester.tap(find.text('Équipes'));
      await tester.pumpAndSettle();
      _expectAccountReadings(tester);

      final card = find.byType(MatchFeedCard);
      await tester.ensureVisible(card);
      await tester.tap(card);
      await tester.pumpAndSettle();
      final detail = tester.widget<MatchDetailPage>(
        find.byType(MatchDetailPage),
      );
      expect(detail.match.profileRelevance.readingMatches, 2);
      expect(detail.match.profileRelevance.scenarioMatches, 1);
      expect(detail.selectedReadingIds, ['positive_streak', 'improving_form']);
      expect(detail.selectedScenarioIds, ['positive_series']);
      expect(detail.opportunity?.primaryThesis.id, 'positive_series');

      await tester.tap(find.byTooltip('Retour'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pour moi'));
      await tester.pumpAndSettle();
      expect(find.byType(MatchFeedCard), findsNothing);
      expect(profile.optionIdsFor('competitions'), ['61']);
      expect(repository.personalizedFor(profile), isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Radar updates account reading choices without hiding hot players',
    (tester) async {
      final repository = _repository();
      await _pumpHome(tester, repository: repository, profile: _profile());
      await tester.tap(find.text('Radar'));
      await tester.pumpAndSettle();
      _expectAccountReadings(tester);

      await _pumpHome(
        tester,
        repository: repository,
        profile: _profile()
            .withOptionIds('readings', ['form_gap'])
            .withOptionIds('opportunity_profiles', []),
      );
      final card = tester.widget<MatchFeedCard>(find.byType(MatchFeedCard));
      expect(card.readingMatch?.signals, isEmpty);
      expect(card.readingMatch?.thesis, isNull);
      expect(find.text('Série positive'), findsNothing);
      expect(find.text('Forme'), findsNothing);
      expect(find.byType(FormRadarSignalPanel), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Radar clears personal readings after signing out', (
    tester,
  ) async {
    final repository = _repository();
    final profile = _profile();
    await _pumpHome(tester, repository: repository, profile: profile);
    await tester.tap(find.text('Radar'));
    await tester.pumpAndSettle();
    _expectAccountReadings(tester);

    await _pumpHome(
      tester,
      repository: repository,
      profile: profile,
      identityScope: const IdentityScope.guest('guest'),
    );
    final card = tester.widget<MatchFeedCard>(find.byType(MatchFeedCard));
    expect(card.showReadings, isFalse);
    expect(card.readingMatch, isNull);
    expect(find.text('Série positive'), findsNothing);
    expect(find.text('Forme'), findsNothing);
    expect(find.byType(FormRadarSignalPanel), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

void _expectAccountReadings(WidgetTester tester) {
  final card = tester.widget<MatchFeedCard>(find.byType(MatchFeedCard));
  expect(card.showReadings, isTrue);
  expect(card.readingMatch?.competition.id, '39');
  expect(card.readingMatch?.profileRelevance.readingMatches, 2);
  expect(card.readingMatch?.profileRelevance.scenarioMatches, 1);
  expect(
    card.readingMatch?.signals.map((signal) => signal.id),
    unorderedEquals([
      'positive_streak',
      'improving_form',
      'scenario:positive_series:api-team-1',
    ]),
  );
  expect(find.text('Forme'), findsWidgets);
  expect(find.text('Série positive'), findsOneWidget);
}

Future<void> _pumpHome(
  WidgetTester tester, {
  required MatchFeedRepository repository,
  required DecisionProfile profile,
  IdentityScope identityScope = const IdentityScope.account('account'),
}) async {
  tester.view.physicalSize = const Size(390, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('fr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      theme: CopilotTheme.dark.copyWith(splashFactory: NoSplash.splashFactory),
      home: MatchesHomePage(
        profile: profile,
        identityScope: identityScope,
        ticketStrategies: const [],
        repositoryOverride: repository,
        onEditProfile: () {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

DecisionProfile _profile() => const DecisionProfile(
  onboardingVersion: 'test',
  answers: [
    OnboardingAnswer(questionId: 'competitions', orderedOptionIds: ['61']),
    OnboardingAnswer(
      questionId: 'readings',
      orderedOptionIds: ['positive_streak', 'improving_form'],
    ),
    OnboardingAnswer(
      questionId: 'opportunity_profiles',
      orderedOptionIds: ['positive_series'],
    ),
  ],
);

SnapshotMatchFeedRepository _repository() {
  final now = DateTime.now();
  final kickoff = DateTime(now.year, now.month, now.day, 20);
  return SnapshotMatchFeedRepository(
    snapshot: {
      'schema_version': 2,
      'captured_at': now.toIso8601String(),
      'timezone': 'Europe/Paris',
      'raw': {
        'fixtures': [
          {
            'fixture': {
              'id': 901,
              'date': kickoff.toIso8601String(),
              'status': {'short': 'NS'},
            },
            'league': {
              'id': 39,
              'name': 'Premier League',
              'country': 'England',
              'season': now.year,
            },
            'teams': {
              'home': {'id': 1, 'name': 'Discovery FC'},
              'away': {'id': 2, 'name': 'Opponent FC'},
            },
          },
        ],
        'player_form_radar': [
          {
            'league': {'id': 39},
            'team': {'id': 1, 'name': 'Discovery FC'},
            'player': {'id': 10, 'name': 'Joueur en forme'},
            'activity': [
              for (var i = 1; i <= 3; i++)
                {
                  'fixture_id': 100 + i,
                  'played_at': now
                      .subtract(Duration(days: i))
                      .toIso8601String(),
                  'appeared': true,
                  'starter': true,
                  'minutes': 90,
                  'goals': 1,
                  'assists': 0,
                },
            ],
          },
        ],
        'recent_league_matches': [
          {
            'league': {'id': 39},
            'team': {'id': 1, 'name': 'Discovery FC'},
            'matches': [
              for (var i = 1; i <= 5; i++)
                {
                  'fixture': {
                    'id': 100 + i,
                    'date': now.subtract(Duration(days: i)).toIso8601String(),
                  },
                  'opponent': {'id': 20 + i, 'name': 'Opponent $i'},
                  'venue': 'home',
                  'result': 'W',
                  'goals': {'for': 2, 'against': 0},
                },
            ],
          },
        ],
      },
      'computed': {
        'fixtures': [
          {
            'fixture_id': 901,
            'readings': [
              for (final id in [
                'positive_streak',
                'improving_form',
                'weak_away_team',
              ])
                {
                  'id': id,
                  'side': id == 'weak_away_team' ? 'away' : 'home',
                  'subject_team_id': id == 'weak_away_team'
                      ? 'api-team-2'
                      : 'api-team-1',
                  'sample_size': 5,
                  'evidence': [
                    {'label': 'Lecture confirmée : $id'},
                  ],
                },
            ],
            'scenarios': [
              {
                'id': 'positive_series',
                'side': 'home',
                'subject_team_id': 'api-team-1',
                'required_reading_ids': ['positive_streak', 'improving_form'],
              },
            ],
          },
        ],
      },
    },
  );
}
