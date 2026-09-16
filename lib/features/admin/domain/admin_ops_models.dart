class AdminOpsOverview {
  const AdminOpsOverview({
    required this.environment,
    required this.generatedAt,
    required this.jobs,
    required this.cronRuns,
    required this.pipelineHealth,
    required this.dailyRuns,
    required this.syncRuns,
    required this.snapshots,
    required this.adminOperationRuns,
  });

  final String environment;
  final DateTime? generatedAt;
  final List<AdminCronJob> jobs;
  final List<AdminCronRun> cronRuns;
  final List<AdminPipelineHealth> pipelineHealth;
  final List<AdminDailyRun> dailyRuns;
  final List<AdminSyncRun> syncRuns;
  final List<AdminSnapshotRun> snapshots;
  final List<AdminOperationRun> adminOperationRuns;

  factory AdminOpsOverview.fromJson(Map<String, Object?> json) {
    return AdminOpsOverview(
      environment: _string(json['environment']) ?? 'unknown',
      generatedAt: _dateTime(json['generated_at']),
      jobs: _list(json['jobs']).map(AdminCronJob.fromJson).toList(),
      cronRuns: _list(json['cron_runs']).map(AdminCronRun.fromJson).toList(),
      pipelineHealth: _list(
        json['pipeline_health'],
      ).map(AdminPipelineHealth.fromJson).toList(),
      dailyRuns: _list(json['daily_runs']).map(AdminDailyRun.fromJson).toList(),
      syncRuns: _list(json['sync_runs']).map(AdminSyncRun.fromJson).toList(),
      snapshots: _list(
        json['snapshots'],
      ).map(AdminSnapshotRun.fromJson).toList(),
      adminOperationRuns: _list(
        json['admin_operation_runs'],
      ).map(AdminOperationRun.fromJson).toList(),
    );
  }

  int get failedCronRuns =>
      cronRuns.where((run) => run.status != 'succeeded').length;

  int get unhealthyLeagues =>
      pipelineHealth.where((row) => row.healthStatus != 'ok').length;

  int get activeJobs => jobs.where((job) => job.active).length;

  int get runningCronRuns => cronRuns.where((run) => run.isRunning).length;

  Iterable<AdminCronRun> get failedRecentCronRuns =>
      cronRuns.where((run) => run.isFailure);

  int get expectedJobs => pipelineHealth.length;

  int get totalSnapshotFixtures => pipelineHealth.fold(
    0,
    (total, row) => total + (row.snapshotFixtures ?? 0),
  );

  int get totalFixturesWithOdds => pipelineHealth.fold(0, (total, row) {
    final fixtures = row.snapshotFixtures ?? 0;
    final missing = row.missingOdds ?? fixtures;
    return total + (fixtures - missing).clamp(0, fixtures).toInt();
  });

  int get totalMissingOdds =>
      pipelineHealth.fold(0, (total, row) => total + (row.missingOdds ?? 0));

  int get totalPlayerStatistics => pipelineHealth.fold(
    0,
    (total, row) => total + (row.snapshotPlayerStatistics ?? 0),
  );

  AdminDailyRun? get latestDailyRun =>
      dailyRuns.isEmpty ? null : dailyRuns.first;

  List<AdminOperationalAlert> get alerts {
    final result = <AdminOperationalAlert>[];
    final reference = generatedAt ?? DateTime.now().toUtc();
    final expected = expectedJobs;
    if (expected > 0 && activeJobs < expected) {
      result.add(
        AdminOperationalAlert(
          severity: AdminAlertSeverity.critical,
          title: 'Planification incomplète',
          message:
              '$activeJobs job(s) actif(s) pour $expected compétitions attendues.',
        ),
      );
    }

    final dailyRun = latestDailyRun;
    if (dailyRun == null) {
      result.add(
        const AdminOperationalAlert(
          severity: AdminAlertSeverity.critical,
          title: 'Aucune orchestration quotidienne',
          message: 'Aucun passage de daily-football-sync n’est enregistré.',
        ),
      );
    } else {
      final startedAt = dailyRun.startedAt;
      if (startedAt != null && reference.difference(startedAt).inHours >= 26) {
        result.add(
          AdminOperationalAlert(
            severity: AdminAlertSeverity.critical,
            title: 'Orchestration quotidienne interrompue',
            message:
                'Dernier passage enregistré le ${_compactDateTime(startedAt)}.',
          ),
        );
      }
      if (dailyRun.status != 'succeeded') {
        result.add(
          AdminOperationalAlert(
            severity: AdminAlertSeverity.critical,
            title: 'Dernière orchestration en échec',
            message: dailyRun.errorMessage ?? 'Statut : ${dailyRun.status}.',
          ),
        );
      }
      if (dailyRun.bookmakerId != null) {
        result.add(
          AdminOperationalAlert(
            severity: AdminAlertSeverity.warning,
            title: 'Collecte de cotes filtrée',
            message:
                'Le dernier batch a limité les cotes au bookmaker ${dailyRun.bookmakerId}.',
          ),
        );
      }
      if (dailyRun.storageWarningLevel != 'ok') {
        result.add(
          AdminOperationalAlert(
            severity: AdminAlertSeverity.warning,
            title: 'Stockage Supabase à surveiller',
            message:
                'Niveau ${dailyRun.storageWarningLevel} (${dailyRun.databaseSizeRatioLabel}).',
          ),
        );
      }
    }

    if (unhealthyLeagues > 0) {
      result.add(
        AdminOperationalAlert(
          severity: AdminAlertSeverity.warning,
          title: '$unhealthyLeagues compétition(s) à vérifier',
          message:
              'Leur collecte ou leur snapshot n’est pas dans l’état attendu.',
        ),
      );
    }
    if (totalMissingOdds > 0) {
      result.add(
        AdminOperationalAlert(
          severity: AdminAlertSeverity.warning,
          title: '$totalMissingOdds rencontre(s) sans cote',
          message:
              '$totalFixturesWithOdds/$totalSnapshotFixtures rencontre(s) disposent de cotes dans les derniers snapshots.',
        ),
      );
    }
    if (result.isEmpty) {
      result.add(
        const AdminOperationalAlert(
          severity: AdminAlertSeverity.info,
          title: 'Aucune alerte active',
          message: 'Planification, collecte et snapshots sont opérationnels.',
        ),
      );
    }
    return result;
  }
}

