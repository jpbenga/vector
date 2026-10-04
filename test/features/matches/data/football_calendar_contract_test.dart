import 'dart:convert';
import 'dart:io';

import 'package:copilot/app/theme/app_theme.dart';
import 'package:copilot/core/config/app_config.dart';
import 'package:copilot/core/config/app_environment.dart';
import 'package:copilot/core/supabase/supabase_initializer.dart';
import 'package:copilot/core/theme/app_theme_controller.dart';
import 'package:copilot/features/matches/data/match_feed_repository_loader.dart';
import 'package:copilot/features/matches/data/supabase_match_feed_snapshot_repository.dart';
import 'package:copilot/features/matches/presentation/widgets/match_feed_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The Deno pipeline regression asserts this entire payload against the actual
// collector, raw builder and compact publisher, using simulated I/O only.
Map<String, Object?> _compact() => Map<String, Object?>.from(
  jsonDecode(
        File(
          'test/fixtures/football_calendar_14_days_compact.json',
        ).readAsStringSync(),
      )
      as Map,
);

class _PublicSnapshot implements MatchFeedSnapshotRemoteDataSource {
  @override
  Future<Map<String, Object?>?> loadLatestForDate(DateTime date) async =>
      _compact();
}

void main() {
  testWidgets(
    'fresh compact snapshot renders a day-14 fixture without bookmaker odds',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final config = AppConfig(
        environment: AppEnvironment.development,
        supabaseUrl: Uri.parse('https://example.test'),
        supabaseAnonKey: 'test-only',
      );
      final loader = MatchFeedRepositoryLoader(
        config: config,
        supabaseInitializer: SupabaseInitializer(config),
        remoteDataSource: _PublicSnapshot(),
        clock: () => DateTime(2030, 10, 4, 12),
      );
      final repository = await loader.load(now: DateTime(2030, 10, 17));
      expect(
        repository.snapshotMetadata!.covers(DateTime(2030, 10, 17)),
        isTrue,
      );
      expect(
        repository.snapshotMetadata!.covers(DateTime(2030, 10, 18)),
        isFalse,
      );
      final matches = repository.allMatches();
      expect(matches, hasLength(13));
      final withoutOdds = matches.singleWhere(
        (match) => match.fixture.apiFootballFixtureId == 13,
      );
      final secondPageOdds = matches.singleWhere(
        (match) => match.fixture.apiFootballFixtureId == 12,
      );
      expect(withoutOdds.hasMatchResultMarket, isFalse);
      expect(secondPageOdds.hasMatchResultMarket, isTrue);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.forVariant(AppThemeVariant.vectorDark),
          home: Scaffold(
            body: SingleChildScrollView(
              child: MatchFeedCard(
                match: withoutOdds,
                onTap: () {},
                radarEntries: const [],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Club 13'), findsOneWidget);
      expect(find.text('Club visiteur'), findsOneWidget);
      expect(find.text('Impossible de charger les rencontres'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
