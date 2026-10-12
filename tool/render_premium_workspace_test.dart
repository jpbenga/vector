// Actual workspace UI, archived public data, local test account/preferences.
// No authentication, provider collection, model call or remote user write.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/app/sports/sport_workspace_registry.dart';
import 'package:copilot/core/di/service_locator.dart';
import 'package:copilot/core/identity/identity_scope.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/theme/app_theme.dart';
import 'package:copilot/core/widgets/lector_competition_browser.dart';
import 'package:copilot/features/matches/data/match_feed_repository.dart';
import 'package:copilot/features/matches/domain/match_board_item.dart';
import 'package:copilot/features/matches/presentation/matches_home_page.dart';
import 'package:copilot/features/onboarding/domain/decision_profile.dart';
import 'package:copilot/features/onboarding/domain/onboarding_answer.dart';
import 'package:copilot/features/opportunities/domain/opportunity.dart';
import 'package:copilot/features/shortlist/application/shortlist_controller.dart';
import 'package:copilot/features/shortlist/data/shortlist_repository.dart';
import 'package:copilot/features/shortlist/domain/shortlist.dart';
import 'package:copilot/features/sports/presentation/sport_workspace_page.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';

class _ArchivedRepository implements MatchFeedRepository {
  _ArchivedRepository(this.sources);
  final List<MatchFeedRepository> sources;
  @override
  MatchDataSourceMode get mode => sources.first.mode;
  @override
  MatchFeedSnapshotMetadata? get snapshotMetadata => null;
  @override
  List<MatchBoardItem> allMatches() =>
      sources.expand((s) => s.allMatches()).toList();
  @override
  List<MatchBoardItem> personalizedFor(DecisionProfile p) =>
      sources.expand((s) => s.personalizedFor(p)).toList();
  @override
  List<Opportunity> opportunitiesFor(DecisionProfile p) =>
      sources.expand((s) => s.opportunitiesFor(p)).toList();
  @override
  MatchBoardItem analyzeFor(DecisionProfile p, MatchBoardItem match) => sources
      .firstWhere((s) => s.allMatches().any((m) => m.id == match.id))
      .analyzeFor(p, match);
}

class _EmptyPreparation implements ShortlistRepository {
  @override
  Future<ShortlistSnapshot> request(
    String action, {
    String? session,
    ShortlistFixture? fixture,
    DateTime? until,
    int? revision,
  }) async => ShortlistSnapshot({
    'serverNow': DateTime.now().toUtc().toIso8601String(),
    'sessions': <Map<String, Object?>>[],
  });
}

const _profile = DecisionProfile(
  onboardingVersion: 'visual-validation',
  answers: [
    OnboardingAnswer(questionId: 'competitions', orderedOptionIds: ['39', '2']),
    OnboardingAnswer(
      questionId: 'markets',
      orderedOptionIds: ['match_result', 'double_chance'],
    ),
    OnboardingAnswer(
      questionId: 'readings',
      orderedOptionIds: ['declining_form', 'positive_streak', 'form_gap'],
    ),
    OnboardingAnswer(
      questionId: 'opportunity_profiles',
      orderedOptionIds: [
        'solid_favorite',
        'ranking_gap',
        'offensive_match',
        'defensive_match',
        'positive_series',
        'negative_series',
        'prolific_attack',
        'fragile_defense',
      ],
    ),
  ],
);
void main() {
  testWidgets('render integrated For me and All at mobile and tablet sizes', (
    tester,
  ) async {
    await initializeDateFormatting('fr');
    await tester.runAsync(() async {
      await (FontLoader(
        'Inter',
      )..addFont(rootBundle.load('assets/fonts/Inter-variable.ttf'))).load();
      final bytes = await File(
        '/usr/local/share/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
      ).readAsBytes();
      await (FontLoader(
        'MaterialIcons',
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    });
    final repo = _ArchivedRepository([
      for (final name in ['league', 'champions'])
        SnapshotMatchFeedRepository(
          snapshot:
              jsonDecode(
                    File('assets/design_preview/$name.json').readAsStringSync(),
                  )
                  as Map<String, dynamic>,
        ),
    ]);
    final controller = ShortlistController(repository: _EmptyPreparation())
      ..account = 'visual-validation';
    getIt.registerSingleton<ShortlistController>(controller);
    final defaults = SportWorkspaceRegistry.defaults;
    for (final (width, light, scale) in [
      (320.0, false, 1.0),
      (375.0, false, 1.0),
      (390.0, false, 1.0),
      (430.0, false, 1.0),
      (768.0, false, 1.0),
      (320.0, true, 1.5),
    ]) {
      tester.view.physicalSize = Size(width, 1100);
      tester.view.devicePixelRatio = 1;
      final boundary = GlobalKey();
      final registry = SportWorkspaceRegistry([
        for (final entry in defaults.entries)
          SportWorkspaceRegistration(
            definition: entry.definition,
            icon: entry.icon,
            builder: (_) => MatchesHomePage(
              profile: _profile,
              identityScope: const IdentityScope.account('visual-validation'),
              repositoryOverride: repo,
              onEditProfile: () {},
            ),
          ),
      ]);
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            key: ValueKey('$width-$scale'),
            debugShowCheckedModeBanner: false,
            theme: light ? CopilotTheme.light : CopilotTheme.dark,
            locale: const Locale('fr'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: SportWorkspacePage(
              sport: SportId.football,
              registry: registry,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        for (final asset in [
          'assets/brand/ls-logo-mark-clean.png',
          'assets/backgrounds/competition-champions-original-v1.png',
        ]) {
          await precacheImage(AssetImage(asset), boundary.currentContext!);
        }
      });
      for (final (section, date) in [('for-me', '11.10'), ('all', '13.10')]) {
        if (section == 'all') {
          await tester.tap(find.byKey(const ValueKey('workspace-tab-all')));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text(date));
        await tester.tap(find.text(date));
        await tester.pumpAndSettle();
        if (section == 'all') {
          final country = find
              .byWidgetPredicate(
                (w) => w is LectorCompetitionGroup && w.isCountry,
              )
              .first;
          final countryLabel = tester
              .widget<LectorCompetitionGroup>(country)
              .name;
          await tester.ensureVisible(find.text(countryLabel));
          await tester.tap(find.text(countryLabel));
          await tester.pumpAndSettle();
          final competition = find
              .byWidgetPredicate(
                (w) => w is LectorCompetitionGroup && !w.isCountry,
              )
              .first;
          final competitionLabel = tester
              .widget<LectorCompetitionGroup>(competition)
              .name;
          await tester.ensureVisible(find.text(competitionLabel).last);
          await tester.tap(find.text(competitionLabel).last);
          await tester.pumpAndSettle();
        }
        expect(
          tester.takeException(),
          isNull,
          reason: '$section $width $scale',
        );
        await tester.runAsync(() async {
          final bitmap =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final target = File(
            'output/premium-workspaces/$section-${width.toInt()}${scale > 1 ? '-large-text' : ''}.png',
          );
          await target.parent.create(recursive: true);
          await target.writeAsBytes(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }
      await tester.pumpWidget(const SizedBox());
    }
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
    controller.dispose();
    await getIt.reset();
  });
}