enum AdminAlertSeverity { critical, warning, info }

class AdminOperationalAlert {
  const AdminOperationalAlert({
    required this.severity,
    required this.title,
    required this.message,
  });

  final AdminAlertSeverity severity;
  final String title;
  final String message;
}

class AdminCronJob {
  const AdminCronJob({
    required this.jobId,
    required this.jobName,
    required this.schedule,
    required this.active,
    required this.taskKind,
    required this.leagueId,
  });

  final int? jobId;
  final String jobName;
  final String schedule;
  final bool active;
  final String taskKind;
  final int? leagueId;

  factory AdminCronJob.fromJson(Map<String, Object?> json) {
    return AdminCronJob(
      jobId: _int(json['jobid']),
      jobName: _string(json['jobname']) ?? 'unknown',
      schedule: _string(json['schedule']) ?? '',
      active: _bool(json['active']) ?? false,
      taskKind: _string(json['task_kind']) ?? 'other',
      leagueId: _int(json['api_football_league_id']),
    );
  }
}

class AdminCronRun {
  const AdminCronRun({
    required this.runId,
    required this.jobName,
    required this.taskKind,
    required this.leagueId,
    required this.status,
    required this.returnMessage,
    required this.startTime,
    required this.endTime,
  });

  final int? runId;
  final String jobName;
  final String taskKind;
  final int? leagueId;
  final String status;
  final String? returnMessage;
  final DateTime? startTime;
  final DateTime? endTime;

  factory AdminCronRun.fromJson(Map<String, Object?> json) {
    return AdminCronRun(
      runId: _int(json['runid']),
      jobName: _string(json['jobname']) ?? 'unknown',
      taskKind: _string(json['task_kind']) ?? 'other',
      leagueId: _int(json['api_football_league_id']),
      status: _string(json['status']) ?? 'unknown',
      returnMessage: _string(json['return_message']),
      startTime: _dateTime(json['start_time']),
      endTime: _dateTime(json['end_time']),
    );
  }

  bool get isRunning => endTime == null && status == 'running';

  bool get isFailure => status != 'succeeded' && !isRunning;
}

