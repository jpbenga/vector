import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../app/access/external_link_launcher.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/config/app_config.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/theme/app_radius.dart';
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
  bool _isCreatingTestLink = false;
  int? _rerunningLeagueId;
  AdminTestLinkResult? _createdTestLink;

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
              appUrl: _publicAppUrl(config),
              overview: overview,
              rerunningLeagueId: _rerunningLeagueId,
              createdTestLink: _createdTestLink,
              isCreatingTestLink: _isCreatingTestLink,
              onRefresh: _load,
              onRerunLeague: _rerunLeague,
              onCreateTestLink: _createTestLink,
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

  Future<void> _createTestLink() async {
    final repository = _repository;
    if (repository == null || _isCreatingTestLink) {
      return;
    }

    setState(() {
      _isCreatingTestLink = true;
      _error = null;
    });

    try {
      final config = getIt<AppConfig>();
      final link = await repository.createTestLink(
        baseUrl: _publicAppUrl(config),
        durationMinutes: 60,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _createdTestLink = link;
      });
      await Clipboard.setData(ClipboardData(text: link.url.toString()));
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
          _isCreatingTestLink = false;
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
    required this.appUrl,
    required this.overview,
    required this.rerunningLeagueId,
    required this.createdTestLink,
    required this.isCreatingTestLink,
    required this.onRefresh,
    required this.onRerunLeague,
    required this.onCreateTestLink,
  });

  final Uri appUrl;
  final AdminOpsOverview overview;
  final int? rerunningLeagueId;
  final AdminTestLinkResult? createdTestLink;
  final bool isCreatingTestLink;
  final VoidCallback onRefresh;
  final ValueChanged<int> onRerunLeague;
  final VoidCallback onCreateTestLink;

  @override
  Widget build(BuildContext context) {
    final failedRuns = overview.failedRecentCronRuns.take(8).toList();
    final runningRuns = overview.cronRuns
        .where((run) => run.isRunning)
        .toList();
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
              _MetricTile(
                label: 'En cours',
                value: '${overview.runningCronRuns}',
                icon: Icons.pending_actions_rounded,
              ),
            ],
          ),
          const SizedBox(height: 20),
          _ShareAccessPanel(
            appUrl: appUrl,
            createdTestLink: createdTestLink,
            isCreatingTestLink: isCreatingTestLink,
            onCreateTestLink: onCreateTestLink,
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
          const _SectionTitle(title: 'Jobs en cours et échecs'),
          const SizedBox(height: 8),
          if (runningRuns.isEmpty && failedRuns.isEmpty)
            const _EmptyAdminLine(label: 'Aucun job en cours ou en échec.')
          else ...[
            ...runningRuns.map(_CronRunTile.new),
            ...failedRuns.map(_CronRunTile.new),
          ],
          const SizedBox(height: 20),
          const _SectionTitle(title: 'Jobs planifiés'),
          const SizedBox(height: 8),
          ...overview.jobs.map(_CronJobTile.new),
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

class _ShareAccessPanel extends StatelessWidget {
  const _ShareAccessPanel({
    required this.appUrl,
    required this.createdTestLink,
    required this.isCreatingTestLink,
    required this.onCreateTestLink,
  });

  final Uri appUrl;
  final AdminTestLinkResult? createdTestLink;
  final bool isCreatingTestLink;
  final VoidCallback onCreateTestLink;

  @override
  Widget build(BuildContext context) {
    final testLink = createdTestLink;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(title: 'Accès rapide'),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            final appBox = _QrLinkBox(
              title: 'App release',
              url: appUrl,
              actions: _linkActions(appUrl, label: 'app release'),
            );
            final testerBox = _QrLinkBox(
              title: 'Lien testeur 1h',
              url: testLink?.url,
              subtitle: testLink?.expiresAt == null
                  ? null
                  : 'Expire ${_formatDateTime(testLink!.expiresAt!)}',
              actions: [
                IconButton(
                  tooltip: 'Générer un lien testeur',
                  onPressed: isCreatingTestLink ? null : onCreateTestLink,
                  icon: isCreatingTestLink
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.add_link_rounded),
                ),
                ..._linkActions(testLink?.url, label: 'lien testeur'),
              ],
            );
            if (compact) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: appBox,
                  ),
                  testerBox,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: appBox),
                const SizedBox(width: 8),
                Expanded(child: testerBox),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _QrLinkBox extends StatelessWidget {
  const _QrLinkBox({
    required this.title,
    required this.url,
    required this.actions,
    this.subtitle,
  });

  final String title;
  final Uri? url;
  final List<Widget> actions;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayUrl = url?.toString();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          _QrPreview(data: displayUrl),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    ...actions,
                  ],
                ),
                if (subtitle != null) Text(subtitle!),
                const SizedBox(height: 6),
                Text(
                  displayUrl ?? 'Aucun lien généré',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QrPreview extends StatelessWidget {
  const _QrPreview({required this.data});

  final String? data;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final value = data;
    return Container(
      width: 104,
      height: 104,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: value == null
          ? Icon(Icons.qr_code_2_rounded, color: colorScheme.onSurfaceVariant)
          : QrImageView(
              data: value,
              version: QrVersions.auto,
              size: 92,
              backgroundColor: colorScheme.surface,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: colorScheme.onSurface,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: colorScheme.onSurface,
              ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: 168,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: colorScheme.outlineVariant),
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
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = isOk ? colorScheme.primary : colorScheme.error;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(AppRadius.control),
        border: Border.all(color: statusColor),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? Icons.check_circle_rounded : Icons.error_rounded,
            color: statusColor,
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

class _CronJobTile extends StatelessWidget {
  const _CronJobTile(this.job);

  final AdminCronJob job;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        job.active ? Icons.schedule_rounded : Icons.pause_circle_rounded,
      ),
      title: Text(job.jobName),
      subtitle: Text(
        [
          job.taskKind,
          if (job.leagueId != null) 'ligue ${job.leagueId}',
          _scheduleLabel(job.schedule),
          if (job.active) _nextRunLabel(job.schedule),
        ].where((item) => item.isNotEmpty).join(' • '),
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
          if (run.returnMessage != null) run.returnMessage!,
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

class _EmptyAdminLine extends StatelessWidget {
  const _EmptyAdminLine({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

String _formatDateTime(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
}

Uri _publicAppUrl(AppConfig config) {
  final configured = config.appPublicUrl;
  final base = configured ?? Uri.base;
  return base.replace(path: '/', query: null, fragment: null);
}

List<Widget> _linkActions(Uri? url, {required String label}) {
  return [
    IconButton(
      tooltip: 'Copier $label',
      onPressed: url == null
          ? null
          : () {
              Clipboard.setData(ClipboardData(text: url.toString()));
            },
      icon: const Icon(Icons.copy_rounded),
    ),
    IconButton(
      tooltip: 'Envoyer $label par mail',
      onPressed: url == null
          ? null
          : () {
              launchExternalLink(_emailUri(url));
            },
      icon: const Icon(Icons.mail_outline_rounded),
    ),
    IconButton(
      tooltip: 'Envoyer $label par SMS',
      onPressed: url == null
          ? null
          : () {
              launchExternalLink(_smsUri(url));
            },
      icon: const Icon(Icons.sms_outlined),
    ),
  ];
}

Uri _emailUri(Uri url) {
  return Uri(
    scheme: 'mailto',
    queryParameters: {'subject': 'Lien de test Lector', 'body': url.toString()},
  );
}

Uri _smsUri(Uri url) {
  return Uri(scheme: 'sms', queryParameters: {'body': url.toString()});
}

String _scheduleLabel(String schedule) {
  final parts = schedule.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) {
    return schedule;
  }
  final minute = int.tryParse(parts[0]);
  final hour = int.tryParse(parts[1]);
  if (minute == null || hour == null) {
    return schedule;
  }
  String two(int value) => value.toString().padLeft(2, '0');
  return 'prévu ${two(hour)}:${two(minute)} UTC';
}

String _nextRunLabel(String schedule) {
  final nextRun = _nextDailyRun(schedule);
  if (nextRun == null) {
    return '';
  }
  return 'prochain ${_formatDateTime(nextRun)}';
}

DateTime? _nextDailyRun(String schedule) {
  final parts = schedule.trim().split(RegExp(r'\s+'));
  if (parts.length < 2) {
    return null;
  }
  final minute = int.tryParse(parts[0]);
  final hour = int.tryParse(parts[1]);
  if (minute == null || hour == null) {
    return null;
  }
  final now = DateTime.now().toUtc();
  var next = DateTime.utc(now.year, now.month, now.day, hour, minute);
  if (!next.isAfter(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}
