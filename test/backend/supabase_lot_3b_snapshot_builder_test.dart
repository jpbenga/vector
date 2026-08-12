import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Supabase Lot 3B snapshot builder', () {
    late String functionSource;
    late String docs;

    setUpAll(() {
      functionSource = File(
        'supabase/functions/build-match-feed-snapshot/index.ts',
      ).readAsStringSync();
      docs = File('docs/backend-lot-3b-snapshot-builder.md').readAsStringSync();
    });

    test(
      'builds snapshots from the Lot 2 cache without API-Football access',
      () {
        expect(
          functionSource,
          contains('/rest/v1/api_football_cached_responses'),
        );
        expect(functionSource, isNot(contains('API_FOOTBALL_KEY')));
        expect(functionSource, isNot(contains('x-apisports-key')));
        expect(functionSource, isNot(contains('football.api-sports.io')));
        expect(docs, contains('ne lit pas `API_FOOTBALL_KEY`'));
      },
    );

    test('keeps the same server execution guard as the sync function', () {
      expect(functionSource, contains('API_FOOTBALL_SYNC_SECRET'));
      expect(functionSource, contains('request.headers.get("authorization")'));
      expect(functionSource, contains(r'replace(/^Bearer\s+/i'));
      expect(
        functionSource,
        contains('requireEnv("SUPABASE_SERVICE_ROLE_KEY")'),
      );
      expect(docs, contains('--no-verify-jwt'));
    });

    test('preserves the V1 payload consumed by ApiFootballMatchAdapter', () {
      for (final key in [
        'schema_version',
        'source',
        'captured_at',
        'timezone',
        'window_start',
        'window_end',
        'date_window',
        'bookmaker_priority',
        'raw',
      ]) {
        expect(functionSource, contains(key));
      }

      for (final rawKey in [
        'fixtures',
        'odds',
        'standings',
        'team_statistics',
        'recent_league_matches',
        'expected_goals',
        'predictions',
      ]) {
        expect(functionSource, contains(rawKey));
        expect(docs, contains(rawKey));
      }
    });

    test(
      'indexes fixtures with coverage flags for day and league browsing',
      () {
        expect(
          functionSource,
          contains('/rest/v1/match_feed_snapshot_fixtures'),
        );

        for (final field in [
          'fixture_id',
          'api_football_fixture_id',
          'api_football_league_id',
          'fixture_date',
          'kickoff_at',
          'competition_name',
          'country_code',
          'home_team_name',
          'away_team_name',
          'has_odds',
          'has_standings',
          'has_team_statistics',
          'has_recent_form',
          'has_expected_goals',
          'contains_predictions',
        ]) {
          expect(functionSource, contains(field));
        }
      },
    );

    test('derives recent form and expected goals from factual cached rows', () {
      expect(functionSource, contains('rawRecentLeagueMatches'));
      expect(functionSource, contains('rawExpectedGoals'));
      expect(functionSource, contains('normalizeRecentFixturesForTeam'));
      expect(functionSource, contains('expectedGoalsSnapshots'));
      expect(functionSource, contains('endpoint: "/fixtures/statistics"'));
      expect(functionSource, contains('has_recent_form:'));
      expect(functionSource, contains('has_expected_goals:'));
      expect(
        functionSource,
        isNot(contains('endpoint: "/predictions"')),
        reason: 'Predictions remain isolated from factual snapshots.',
      );
    });

    test('stores snapshot provenance for every raw cached response used', () {
      expect(functionSource, contains('/rest/v1/match_feed_snapshot_sources'));
      expect(functionSource, contains('query_hash'));
      expect(functionSource, contains('sync_run_id'));
      expect(functionSource, contains('fetched_at'));
      expect(functionSource, contains('response_status'));
      expect(functionSource, contains('provenanceSummary'));
      expect(docs, contains('match_feed_snapshot_sources'));
    });

    test('is idempotent for the same immutable snapshot identity', () {
      expect(functionSource, contains('findExistingSnapshot'));
      expect(functionSource, contains('reused: true'));
      expect(functionSource, contains('schema_version'));
      expect(functionSource, contains('window_start'));
      expect(functionSource, contains('window_end'));
      expect(functionSource, contains('as_of'));
      expect(
        docs,
        contains('relancer la meme commande et verifier `reused: true`'),
      );
    });

    test('protects build payload size and requires explicit leagues', () {
      expect(functionSource, contains('const maxDays = 7;'));
      expect(functionSource, contains('const maxLeagues = 40;'));
      expect(
        functionSource,
        contains('league_ids must contain at least one API-Football league id'),
      );
      expect(functionSource, contains('Date window cannot exceed'));
    });

    test(
      'documents that front switching and analyzer migration are excluded',
      () {
        expect(
          docs,
          contains('Pas de bascule du front vers la source distante'),
        );
        expect(
          docs,
          contains('Pas de migration du Football Analyzer cote serveur'),
        );
        expect(docs, contains('Pas de collecte de predictions API'));
      },
    );
  });
}
