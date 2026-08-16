class AdminOpsOverview {
  const AdminOpsOverview({
    required this.environment,
    required this.generatedAt,
    required this.jobs,
    required this.cronRuns,
    required this.pipelineHealth,
    required this.syncRuns,
    required this.snapshots,
    required this.adminOperationRuns,
  });

  final String environment;
  final DateTime? generatedAt;
  final List<AdminCronJob> jobs;
  final List<AdminCronRun> cronRuns;
  final List<AdminPipelineHealth> pipelineHealth;
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
    );
  }
}

class AdminSyncRun {
  const AdminSyncRun({
    required this.id,
    required this.status,
    required this.startedAt,
    required this.finishedAt,
    required this.leagueIds,
    required this.errorMessage,
  });

  final String id;
  final String status;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final List<int> leagueIds;
  final String? errorMessage;

  factory AdminSyncRun.fromJson(Map<String, Object?> json) {
    return AdminSyncRun(
      id: _string(json['id']) ?? '',
      status: _string(json['status']) ?? 'unknown',
      startedAt: _dateTime(json['started_at']),
      finishedAt: _dateTime(json['finished_at']),
      leagueIds: _intList(json['league_ids']),
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
    required this.createdAt,
  });

  final String id;
  final String scopeKey;
  final List<int> leagueIds;
  final String? windowStart;
  final String? windowEnd;
  final DateTime? createdAt;

  factory AdminSnapshotRun.fromJson(Map<String, Object?> json) {
    return AdminSnapshotRun(
      id: _string(json['id']) ?? '',
      scopeKey: _string(json['scope_key']) ?? 'unknown',
      leagueIds: _intList(json['league_ids']),
      windowStart: _string(json['window_start']),
      windowEnd: _string(json['window_end']),
      createdAt: _dateTime(json['snapshot_created_at']),
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

DateTime? _dateTime(Object? value) {
  if (value is! String || value.isEmpty) {
    return null;
  }
  return DateTime.tryParse(value);
}