class AdminPipelineHealth {
  const AdminPipelineHealth({
    required this.leagueId,
    required this.leagueName,
    required this.syncStatus,
    required this.syncHealthStatus,
    required this.snapshotHealthStatus,
    required this.healthStatus,
    required this.resolvedSeason,
    required this.syncFixtures,
    required this.snapshotFixtures,
    required this.snapshotOdds,
    required this.missingOdds,
    required this.syncStartedAt,
    required this.syncFinishedAt,
    required this.syncWindowStart,
    required this.syncWindowEnd,
    required this.syncOdds,
    required this.syncStandings,
    required this.syncTeamStatistics,
    required this.syncRecentFixtureRows,
    required this.syncCachedResponses,
    required this.syncErrorMessage,
    required this.syncBookmakerId,
    required this.snapshotAsOf,
    required this.snapshotCreatedAt,
    required this.snapshotWindowStart,
    required this.snapshotWindowEnd,
    required this.snapshotStandings,
    required this.snapshotTeamStatistics,
    required this.snapshotRecentLeagueMatches,
    required this.snapshotExpectedGoals,
    required this.snapshotPlayerStatistics,
    required this.missingTeamStatistics,
    required this.missingRecentForm,
    required this.missingExpectedGoals,
  });

  final int leagueId;
  final String leagueName;
  final String? syncStatus;
  final String? syncHealthStatus;
  final String? snapshotHealthStatus;
  final String healthStatus;
  final int? resolvedSeason;
  final int? syncFixtures;
  final int? snapshotFixtures;
  final int? snapshotOdds;
  final int? missingOdds;
  final DateTime? syncStartedAt;
  final DateTime? syncFinishedAt;
  final String? syncWindowStart;
  final String? syncWindowEnd;
  final int? syncOdds;
  final int? syncStandings;
  final int? syncTeamStatistics;
  final int? syncRecentFixtureRows;
  final int? syncCachedResponses;
  final String? syncErrorMessage;
  final int? syncBookmakerId;
  final DateTime? snapshotAsOf;
  final DateTime? snapshotCreatedAt;
  final String? snapshotWindowStart;
  final String? snapshotWindowEnd;
  final int? snapshotStandings;
  final int? snapshotTeamStatistics;
  final int? snapshotRecentLeagueMatches;
  final int? snapshotExpectedGoals;
  final int? snapshotPlayerStatistics;
  final int? missingTeamStatistics;
  final int? missingRecentForm;
  final int? missingExpectedGoals;

  factory AdminPipelineHealth.fromJson(Map<String, Object?> json) {
    return AdminPipelineHealth(
      leagueId: _int(json['api_football_league_id']) ?? 0,
      leagueName: _string(json['league_name']) ?? 'Unknown league',
      syncStatus: _string(json['sync_status']),
      syncHealthStatus: _string(json['sync_health_status']),
      snapshotHealthStatus: _string(json['snapshot_health_status']),
      healthStatus: _string(json['health_status']) ?? 'unknown',
      resolvedSeason: _int(json['resolved_season']),
      syncFixtures: _int(json['sync_fixtures']),
      snapshotFixtures: _int(json['snapshot_fixtures']),
      snapshotOdds: _int(json['snapshot_odds']),
      missingOdds: _int(json['missing_odds']),
      syncStartedAt: _dateTime(json['sync_started_at']),
      syncFinishedAt: _dateTime(json['sync_finished_at']),
      syncWindowStart: _string(json['sync_window_start']),
      syncWindowEnd: _string(json['sync_window_end']),
      syncOdds: _int(json['sync_odds']),
      syncStandings: _int(json['sync_standings']),
      syncTeamStatistics: _int(json['sync_team_statistics']),
      syncRecentFixtureRows: _int(json['sync_recent_fixture_rows']),
      syncCachedResponses: _int(json['sync_cached_responses']),
      syncErrorMessage: _string(json['sync_error_message']),
      syncBookmakerId: _int(json['sync_bookmaker_id']),
      snapshotAsOf: _dateTime(json['snapshot_as_of']),
      snapshotCreatedAt: _dateTime(json['snapshot_created_at']),
      snapshotWindowStart: _string(json['snapshot_window_start']),
      snapshotWindowEnd: _string(json['snapshot_window_end']),
      snapshotStandings: _int(json['snapshot_standings']),
      snapshotTeamStatistics: _int(json['snapshot_team_statistics']),
      snapshotRecentLeagueMatches: _int(json['snapshot_recent_league_matches']),
      snapshotExpectedGoals: _int(json['snapshot_expected_goals']),
      snapshotPlayerStatistics: _int(json['snapshot_player_statistics']),
      missingTeamStatistics: _int(json['missing_team_statistics']),
      missingRecentForm: _int(json['missing_recent_form']),
      missingExpectedGoals: _int(json['missing_expected_goals']),
    );
  }

