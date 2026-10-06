import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/sports/data/sport_live_repository.dart';
import 'package:copilot/core/sports/domain/sport.dart';
import 'package:copilot/core/sports/domain/sport_fixture.dart';
import 'package:copilot/core/widgets/lector_live_badge.dart';
import 'package:copilot/core/widgets/lector_match_hero_view.dart';
import 'package:copilot/features/hockey/presentation/hockey_match_detail_page.dart';
import 'package:copilot/l10n/generated/app_localizations.dart';
import '../../../fixtures/sports/hockey_readings_fixture.dart';

void main() {
  setUpAll(() => initializeDateFormatting('fr'));
  testWidgets(
    'an opened hockey detail receives live then final score with correct away/home order',
    (tester) async {
      final base = hockeyReadingFixture();
      final repo = _Scores();
      final controller = SportLiveController(
        sport: SportId.hockey,
        repository: repo,
      );
      controller.watch([base]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: HockeyMatchDetailPage(
            fixture: base,
            liveController: controller,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<LectorMatchHeroView>(find.byType(LectorMatchHeroView))
            .match
            .isLive,
        isFalse,
      );
      SportFixture update(SportFixtureStatus status) => SportFixture(
        id: base.id,
        competition: base.competition,
        competitionName: base.competitionName,
        season: base.season,
        home: base.home,
        away: base.away,
        startsAt: base.startsAt,
        status: status,
        capturedAt: DateTime.now(),
        providerStatus: status == SportFixtureStatus.live ? 'P3' : 'FT',
        scores: {
          SportScoreScope(
            status == SportFixtureStatus.live ? 'current' : 'final',
          ): SportScore(
            home: 2,
            away: 5,
          ),
        },
      );
      repo.rows = [update(SportFixtureStatus.live)];
      await controller.refresh();
      await tester.pumpAndSettle();
      var hero = tester
          .widget<LectorMatchHeroView>(find.byType(LectorMatchHeroView))
          .match;
      expect(hero.isLive, isTrue);
      expect(hero.scoreLabel, '5 - 2');
      expect(hero.firstTeam.role, 'Extérieur');
      expect(hero.secondTeam.role, 'Domicile');
      expect(find.byType(LectorLiveBadge), findsWidgets);
      repo.rows = [update(SportFixtureStatus.finished)];
      await controller.refresh();
      await tester.pumpAndSettle();
      hero = tester
          .widget<LectorMatchHeroView>(find.byType(LectorMatchHeroView))
          .match;
      expect(hero.isFinished, isTrue);
      expect(hero.scoreLabel, '5 - 2');
      expect(hero.isLive, isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}

class _Scores implements SportLiveRepository {
  List<SportFixture> rows = [];
  @override
  Future<List<SportFixture>> load(SportId sport, Set<String> ids) async => rows;
}
