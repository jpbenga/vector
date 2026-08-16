import 'package:flutter/material.dart';

import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../data/admin_ops_repository.dart';
import '../domain/admin_ops_models.dart';

class AdminCockpitPage extends StatefulWidget {
  const AdminCockpitPage({super.key});

  @override
  State<AdminCockpitPage> createState() => _AdminCockpitPageState();
}

class _AdminCockpitPageState extends State<AdminCockpitPage> {
  late final SupabaseAuthController _authController;
  AdminOpsRepository? _repository;
  AdminOpsOverview? _overview;
  Object? _error;
  bool _isLoading = true;
  int? _rerunningLeagueId;

  @override
  void initState() {
    super.initState();
    _authController = getIt<SupabaseAuthController>()
      ..addListener(_handleAuthChange);
    _prepareRepository();
    _load();
  }

  @override
  void dispose() {
    _authController.removeListener(_handleAuthChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = getIt<AppConfig>();
    return Scaffold(
      backgroundColor: const Color(0xFF090C10),
      appBar: AppBar(
        title: const Text('Cockpit admin'),
        actions: [
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _isLoading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _authController,
          builder: (context, _) {
            if (!_authController.isSignedIn) {
              return _AdminSignInPanel(
                environment: config.environment.value,
                isConfigured: _authController.isConfigured,
                onSignIn: _authController.signInWithGoogle,
              );
            }

            if (_isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            final error = _error;
            if (error != null) {
              return _AdminErrorPanel(error: error.toString(), onRetry: _load);
            }

            final overview = _overview;
            if (overview == null) {
              return _AdminErrorPanel(
                error: 'Aucune donnée admin disponible.',
                onRetry: _load,
              );
            }

            return _AdminOverview(
              overview: overview,
              rerunningLeagueId: _rerunningLeagueId,
              onRefresh: _load,
              onRerunLeague: _rerunLeague,
            );
          },
        ),
      ),
    );
  }

  void _prepareRepository() {
    final client = getIt<SupabaseInitializer>().client;
    _repository = client == null ? null : AdminOpsRepository(client);
  }

  void _handleAuthChange() {
    _prepareRepository();
    if (_authController.isSignedIn) {
      _load();
    }
  }

  Future<void> _load() async {
    final repository = _repository;
    if (repository == null) {
      setState(() {
        _isLoading = false;
        _error = 'Supabase n’est pas configuré pour cet environnement.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final overview = await repository.loadOverview();
      if (!mounted) {
        return;
      }
      setState(() {
        _overview = overview;
      });
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _rerunLeague(int leagueId) async {
    final repository = _repository;
    if (repository == null || _rerunningLeagueId != null) {
      return;
    }

    setState(() {
      _rerunningLeagueId = leagueId;
      _error = null;
    });

    try {
      await repository.rerunLeague(leagueId);
      await _load();
    } on Object catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
      });
    } finally {
      if (mounted) {
        setState(() {
          _rerunningLeagueId = null;
        });
      }
    }
  }
}

class _AdminSignInPanel extends StatelessWidget {
  const _AdminSignInPanel({
    required this.environment,
    required this.isConfigured,
    required this.onSignIn,
  });

  final String environment;
  final bool isConfigured;
  final Future<void> Function() onSignIn;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Accès admin',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text('Environnement : $environment'),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: isConfigured ? onSignIn : null,
                icon: const Icon(Icons.g_mobiledata_rounded),
                label: const Text('Se connecter avec Google'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AdminErrorPanel extends StatelessWidget {
  const _AdminErrorPanel({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40),
            const SizedBox(height: 16),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminOverview extends StatelessWidget {
  const _AdminOverview({
    required this.overview,
    required this.rerunningLeagueId,
    required this.onRefresh,
    required this.onRerunLeague,
  });

  final AdminOpsOverview overview;
  final int? rerunningLeagueId;
  final VoidCallback onRefresh;
  final ValueChanged<int> onRerunLeague;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricTile(
                label: 'Environnement',
                value: overview.environment,
                icon: Icons.public_rounded,
              ),
              _MetricTile(
                label: 'Jobs actifs',
                value: '${overview.activeJobs}/${overview.jobs.length}',
                icon: Icons.schedule_rounded,
              ),
              _MetricTile(
                label: 'Ligues à vérifier',
                value: '${overview.unhealthyLeagues}',
                icon: Icons.monitor_heart_rounded,
              ),
              _MetricTile(
                label: 'Runs cron non OK',
                value: '${overview.failedCronRuns}',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _SectionTitle(
            title: 'Santé pipeline',
            trailing: overview.generatedAt == null
                ? null
                : _formatDateTime(overview.generatedAt!),
          ),
          const SizedBox(height: 8),
          ...overview.pipelineHealth.map(
            (row) => _PipelineHealthTile(
              row: row,
              isRerunning: rerunningLeagueId == row.leagueId,
              onRerun: () => onRerunLeague(row.leagueId),
            ),
          ),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Dernières exécutions cron'),
          const SizedBox(height: 8),
          ...overview.cronRuns.take(12).map(_CronRunTile.new),
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Relances admin'),
          const SizedBox(height: 8),
          ...overview.adminOperationRuns.take(8).map(_AdminOperationTile.new),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121820),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF243140)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 4),
                Text(value, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (trailing != null) Text(trailing!),
      ],
    );
  }
}

class _PipelineHealthTile extends StatelessWidget {
  const _PipelineHealthTile({
    required this.row,
    required this.isRerunning,
    required this.onRerun,
  });

  final AdminPipelineHealth row;
  final bool isRerunning;
  final VoidCallback onRerun;

  @override
  Widget build(BuildContext context) {
    final isOk = row.healthStatus == 'ok';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF10151C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk ? const Color(0xFF214534) : const Color(0xFF5E3B28),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.error_rounded,
            color: isOk ? const Color(0xFF5DCA8B) : const Color(0xFFFFA35C),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${row.leagueName} (${row.leagueId})'),
                const SizedBox(height: 4),
                Text(
                  'sync ${row.syncFixtures ?? 0} | snapshot ${row.snapshotFixtures ?? 0} | odds ${row.snapshotOdds ?? 0} | ${row.healthStatus}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Relancer cette ligue',
            onPressed: isRerunning ? null : onRerun,
            icon: isRerunning
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.play_arrow_rounded),
          ),
        ],
      ),
    );
  }
}

class _CronRunTile extends StatelessWidget {
  const _CronRunTile(this.run);

  final AdminCronRun run;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        run.status == 'succeeded'
            ? Icons.check_circle_outline_rounded
            : Icons.error_outline_rounded,
      ),
      title: Text(run.jobName),
      subtitle: Text(
        [
          run.status,
          if (run.leagueId != null) 'ligue ${run.leagueId}',
          if (run.startTime != null) _formatDateTime(run.startTime!),
        ].join(' • '),
      ),
    );
  }
}

class _AdminOperationTile extends StatelessWidget {
  const _AdminOperationTile(this.run);

  final AdminOperationRun run;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        run.status == 'succeeded'
            ? Icons.published_with_changes_rounded
            : Icons.pending_actions_rounded,
      ),
      title: Text('${run.action} ${run.leagueIds.join(', ')}'),
      subtitle: Text(
        [
          run.status,
          if (run.actorEmail != null) run.actorEmail!,
          if (run.startedAt != null) _formatDateTime(run.startedAt!),
        ].join(' • '),
      ),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}
