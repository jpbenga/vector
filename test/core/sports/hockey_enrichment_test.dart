import 'dart:convert';
import 'dart:io';
import 'package:copilot/core/domain/lector_head_to_head_policy.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/published_sport_feed_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/widgets/lector_head_to_head_timeline_panel.dart';
import 'package:copilot/core/widgets/lector_standing_table.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';

Map<String, dynamic> payload() =>
    jsonDecode(
          File(
            'test/fixtures/sports/hockey_enriched_compact.json',
          ).readAsStringSync(),
        )
        as Map<String, dynamic>;
void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  test(
    'legacy NHL captures exclude unnamed preseason and preserve up to 24 independently sampled meetings',
    () {
      final p = payload();
      final snapshot = SportPublicationCodec.decode(p, SportId.hockey);
      final history = snapshot.items.first.headToHead!;
      expect(
        history.meetings
            .where((m) => m.competitionKind == LectorMeetingKind.excluded)
            .length,
        2,
      );
      expect(
        history.meetings
            .where((m) => m.competitionKind == LectorMeetingKind.league)
            .length,
        4,
      );
      final base = p['items'][0]['headToHead']['meetings'][1];
      p['items'][0]['headToHead']['meetings'] = List.generate(24, (i) {
        final copy = jsonDecode(jsonEncode(base)) as Map<String, dynamic>;
        copy['id'] = '${900000 + i}';
        return copy;
      });
      expect(
        SportPublicationCodec.decode(
          p,
          SportId.hockey,
        ).items.first.headToHead!.meetings.length,
        24,
      );
    },
  );
  test(
    'real provider enrichment decodes venue aggregates, independent H2H scopes and period clocks',
    () {
      final snapshot = SportPublicationCodec.decode(payload(), SportId.hockey);
      expect(snapshot.items.length, 3);
      for (final competition in snapshot.competitions) {
        expect(competition.venueStandings, isNotNull);
        for (final r in [
          ...competition.venueStandings!.home,
          ...competition.venueStandings!.away,
        ]) {
          expect(r.wins + r.losses, lessThanOrEqualTo(r.played));
          expect(r.winRate, r.played == 0 ? isNull : inInclusiveRange(0, 1));
        }
      }
      for (final f in snapshot.items) {
        expect(f.headToHead!.meetings, isNotEmpty);
        for (final h in f.headToHead!.meetings) {
          expect(h.fixture.startsAt!.isBefore(f.startsAt!), isTrue);
          expect(h.fixture.scoreFor(SportScoreScope.finalResult), isNotNull);
          for (final e in h.events) {
            final offset = {'P1': 0, 'P2': 20, 'P3': 40, 'OT': 60}[e.period]!;
            expect(e.elapsed, e.minute == null ? null : offset + e.minute!);
          }
        }
      }
    },
  );
  test(
    'public reader rejects crossed pair, future game, event team and invalid venue counts',
    () {
      for (final mutate in <void Function(Map<String, dynamic>)>[
        (p) => (p['items'][0]['headToHead']['meetings'][0]['home'])['id'] =
            'foreign',
        (p) => p['items'][0]['headToHead']['meetings'][0]['startsAt'] =
            '2099-01-01T00:00:00Z',
        (p) =>
            p['items'][0]['headToHead']['meetings'][0]['events'][0]['teamId'] =
                'foreign',
        (p) => p['competitions'][0]['venueStandings']['home'][0]['wins'] = 999,
      ]) {
        final p = payload();
        mutate(p);
        expect(
          () => SportPublicationCodec.decode(p, SportId.hockey),
          throwsFormatException,
        );
      }
    },
  );
  test(
    'standing points, goals and official description survive public decoding; missing goals stay unknown',
    () {
      final p = payload();
      final row = p['competitions'][0]['tables'][0]['rows'][0];
      row['goalsFor'] = 31;
      row['goalsAgainst'] = 20;
      row['description'] = 'Playoffs';
      final originalPoints = row['points'];
      final decoded = SportPublicationCodec.decode(
        p,
        SportId.hockey,
      ).competitions.first.tables.first.rows.first;
      expect(decoded.points, originalPoints);
      expect(decoded.goalsFor, 31);
      expect(decoded.goalsAgainst, 20);
      expect(decoded.description, 'Playoffs');
      row.remove('goalsFor');
      row.remove('goalsAgainst');
      final absent = SportPublicationCodec.decode(
        p,
        SportId.hockey,
      ).competitions.first.tables.first.rows.first;
      expect(absent.goalsFor, isNull);
      expect(absent.goalsAgainst, isNull);
      row['goalsFor'] = -1;
      expect(
        () => SportPublicationCodec.decode(p, SportId.hockey),
        throwsFormatException,
      );
    },
  );
  test('missing provider minute remains absent in the public contract', () {
    final p = payload();
    final e = p['items'][0]['headToHead']['meetings'][0]['events'][0];
    e['minute'] = null;
    e['elapsed'] = null;
    final event = SportPublicationCodec.decode(
      p,
      SportId.hockey,
    ).items.first.headToHead!.meetings.first.events.first;
    expect(event.minute, isNull);
    expect(event.elapsed, isNull);
  });

  test(
    'team history is backward compatible and must match the recent window',
    () {
      final p = payload();
      final row = p['competitions'][1]['tables'][0]['rows'][0] as Map;
      final recent = row['form'] as List;
      expect(recent, isNotEmpty);
      final fallback = SportPublicationCodec.decode(
        p,
        SportId.hockey,
      ).competitions[1].tables.first.rows.first;
      expect(fallback.formHistory, fallback.form);
      final older = Map<String, dynamic>.from(recent.first as Map)
        ..['id'] = 'older'
        ..['startsAt'] = DateTime.parse(
          recent.first['startsAt'] as String,
        ).subtract(const Duration(days: 1)).toIso8601String();
      row['formHistory'] = [older, ...recent];
      final decoded = SportPublicationCodec.decode(
        p,
        SportId.hockey,
      ).competitions[1].tables.first.rows.first;
      expect(decoded.formHistory.length, recent.length + 1);
      expect(decoded.form.length, recent.length);
      row['formHistory'] = [older];
      expect(
        () => SportPublicationCodec.decode(p, SportId.hockey),
        throwsFormatException,
      );
    },
  );
  for (final width in [360.0, 1100.0]) {
    testWidgets(
      'real venue standings and hockey H2H use the shared components at $width',
      (tester) async {
        tester.view.physicalSize = Size(width, 1500);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final snapshot = SportPublicationCodec.decode(
              payload(),
              SportId.hockey,
            ),
            fixture = snapshot.items[1];
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.dark,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HockeyMatchDetailPage(
              fixture: fixture,
              competition: snapshot.competitions[1],
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Classement'));
        await tester.tap(find.text('Classement'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const ValueKey('hockey-standing-scope-1')),
        );
        await tester.tap(find.byKey(const ValueKey('hockey-standing-scope-1')));
        await tester.pumpAndSettle();
        expect(find.byType(LectorStandingTable), findsOneWidget);
        expect(find.text('% V'), findsNothing);
        expect(find.text('Pts'), findsOneWidget);
        expect(
          find.textContaining('points et positions non fournis'),
          findsOneWidget,
        );
        await tester.tap(find.byKey(const ValueKey('hockey-standing-scope-2')));
        await tester.pumpAndSettle();
        expect(find.text('% V'), findsNothing);
        expect(find.text('Pts'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('TAT'));
        await tester.tap(find.text('TAT'));
        await tester.pumpAndSettle();
        expect(find.byType(LectorHeadToHeadTimelinePanel), findsOneWidget);
        expect(find.text('Championnat (0)'), findsOneWidget);
        // KHL capture has no phase metadata: inspect factual history in All.
        await tester.ensureVisible(find.text('Toutes compétitions (6)'));
        await tester.tap(find.text('Toutes compétitions (6)'));
        await tester.pumpAndSettle();
        expect(find.text("60'"), findsOneWidget);
        expect(find.text("90'"), findsNothing);
        expect(find.textContaining(' : Extérieur ·'), findsOneWidget);
        expect(find.textContaining('n’est pas encore inclus'), findsNothing);
        final events = find.textContaining('Voir les événements (');
        expect(events, findsOneWidget);
        await tester.ensureVisible(events);
        await tester.pumpAndSettle();
        await tester.tap(events);
        await tester.pumpAndSettle();
        expect(find.byType(ListTile), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
