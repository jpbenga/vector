import 'package:copilot/features/admin/domain/admin_ops_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AdminOpsOverview', () {
    test('surfaces stale orchestration, bookmaker and odds alerts', () {
      final overview = AdminOpsOverview.fromJson({
        'environment': 'production',
        'generated_at': '2026-09-15T21:00:00Z',
        'jobs': [
          {
            'jobid': 1,
            'jobname': 'api-football-league-164',
            'schedule': '0 2 * * *',
            'active': true,
          },
        ],
        'pipeline_health': [
          {
            'api_football_league_id': 164,
            'league_name': 'Besta deild karla',
            'health_status': 'stale_window',
            'snapshot_fixtures': 4,
            'missing_odds': 2,
            'snapshot_player_statistics': 18,
          },
        ],
        'daily_runs': [
          {
            'id': 'daily-1',
            'status': 'succeeded',
            'league_ids': [164],
            'bookmaker_id': 16,
            'api_request_count': 42,
            'storage_warning_level': 'ok',
            'started_at': '2026-09-06T02:00:00Z',
          },
        ],
        'cron_runs': const [],
        'sync_runs': const [],
        'snapshots': const [],
        'admin_operation_runs': const [],
      });

      expect(overview.totalSnapshotFixtures, 4);
      expect(overview.totalFixturesWithOdds, 2);
      expect(overview.totalMissingOdds, 2);
      expect(overview.totalPlayerStatistics, 18);
      expect(
        overview.alerts.map((alert) => alert.title),
        containsAll([
          'Orchestration quotidienne interrompue',
          'Collecte de cotes filtrée',
          '1 compétition(s) à vérifier',
          '2 rencontre(s) sans cote',
        ]),
      );
    });

    test('reports no active alert when the pipeline is healthy', () {
      final overview = AdminOpsOverview.fromJson({
        'environment': 'production',
        'generated_at': '2026-09-15T21:00:00Z',
        'jobs': [
          {
            'jobid': 1,
            'jobname': 'api-football-league-61',
            'schedule': '0 0 * * *',
            'active': true,
          },
        ],
        'pipeline_health': [
          {
            'api_football_league_id': 61,
            'league_name': 'Ligue 1',
            'health_status': 'ok',
            'snapshot_fixtures': 3,
            'missing_odds': 0,
          },
        ],
        'daily_runs': [
          {
            'id': 'daily-2',
            'status': 'succeeded',
            'league_ids': [61],
            'api_request_count': 20,
            'storage_warning_level': 'ok',
            'started_at': '2026-09-15T02:00:00Z',
          },
        ],
        'cron_runs': const [],
        'sync_runs': const [],
        'snapshots': const [],
        'admin_operation_runs': const [],
      });

      expect(overview.alerts, hasLength(1));
      expect(overview.alerts.single.severity, AdminAlertSeverity.info);
      expect(overview.alerts.single.title, 'Aucune alerte active');
    });
  });

  test('pipeline health explains provider failures', () {
    final health = AdminPipelineHealth.fromJson({
      'api_football_league_id': 164,
      'league_name': 'Besta deild karla',
      'health_status': 'sync_not_succeeded',
      'sync_error_message': 'API-Football quota exceeded',
    });

    expect(health.explanation, 'API-Football quota exceeded');
  });
}
