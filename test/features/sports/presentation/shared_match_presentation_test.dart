import '../../../fixtures/sports/hockey_readings_fixture.dart';
import 'package:copilot/core/widgets/lector_match_form_view.dart';
import 'package:copilot/core/widgets/lector_match_insights.dart';
import 'package:copilot/features/hockey/presentation/hockey_player_radar_panel.dart';
import 'package:copilot/features/hockey/domain/hockey_player_radar.dart';
import 'package:copilot/core/widgets/lector_player_radar.dart';
import 'package:copilot/core/widgets/lector_form_radar_signal_panel.dart';
import 'package:copilot/core/widgets/lector_head_to_head_timeline_panel.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/sports/domain/sport_policy.dart';
import 'package:copilot/core/sports/presentation/sport_fixture_card.dart';
import 'package:copilot/core/widgets/lector_match_card.dart';
import 'package:copilot/core/widgets/lector_match_detail_view.dart';
import 'package:copilot/core/widgets/lector_match_hero_view.dart';
import 'package:copilot/features/appearance/data/appearance_preview_fixture.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/features/matches/presentation/match_detail_page.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  final hockey = SportPublicationCodec.decode(
    jsonDecode(File('test/fixtures/sports/nhl_compact.json').readAsStringSync())
        as Map<String, dynamic>,
    SportId.hockey,
  ).items.single;
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'hockey match card previews the three hottest players and expands at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = SportPublicationCodec.decode(
          jsonDecode(
                File(
                  'test/fixtures/sports/hockey_players_compact.json',
                ).readAsStringSync(),
              )
              as Map<String, dynamic>,
          SportId.hockey,
        );
        final ranked = HockeyPlayerRadarRanker.rank(
          snapshot.players.reversed,
          before: snapshot.capturedAt,
        );
        // Build a test opposition using the teams of the collected players.
        // The calendar fixture in this sample belongs to two other teams.
        final home = ranked.first.profile.team;
        final away = ranked
            .firstWhere((e) => e.profile.team.id != home.id)
            .profile
            .team;
        final base = snapshot.items.first;
        final fixture = SportFixture(
          id: base.id,
          competition: ranked.first.profile.competition,
          competitionName: base.competitionName,
          season: base.season,
          home: home,
          away: away,
          startsAt: base.startsAt,
          status: base.status,
        );
        final entries = ranked
            .where(
              (e) =>
                  e.profile.competition == fixture.competition &&
                  (e.profile.team.id == fixture.home.id ||
                      e.profile.team.id == fixture.away.id),
            )
            .toList();
        expect(entries.length, greaterThan(3));
        var navigations = 0;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            home: Scaffold(
              body: SingleChildScrollView(
                child: SportFixtureCard(
                  fixture: fixture,
                  order: SportParticipantOrder.awayHome,
                  contextPanel: HockeyPlayerSignalPanel(entries: entries),
                  onTap: () => navigations++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(LectorFormRadarSignalRow), findsNWidgets(3));
        for (final entry in entries.take(3)) {
          expect(find.text(entry.profile.name), findsOneWidget);
        }
        expect(find.text(entries[3].profile.name), findsNothing);
        final expand = find.text('Voir les ${entries.length} joueurs');
        await tester.ensureVisible(expand);
        await tester.tap(expand);
        await tester.pumpAndSettle();
        expect(
          find.byType(LectorFormRadarSignalRow),
          findsNWidgets(entries.length),
        );
        for (final entry in entries) {
          expect(find.text(entry.profile.name), findsOneWidget);
        }
        await tester.ensureVisible(find.text('Réduire la liste'));
        await tester.tap(find.text('Réduire la liste'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorFormRadarSignalRow), findsNWidgets(3));
        expect(navigations, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'real hockey form uses the same embedded Radar rows and compact cells',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final snapshot = SportPublicationCodec.decode(
        jsonDecode(
              File(
                'test/fixtures/sports/hockey_players_compact.json',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>,
        SportId.hockey,
      );
      final fixture = snapshot.items.firstWhere(
        (f) => f.homeForm.isNotEmpty && f.awayForm.isNotEmpty,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SportFixtureCard(
              fixture: fixture,
              order: SportParticipantOrder.awayHome,
              contextPanel: HockeyPlayerSignalPanel(
                entries: HockeyPlayerRadarRanker.rank(
                  snapshot.players,
                  before: snapshot.capturedAt,
                ).take(2).toList(),
              ),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(LectorFormRadarSignalPanel), findsOneWidget);
      expect(find.byType(LectorFormRadarSignalRow), findsNWidgets(2));
      expect(find.byType(LectorPlayerActivityMatrix), findsNWidgets(2));
      expect(find.text('Signaux Form Radar'), findsOneWidget);
      expect(find.text('3 récents'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'shared form respects NHL two-point and Swedish three-point rules',
    (tester) async {
      for (final (league, maximum) in [('57', 10), ('47', 15)]) {
        await tester.pumpWidget(
          MaterialApp(
            key: UniqueKey(),
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HockeyMatchDetailPage(
              fixture: hockeyReadingFixture(league: league),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Forme'));
        await tester.tap(find.text('Forme'));
        await tester.pumpAndSettle();
        final form = tester.widget<LectorMatchFormView>(
          find.byType(LectorMatchFormView),
        );
        expect(form.data.first.summary.maximumPoints, maximum);
        expect(form.data.second.summary.maximumPoints, maximum);
        expect(find.text('FORME RÉCENTE'), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    },
  );
  for (final width in [360.0, 1100.0]) {
    testWidgets('football and hockey use the complete shared card at $width', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: SingleChildScrollView(
              child: Column(
                children: [
                  MatchFeedCard(
                    match: appearancePreviewMatch,
                    onTap: () => taps++,
                  ),
                  SportFixtureCard(
                    fixture: hockey,
                    order: SportParticipantOrder.awayHome,
                    onTap: () => taps++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The old implementation only shared the surrounding frame. Require the
      // full component and its teams/layout/action to prevent that regression.
      expect(find.byType(LectorMatchCard), findsNWidgets(2));
      expect(find.byType(LectorMatchTeams), findsNWidgets(2));
      for (final action
          in find.byTooltip('Voir l’analyse').evaluate().toList()) {
        final target = find.byWidget(action.widget);
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
      }
      expect(taps, 2);
      expect(tester.takeException(), isNull);
    });
    testWidgets(
      'both sports use the same detail page, hero and tabs at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1200);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final page in [
          MatchDetailPage(match: appearancePreviewMatch),
          HockeyMatchDetailPage(fixture: hockey),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              key: UniqueKey(),
              theme: AppTheme.dark,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: page,
            ),
          );
          await tester.pumpAndSettle();
          expect(find.byType(LectorMatchDetailView), findsOneWidget);
          expect(find.byType(LectorMatchHeroView), findsOneWidget);
          final hero = tester.widget<LectorMatchHeroView>(
            find.byType(LectorMatchHeroView),
          );
          expect(
            hero.backgroundAsset,
            page is HockeyMatchDetailPage
                ? 'assets/backgrounds/match-card-hockey-arena-premium.png'
                : 'assets/backgrounds/match-card-stadium-premium.png',
          );
          expect(find.byType(LectorMatchTopBar), findsOneWidget);
          expect(find.byType(BottomSheet), findsNothing);
          for (final label in ['Contexte', 'Classement', 'Forme', 'TAT']) {
            await tester.ensureVisible(find.text(label));
            await tester.tap(find.text(label));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            if (label == 'Contexte') {
              expect(find.byType(LectorMatchContextView), findsOneWidget);
            }
            if (label == 'Forme') {
              expect(find.byType(LectorMatchFormView), findsOneWidget);
            }
          }
          expect(find.byType(LectorHeadToHeadTimelinePanel), findsOneWidget);
        }
      },
    );
  }
}
