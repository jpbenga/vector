// Isolated visual/test fixture. This entry point is never used by lib/main.dart.
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:copilot/features/admin/data/admin_ops_repository.dart';
import 'package:copilot/features/admin/presentation/operations_page.dart';

void main() => runApp(
  MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OperationsPage(repository: OperationsFixtureRepository()),
  ),
);

class OperationsFixtureRepository extends AdminOpsRepository {
  OperationsFixtureRepository()
    : super(
        SupabaseClient(
          'https://preview.invalid',
          'fixture-public-key',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        ),
      );
  final calls = <String>[];
  bool rejectCommands = false;
  bool paused = false;
  final now = DateTime.now();
  @override
  Future<Map<String, dynamic>> operations(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    calls.add(action);
    if (action == 'ops_overview') return overview;
    if (action == 'ops_events') {
      return {
        'ok': true,
        'task': {
          ...tasks.firstWhere((t) => t['id'] == payload['task_id']),
          'stage_results': {
            'sync': {'cachedResponses': 34, 'leagueFixtureRows': 190},
          },
        },
        'events': [
          {
            'kind': 'started',
            'stage': 1,
            'message': 'Étape démarrée',
            'actor': 'worker',
            'created_at': now.toIso8601String(),
          },
          {
            'kind': 'completed',
            'stage': 0,
            'message': 'Étape terminée',
            'actor': 'worker',
            'created_at': now
                .subtract(const Duration(seconds: 40))
                .toIso8601String(),
          },
        ],
      };
    }
    if (rejectCommands) {
      throw const AdminOpsException(
        'Une compétition sélectionnée est déjà en cours',
      );
    }
    if (action == 'ops_pause_cycle') paused = true;
    if (action == 'ops_resume_cycle') paused = false;
    return {'ok': true};
  }

  List<Map<String, dynamic>> get tasks => [
    _task('a', 'Championnat Nord', 'succeeded', 4, 1),
    _task('b', 'Championnat Sud', 'running', 1, 2),
    _task('c', 'Coupe nationale', 'failed', 0, 3),
    _task('d', 'Sélections internationales', 'pending', 0, 4),
  ];
  Map<String, dynamic> _task(
    String id,
    String name,
    String status,
    int stage,
    int league,
  ) => {
    'id': id,
    'cycle_id': 'cycle-a',
    'competition_name': name,
    'league_id': league,
    'job_kind': 'daily',
    'status': status,
    'stage': stage,
    'day': '2026-10-01',
    'started_at': status == 'pending'
        ? null
        : now.subtract(const Duration(minutes: 2)).toIso8601String(),
    'finished_at': status == 'succeeded' || status == 'failed'
        ? now.toIso8601String()
        : null,
    'heartbeat_at': now.toIso8601String(),
    if (status == 'failed') 'error_message': 'API-Football 429: minute_limit',
    'counters': {
      'collectProviderRequests': 18,
      'resultProviderRequests': 5,
      'cachedResponses': 34,
      'leagueFixtureRows': 190,
      'completedFixtures': 8,
      'endpoint': '/fixtures',
    },
    'sample': {
      'fixture_id': 42,
      'home': 'Équipe Nord',
      'away': 'Équipe Sud',
      'competition': name,
      'kickoff': '2026-10-01T18:00:00Z',
      'status': 'FT',
      'goals': {'home': 2, 'away': 1},
    },
  };
  Map<String, dynamic> get overview => {
    'ok': true,
    'selected_cycle_id': 'cycle-a',
    'generated_at': now.toIso8601String(),
    'configured': true,
    'last_tick_at': now.toIso8601String(),
    'scheduling_enabled': true,
    'cycles': [
      {
        'id': 'cycle-a',
        'label': 'Cycle quotidien',
        'actor': 'scheduler',
        'created_at': now.toIso8601String(),
        'paused': paused,
        'total': 4,
        'succeeded': 1,
        'failed': 1,
        'pending': 1,
      },
    ],
    'tasks': tasks,
    'active': [tasks[1]],
    'legacy': <Map<String, dynamic>>[],
    'audit': [
      {
        'actor': 'admin@example.test',
        'message': 'Planification quotidienne activée',
        'created_at': now.toIso8601String(),
      },
    ],
    'budget': {'budget_date': '2026-10-01', 'request_count': 2840},
    'durations': [
      {
        'league_id': 2,
        'job_kind': 'daily',
        'samples': 6,
        'average_seconds': 103,
      },
    ],
    'competitions': [
      for (var i = 0; i < tasks.length; i++)
        {
          'league_id': i + 1,
          'name': tasks[i]['competition_name'],
          'enabled': true,
          'daily_time': '02:00:00',
          'enrichment_enabled': true,
          'enrichment_day': 2,
          'enrichment_time': '04:15:00',
          'enrichment_timezone': 'Europe/Paris',
        },
    ],
  };
}