  String get explanation => switch (healthStatus) {
    'missing_sync' => 'Aucune collecte API-Football trouvée.',
    'stale_running' =>
      'La collecte est bloquée en cours depuis plus de 30 minutes.',
    'sync_not_succeeded' =>
      syncErrorMessage ?? 'La dernière collecte a échoué.',
    'missing_resolved_season' => 'La saison active n’a pas pu être déterminée.',
    'missing_snapshot' => 'Aucun snapshot publié pour cette compétition.',
    'stale_window' => 'Le dernier snapshot ne couvre plus la date actuelle.',
    'ok' => 'Collecte et snapshot à jour.',
    _ => 'État opérationnel non reconnu : $healthStatus.',
  };
}

class AdminDailyRun {
  const AdminDailyRun({
    required this.id,
    required this.status,
    required this.leagueIds,
    required this.bookmakerId,
    required this.resultsWindowStart,
    required this.resultsWindowEnd,
    required this.feedWindowStart,
    required this.feedWindowEnd,
    required this.apiRequestCount,
    required this.databaseSizeBytes,
    required this.databaseSizeLimitBytes,
    required this.databaseSizeRatio,
    required this.storageWarningLevel,
    required this.errorMessage,
    required this.startedAt,
    required this.finishedAt,
  });

  final String id;
  final String status;
  final List<int> leagueIds;
  final int? bookmakerId;
  final String? resultsWindowStart;
  final String? resultsWindowEnd;
  final String? feedWindowStart;
  final String? feedWindowEnd;
  final int apiRequestCount;
  final int? databaseSizeBytes;
  final int? databaseSizeLimitBytes;
  final double? databaseSizeRatio;
  final String storageWarningLevel;
  final String? errorMessage;
  final DateTime? startedAt;
  final DateTime? finishedAt;

  factory AdminDailyRun.fromJson(Map<String, Object?> json) {
    return AdminDailyRun(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? 'unknown',
      leagueIds: _intList(json['league_ids']),
      bookmakerId: _int(json['bookmaker_id']),
      resultsWindowStart: _string(json['results_window_start']),
      resultsWindowEnd: _string(json['results_window_end']),
      feedWindowStart: _string(json['feed_window_start']),
      feedWindowEnd: _string(json['feed_window_end']),
      apiRequestCount: _int(json['api_request_count']) ?? 0,
      databaseSizeBytes: _int(json['database_size_bytes']),
      databaseSizeLimitBytes: _int(json['database_size_limit_bytes']),
      databaseSizeRatio: _double(json['database_size_ratio']),
      storageWarningLevel: _string(json['storage_warning_level']) ?? 'unknown',
      errorMessage: _string(json['error_message']),
      startedAt: _dateTime(json['started_at']),
      finishedAt: _dateTime(json['finished_at']),
    );
  }

  String get databaseSizeRatioLabel {
    final ratio = databaseSizeRatio;
    return ratio == null ? 'ratio indisponible' : '${(ratio * 100).round()} %';
  }
}

class AdminSyncRun {
  const AdminSyncRun({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.leagueIds,
    required this.bookmakerId,
    required this.windowStart,
    required this.windowEnd,
    required this.fixtures,
    required this.odds,
    required this.cachedResponses,
    required this.errorMessage,
  });

  final String id;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<int> leagueIds;
  final int? bookmakerId;
  final String? windowStart;
  final String? windowEnd;
  final int fixtures;
  final int odds;
  final int cachedResponses;
  final String? errorMessage;

  factory AdminSyncRun.fromJson(Map<String, Object?> json) {
    final summary = _map(json['response_summary']);
    return AdminSyncRun(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? 'unknown',
      startedAt: _dateTime(json['started_at']),
      finishedAt: _dateTime(json['finished_at']),
      leagueIds: _intList(json['league_ids']),
      bookmakerId: _int(json['bookmaker_id']),
      windowStart: _string(json['window_start']),
      windowEnd: _string(json['window_end']),
      fixtures: _int(summary['fixtures']) ?? 0,
      odds: _int(summary['odds']) ?? 0,
      cachedResponses: _int(summary['cachedResponses']) ?? 0,
      errorMessage: _string(json['error_message']),
    );
  }
}

class AdminSnapshotRun {
  const AdminSnapshotRun({
    required this.id,
    required this.scopeKey,
    required this.leagueIds,
    required this.windowStart,
    required this.windowEnd,
    required this.asOf,
    required this.createdAt,
    required this.fixtures,
    required this.odds,
    required this.playerStatistics,
    required this.missingOdds,
  });

  final String id;
  final String scopeKey;
  final List<int> leagueIds;
  final String? windowStart;
  final String? windowEnd;
  final DateTime? asOf;
  final DateTime? createdAt;
  final int fixtures;
  final int odds;
  final int playerStatistics;
  final int missingOdds;

  factory AdminSnapshotRun.fromJson(Map<String, Object?> json) {
    final coverage = _map(json['coverage_summary']);
    final missing = _map(coverage['missing']);
    return AdminSnapshotRun(
      id: _string(json['id']) ?? '',
      scopeKey: _string(json['scope_key']) ?? 'unknown',
      leagueIds: _intList(json['league_ids']),
      windowStart: _string(json['window_start']),
      windowEnd: _string(json['window_end']),
      asOf: _dateTime(json['as_of']),
      createdAt: _dateTime(json['snapshot_created_at']),
      fixtures: _int(coverage['fixtures']) ?? 0,
      odds: _int(coverage['odds']) ?? 0,
      playerStatistics: _int(coverage['player_statistics']) ?? 0,
      missingOdds: _int(missing['odds']) ?? 0,
    );
  }
}

class AdminOperationRun {
  const AdminOperationRun({
    required this.id,
    required this.action,
    required this.status,
    required this.actorEmail,
    required this.leagueIds,
    required this.startedAt,
    required this.finishedAt,
    required this.errorMessage,
  });

  final String id;
  final String action;
  final String status;
  final String? actorEmail;
  final List<int> leagueIds;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorMessage;

  factory AdminOperationRun.fromJson(Map<String, Object?> json) {
    return AdminOperationRun(
      id: _string(json['id']) ?? '',
      action: _string(json['action']) ?? 'unknown',
      status: _string(json['status']) ?? 'unknown',
      actorEmail: _string(json['actor_email']),
      leagueIds: _intList(json['league_ids']),
      startedAt: _dateTime(json['started_at']),
      finishedAt: _dateTime(json['finished_at']),
      errorMessage: _string(json['error_message']),
    );
  }
}

class AdminOperationResult {
  const AdminOperationResult({
    required this.operationId,
    required this.status,
    required this.leagueId,
  });

  final String operationId;
  final String status;
  final int leagueId;

  factory AdminOperationResult.fromJson(Map<String, Object?> json) {
    return AdminOperationResult(
      operationId: _string(json['operation_id']) ?? '',
      status: _string(json['status']) ?? 'unknown',
      leagueId: _int(json['league_id']) ?? 0,
    );
  }
}

class AdminTestLinkResult {
  const AdminTestLinkResult({
    required this.linkId,
    required this.url,
    required this.expiresAt,
    required this.durationMinutes,
  });

  final String linkId;
  final Uri url;
  final DateTime? expiresAt;
  final int durationMinutes;

  factory AdminTestLinkResult.fromJson(Map<String, Object?> json) {
    return AdminTestLinkResult(
      linkId: _string(json['link_id']) ?? '',
      url: Uri.parse(_string(json['url']) ?? ''),
      expiresAt: _dateTime(json['expires_at']),
      durationMinutes: _int(json['duration_minutes']) ?? 60,
    );
  }
}

List<Map<String, Object?>> _list(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value
      .whereType<Map<Object?, Object?>>()
      .map((row) {
        return {
          for (final entry in row.entries)
            if (entry.key != null) entry.key.toString(): entry.value,
        };
      })
      .toList(growable: false);
}

List<int> _intList(Object? value) {
  if (value is! List) {
    return const [];
  }
  return value.map(_int).whereType<int>().toList(growable: false);
}

Map<String, Object?> _map(Object? value) {
  if (value is! Map) {
    return const {};
  }
  return {
    for (final entry in value.entries)
      if (entry.key != null) entry.key.toString(): entry.value,
  };
}

String? _string(Object? value) => value is String ? value : null;

bool? _bool(Object? value) => value is bool ? value : null;

int? _int(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  if (value is String) {
    return int.tryParse(value);
  }
  return null;
}

double? _double(Object? value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value);
  }
  return null;
}

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}

String _compactDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} à ${two(local.hour)}:${two(local.minute)}';
}
