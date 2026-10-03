import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../../../core/auth/supabase_auth_controller.dart';
import '../../../core/di/service_locator.dart';
import '../../../core/supabase/supabase_initializer.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../data/admin_ops_repository.dart';
import '../domain/operations_models.dart';
import '../domain/operations_issue.dart';
import 'operations_issue_card.dart';
import 'operations_history.dart';
import 'admin_cockpit_page.dart';

class OperationsPage extends StatefulWidget {
  const OperationsPage({super.key, this.repository});
  final AdminOpsRepository? repository;
  @override
  State<OperationsPage> createState() => _OperationsPageState();
}

class _OperationsPageState extends State<OperationsPage>
    with WidgetsBindingObserver {
  AdminOpsRepository? _repository;
  SupabaseAuthController? _auth;
  OpsOverview? _data;
  String? _error, _commandError, _cycleId, _selectedTask;
  bool _reloadRequested = false;
  Map<String, dynamic>? _details;
  Timer? _timer;
  bool _loading = false, _busy = false, _visible = true;
  int _tab = 0;
  String _search = '', _filter = 'all';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.repository != null) {
      _repository = widget.repository;
    } else {
      _auth = getIt<SupabaseAuthController>()..addListener(_authChanged);
      final client = getIt<SupabaseInitializer>().client;
      if (client != null) _repository = AdminOpsRepository(client);
    }
    _load();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_visible) _load();
    });
  }

  void _authChanged() {
    if (mounted) {
      setState(() {
        if (_auth?.isSignedIn != true) {
          _data = null;
          _details = null;
        }
      });
      _load();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _visible = state == AppLifecycleState.resumed;
    if (_visible) _load();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _auth?.removeListener(_authChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    if (_loading) {
      _reloadRequested = true;
      return;
    }
    if (_repository == null || (_auth != null && !_auth!.isSignedIn)) {
      return;
    }
    _loading = true;
    final requestedCycle = _cycleId;
    final requestedTask = _selectedTask;
    try {
      final value = await _repository!.operations('ops_overview', {
        'cycle_id': ?requestedCycle,
      });
      Map<String, dynamic>? detail;
      if (requestedTask != null) {
        detail = await _repository!.operations('ops_events', {
          'task_id': requestedTask,
        });
      }
      if (!mounted ||
          (_auth != null && !_auth!.isSignedIn) ||
          _cycleId != requestedCycle ||
          _selectedTask != requestedTask) {
        return;
      }
      setState(() {
        _data = OpsOverview(value);
        if (_cycleId == null && _data!.cycleId != null) {
          _cycleId = _data!.cycleId;
        }
        if (_selectedTask == null && _data!.tasks.isNotEmpty) {
          _selectedTask =
              (_data!.tasks.where((t) => t.status == 'running').firstOrNull ??
                      _data!.tasks
                          .where((t) => t.status == 'failed')
                          .firstOrNull ??
                      _data!.tasks.first)
                  .id;
          _reloadRequested = true;
        }
        _details = detail;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _loading = false;
      if (_reloadRequested && mounted) {
        _reloadRequested = false;
        unawaited(_load());
      }
    }
  }

  Future<void> _action(
    String action, [
    Map<String, Object?> payload = const {},
  ]) async {
    if (_busy || _repository == null) return;
    setState(() {
      _busy = true;
      _commandError = null;
    });
    try {
      final result = await _repository!.operations(action, payload);
      if (!mounted) return;
      if (result['cycle_id'] != null) {
        setState(() {
          _cycleId = result['cycle_id'] as String;
          _selectedTask = null;
          _details = null;
          _tab = 0;
        });
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Commande enregistrée par le serveur.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _commandError = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(
    String title,
    String explanation,
    String action,
    Map<String, Object?> payload,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(explanation),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Retour'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
    if (yes == true) await _action(action, payload);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surfaces.background,
      appBar: AppBar(
        backgroundColor: context.surfaces.backgroundSecondary,
        foregroundColor: context.textColors.primary,
        title: const Text('LECTOR SPORT  /  Opérations'),
        actions: [
          IconButton(
            tooltip: 'Accès testeurs et diagnostic historique',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const AdminCockpitPage()),
            ),
            icon: const Icon(Icons.settings_outlined),
          ),
          IconButton(
            tooltip: 'Actualiser',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(child: _body(context)),
    );
  }

  Widget _body(BuildContext context) {
    if (_auth != null && !_auth!.isSignedIn) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.admin_panel_settings_outlined,
              size: 56,
              color: context.brand.accent,
            ),
            const SizedBox(height: 16),
            const Text('Pilotage réservé aux administrateurs'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _auth!.isConfigured ? _auth!.signInWithGoogle : null,
              child: const Text('Se connecter avec Google'),
            ),
          ],
        ),
      );
    }
    if (_repository == null) {
      return const Center(child: Text('Supabase n’est pas configuré.'));
    }
    final data = _data;
    if (data == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: _error == null
              ? const CircularProgressIndicator()
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Le poste de pilotage n’est pas disponible',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _issue(_error!, adminRequest: true),
                      const SizedBox(height: 12),

                      TextButton(
                        onPressed: _load,
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1520),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 24,
              runSpacing: 12,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Le centre de contrôle',
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: context.textColors.primary,
                      ),
                    ),
                    Text(
                      'Comprendre, agir et retrouver ce qui s’est passé.',
                      style: TextStyle(color: context.textColors.secondary),
                    ),
                  ],
                ),
                Tooltip(
                  message: 'Actualisation toutes les 5 secondes',
                  child: Chip(
                    avatar: Icon(
                      Icons.circle,
                      size: 10,
                      color: _error == null
                          ? context.brand.accent
                          : context.semantic.warning,
                    ),
                    label: Text(
                      _error == null
                          ? 'Direct · ${_time(data.updatedAt?.toIso8601String())}'
                          : explainOperationsIssue(
                              _error!,
                              adminRequest: true,
                            ).reconnect
                          ? 'Session à renouveler'
                          : 'Actualisation interrompue',
                    ),
                  ),
                ),
              ],
            ),
            if (data.json['configured'] == true &&
                (DateTime.tryParse('${data.json['last_tick_at']}')?.isBefore(
                      DateTime.now().subtract(const Duration(minutes: 3)),
                    ) ??
                    true))
              _notice(
                context,
                'Le planificateur ne confirme pas de passage récent. Les batchs en attente peuvent rester bloqués ; vérifier le cron lector-ops-dispatch dans Supabase.',
                true,
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _issue(_error!, adminRequest: true),
              ),
            if (_commandError != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: _issue(
                  _commandError!,
                  adminRequest: true,
                  heading: 'Commande refusée',
                ),
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final item in [
                  (0, 'Pilotage', Icons.account_tree_outlined),
                  (1, 'Historique', Icons.history),
                  (2, 'Planification', Icons.calendar_month_outlined),
                  (3, 'API & données', Icons.data_object),
                ])
                  ChoiceChip(
                    avatar: Icon(item.$3, size: 18),
                    label: Text(item.$2),
                    selected: _tab == item.$1,
                    onSelected: (_) => setState(() => _tab = item.$1),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            switch (_tab) {
              0 => _pilot(context, data),
              1 => _history(context, data),
              2 => _schedules(context, data),
              _ => _api(context, data),
            },
          ],
        ),
      ),
    );
  }

  Widget _pilot(BuildContext context, OpsOverview data) {
    final cycle = data.cycle;
    final all = data.tasks;
    final filtered = all
        .where(
          (t) =>
              (_filter == 'all' || t.status == _filter) &&
              t.name.toLowerCase().contains(_search.toLowerCase()),
        )
        .toList();
    final selected = all.where((t) => t.id == _selectedTask).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                spacing: 12,
                runSpacing: 12,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${cycle['label'] ?? 'Prêt pour un nouveau cycle'}',
                        style: const TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        cycle.isEmpty
                            ? 'Lancer les compétitions activées, ou une compétition depuis Planification.'
                            : '${_date(cycle['created_at'])} · ${cycle['actor']}',
                      ),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: _busy
                        ? null
                        : () => _action('ops_start', {'all': true}),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Lancer un cycle'),
                  ),
                  if (data.cycleId != null) ...[
                    OutlinedButton.icon(
                      onPressed: _busy || cycle['cancel_requested'] == true
                          ? null
                          : () => _action(
                              cycle['paused'] == true
                                  ? 'ops_resume_cycle'
                                  : 'ops_pause_cycle',
                              {'id': data.cycleId},
                            ),
                      icon: Icon(
                        cycle['paused'] == true
                            ? Icons.play_arrow
                            : Icons.pause,
                      ),
                      label: Text(
                        cycle['paused'] == true
                            ? 'Reprendre'
                            : 'Mettre en pause',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: _busy || !all.any((t) => !t.terminal)
                          ? null
                          : () => _confirm(
                              'Interrompre le cycle ?',
                              'Les batchs en attente seront annulés. Le batch actif confirmera son arrêt au prochain point de contrôle. Les données déjà enregistrées seront conservées.',
                              'ops_cancel_cycle',
                              {'id': data.cycleId},
                            ),
                      icon: const Icon(Icons.stop),
                      label: const Text('Interrompre'),
                    ),
                    if (all.any(
                      (t) => t.status == 'failed' || t.status == 'cancelled',
                    ))
                      OutlinedButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _action('ops_retry', {
                                'cycle_id': data.cycleId,
                              }),
                        icon: const Icon(Icons.replay),
                        label: const Text('Reprendre les échecs'),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: data.progress,
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${(data.progress * 100).round()} % traités',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _metric(
                    context,
                    'Réussis',
                    data.count('succeeded'),
                    context.semantic.success,
                  ),
                  _metric(
                    context,
                    'En cours',
                    data.count('running'),
                    context.semantic.info,
                  ),
                  _metric(
                    context,
                    'Erreurs',
                    data.count('failed'),
                    context.semantic.error,
                  ),
                  _metric(
                    context,
                    'En attente',
                    data.count('pending'),
                    context.textColors.secondary,
                  ),
                  _metric(
                    context,
                    'Interrompus',
                    data.count('cancelled'),
                    context.textColors.weak,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Progression = étapes terminées ; les échecs sont comptés comme traités, jamais comme réussis.',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textColors.secondary,
                ),
              ),
              if (cycle['paused'] == true)
                _notice(
                  context,
                  'Cycle en pause. L’étape en cours termine son travail ; aucune étape suivante ne démarre.',
                  false,
                ),
              if (cycle['cancel_requested'] == true)
                _notice(
                  context,
                  'Interruption demandée. Les réponses déjà en cours peuvent encore être enregistrées.',
                  false,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (data.active.any((t) => t.json['cycle_id'] != data.cycleId))
          _notice(
            context,
            'Un batch d’un autre cycle occupe le worker : ${data.active.map((t) => t.name).join(', ')}. Ce cycle attend son tour.',
            false,
          ),
        LayoutBuilder(
          builder: (context, c) {
            final list = _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Rechercher une compétition',
                    ),
                    onChanged: (v) => setState(() => _search = v),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final status in [
                        'all',
                        'running',
                        'failed',
                        'pending',
                        'succeeded',
                        'cancelled',
                      ])
                        ChoiceChip(
                          label: Text(
                            status == 'all' ? 'Tout' : opsStatus(status),
                          ),
                          selected: _filter == status,
                          onSelected: (_) => setState(() => _filter = status),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (filtered.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('Aucun batch dans cette sélection.'),
                    ),
                  for (final task in filtered) _taskTile(context, task),
                ],
              ),
            );
            final detail = selected == null
                ? _panel(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.account_tree_outlined,
                            size: 48,
                            color: context.brand.accent,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'Sélectionne une compétition pour explorer ses étapes, ses données et ses erreurs.',
                          ),
                        ],
                      ),
                    ),
                  )
                : _taskDetail(context, selected);
            return c.maxWidth > 1050
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 5, child: list),
                      const SizedBox(width: 16),
                      Expanded(flex: 6, child: detail),
                    ],
                  )
                : Column(children: [list, const SizedBox(height: 16), detail]);
          },
        ),
      ],
    );
  }

  Widget _taskTile(BuildContext context, OpsTask task) => Card(
    color: _selectedTask == task.id ? context.surfaces.surfaceHover : null,
    child: InkWell(
      borderRadius: BorderRadius.circular(AppRadius.button),
      onTap: () {
        setState(() {
          _selectedTask = task.id;
          _details = null;
        });
        _load();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  task.status == 'running'
                      ? Icons.sync
                      : task.status == 'succeeded'
                      ? Icons.check_circle_outline
                      : task.status == 'failed'
                      ? Icons.error_outline
                      : Icons.circle_outlined,
                  color: _color(context, task.status),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.name,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                  ),
                ),
                _badge(context, task.label, _color(context, task.status)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < 4; i++) ...[
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < task.stage
                            ? context.semantic.success
                            : task.stage == i && task.status != 'pending'
                            ? _color(context, task.status)
                            : context.surfaces.disabled,
                        borderRadius: BorderRadius.circular(
                          AppRadius.indicator,
                        ),
                      ),
                    ),
                  ),
                  if (i < 3) const SizedBox(width: 5),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Text(
                    task.stage == 4
                        ? 'Publié dans l’application'
                        : opsStageNames[task.stage],
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textColors.secondary,
                    ),
                  ),
                ),
                Text(
                  '${(task.progress * 100).round()} % · ${_duration(task.json)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textColors.secondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  Widget _taskDetail(BuildContext context, OpsTask task) {
    final detailTask = opsMap(_details?['task']);
    final sample = detailTask.isEmpty
        ? task.sample
        : opsMap(detailTask['sample']);
    final events = opsRows(_details?['events']);
    final duration = opsRows(_data?.json['durations'])
        .where(
          (d) =>
              d['league_id'] == task.leagueId &&
              d['job_kind'] == task.json['job_kind'],
        )
        .firstOrNull;
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.name,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _badge(context, task.label, _color(context, task.status)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${task.json['job_kind'] == 'enrichment' ? 'Enrichissement hebdomadaire' : 'Mise à jour quotidienne'} · Données du ${task.json['day']} · Dernier signal ${_time(task.json['heartbeat_at'])}',
            style: TextStyle(color: context.textColors.secondary),
          ),
          const SizedBox(height: 8),
          Text(
            duration == null
                ? 'Durée moyenne : disponible après une première exécution réussie.'
                : 'Moyenne sur 48 h : ${duration['average_seconds']} s · ${duration['samples']} exécution(s) réussie(s). La durée inclut les pauses éventuelles.',
            style: TextStyle(fontSize: 12, color: context.textColors.secondary),
          ),
          const SizedBox(height: 20),
          OperationsDag(
            task: task,
            onStage: (index) => showDialog<void>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(opsStageNames[index]),
                content: SizedBox(
                  width: 540,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(opsStageExpectations[index]),
                        const SizedBox(height: 16),
                        _json(
                          context,
                          opsMap(detailTask['stage_results'])[[
                                'sync',
                                'results',
                                'snapshot',
                                'analysis',
                              ][index]] ??
                              {
                                'statut': index < task.stage
                                    ? 'Terminé'
                                    : 'Pas encore terminé',
                              },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Fermer'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Cliquer sur une étape pour voir ce qu’elle doit produire.',
            style: TextStyle(fontSize: 12, color: context.textColors.secondary),
          ),
          const SizedBox(height: 18),
          if (task.error != null) _issue(task.error!),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!task.terminal)
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _confirm(
                          'Interrompre ${task.name} ?',
                          'L’arrêt sera confirmé au prochain point de contrôle. Une requête déjà envoyée au fournisseur ne peut pas être annulée rétroactivement.',
                          'ops_cancel_task',
                          {'id': task.id},
                        ),
                  icon: const Icon(Icons.stop),
                  label: const Text('Interrompre ce batch'),
                ),
              if (task.terminal)
                FilledButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _action('ops_start', {
                          'league_ids': [task.leagueId],
                          'job_kind': task.json['job_kind'],
                        }),
                  icon: const Icon(Icons.replay),
                  label: const Text('Relancer'),
                ),
            ],
          ),
          const SizedBox(height: 22),
          const Text(
            'Ce que le batch reçoit',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final item in [
                ('collectProviderRequests', 'Appels collecte'),
                ('resultProviderRequests', 'Appels résultats'),
                ('cachedResponses', 'Réponses disponibles'),
                ('leagueFixtureRows', 'Matchs de saison'),
                ('completedFixtures', 'Matchs terminés'),
              ])
                if (task.counters[item.$1] != null)
                  _metric(
                    context,
                    item.$2,
                    task.counters[item.$1],
                    context.brand.accent,
                  ),
            ],
          ),
          if (task.counters['enrichmentPhase'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                'Enrichissement par lots · ${_enrichmentPhaseLabel('${task.counters['enrichmentPhase']}')} · dernier passage : ${task.counters['enrichmentBatchProcessed'] ?? 0} appels traités. Le batch reprend automatiquement jusqu’à la fin.',
              ),
            ),
          if (task.counters['endpoint'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Ressource en cours : ${task.counters['endpoint']}'),
            ),
          const SizedBox(height: 16),
          if (sample.isEmpty)
            const Text(
              'Aucun échantillon de match reçu pour le moment. Cela ne signifie pas que le batch a échoué.',
            )
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.surfaces.backgroundSecondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${sample['home'] ?? 'Domicile'}  —  ${sample['away'] ?? 'Extérieur'}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${sample['competition'] ?? task.name} · ${_date(sample['kickoff'])}',
                  ),
                  if (sample['fetched_at'] != null)
                    Text(
                      'Reçu du fournisseur le ${_date(sample['fetched_at'])}${sample['from_cache'] == true ? ' · relu du cache' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textColors.secondary,
                      ),
                    ),
                  const SizedBox(height: 12),
                  for (final field in [
                    ('fixture_id', 'Identifiant du match'),
                    ('kickoff', 'Date du match'),
                    ('home', 'Équipe domicile'),
                    ('away', 'Équipe extérieure'),
                    ('status', 'Statut du match'),
                  ])
                    Row(
                      children: [
                        Icon(
                          sample[field.$1] == null
                              ? Icons.help_outline
                              : Icons.check_circle,
                          size: 16,
                          color: sample[field.$1] == null
                              ? context.semantic.warning
                              : context.semantic.success,
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(field.$2)),
                        Flexible(
                          child: Text(
                            '${sample[field.$1] ?? 'Non fourni'}',
                            textAlign: TextAlign.right,
                          ),
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  Text(
                    'Échantillon factuel reçu ou relu du cache ; couverture complète dans le résultat de l’étape.',
                    style: TextStyle(
                      fontSize: 12,
                      color: context.textColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
            ExpansionTile(
              title: const Text('Voir le JSON reçu (extrait)'),
              children: [_json(context, sample)],
            ),
          ],
          const SizedBox(height: 18),
          const Text(
            'Journal du batch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          if (events.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Le journal apparaîtra au démarrage des étapes.'),
            ),
          for (final e in events)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                e['kind'] == 'failed' || e['kind'] == 'timeout'
                    ? Icons.error_outline
                    : Icons.circle,
                size: 14,
                color: e['kind'] == 'failed'
                    ? context.semantic.error
                    : context.brand.accent,
              ),
              title: Text(
                '${e['stage'] is int ? opsStageNames[(e['stage'] as int).clamp(0, 3)] : ''} · ${['failed', 'timeout'].contains(e['kind']) ? explainOperationsIssue('${e['message']}').title : e['message']}',
              ),
              subtitle: Text('${_time(e['created_at'])} · ${e['actor']}'),
            ),
        ],
      ),
    );
  }

  Widget _history(BuildContext context, OpsOverview data) => OperationsHistory(
    data: data,
    onCycle: (id) {
      setState(() {
        _cycleId = id;
        _selectedTask = null;
        _details = null;
        _tab = 0;
      });
      _load();
    },
  );
  Widget _schedules(BuildContext context, OpsOverview data) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            const Text(
              'Compétitions & horaires',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            FilledButton.icon(
              onPressed: _busy ? null : () => _editCompetition(context),
              icon: const Icon(Icons.add),
              label: const Text('Ajouter une compétition'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Planification quotidienne pilotée'),
          subtitle: const Text(
            'Fuseau Europe/Paris. Les compétitions activées sont mises en file à leur horaire, puis exécutées successivement.',
          ),
          value: data.scheduling,
          onChanged: _busy
              ? null
              : (enabled) => _confirm(
                  enabled
                      ? 'Activer la planification pilotée ?'
                      : 'Suspendre les prochains cycles quotidiens ?',
                  enabled
                      ? 'Les anciens crons api-football seront désactivés pour éviter les doubles exécutions. Les tâches déjà lancées par ces crons ne seront pas arrêtées. Les horaires déjà passés aujourd’hui seront rattrapés.'
                      : 'Les cycles déjà en cours continueront. Aucun nouveau cycle quotidien piloté ne sera créé.',
                  'ops_configure',
                  {'enabled': enabled},
                ),
        ),
        const Divider(),
        for (final competition in data.competitions)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                SizedBox(
                  width: MediaQuery.sizeOf(context).width < 420
                      ? MediaQuery.sizeOf(context).width - 96
                      : 310,
                  child: Row(
                    children: [
                      Switch(
                        value: competition['enabled'] == true,
                        onChanged: _busy
                            ? null
                            : (v) => _action('ops_competition', {
                                'league_id': competition['league_id'],
                                'name': competition['name'],
                                'enabled': v,
                                'daily_time': '${competition['daily_time']}'
                                    .substring(0, 5),
                              }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${competition['name']}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Quotidien · ${competition['daily_time']} · Paris'),
                    Text(
                      'Dernière mise en file : ${competition['last_scheduled_date'] ?? 'jamais'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textColors.secondary,
                      ),
                    ),
                    Text(
                      competition['enrichment_enabled'] == true
                          ? 'Enrichissement · ${_weekdays[(competition['enrichment_day'] as int?) ?? 0]} · ${competition['enrichment_time']} · ${competition['enrichment_timezone'] ?? 'Europe/Paris'}'
                          : 'Enrichissement hebdomadaire désactivé',
                      style: TextStyle(
                        fontSize: 12,
                        color: context.textColors.secondary,
                      ),
                    ),
                  ],
                ),
                OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _editCompetition(context, competition),
                  child: const Text('Modifier'),
                ),
                FilledButton.tonalIcon(
                  onPressed: _busy
                      ? null
                      : () => _action('ops_start', {
                          'league_ids': [competition['league_id']],
                        }),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Lancer maintenant'),
                ),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _action('ops_start', {
                          'league_ids': [competition['league_id']],
                          'job_kind': 'enrichment',
                        }),
                  child: const Text('Enrichir les joueurs'),
                ),
              ],
            ),
          ),
      ],
    ),
  );
  Future<void> _editCompetition(
    BuildContext context, [
    Map<String, dynamic>? current,
  ]) async {
    final id = TextEditingController(
      text: current?['league_id']?.toString() ?? '',
    );
    final name = TextEditingController(
      text: current?['name']?.toString() ?? '',
    );
    final time = TextEditingController(
      text: (current?['daily_time']?.toString() ?? '02:00').substring(0, 5),
    );
    final enrichmentTime = TextEditingController(
      text: (current?['enrichment_time']?.toString() ?? '04:15').substring(
        0,
        5,
      ),
    );
    var enrichmentEnabled = current?['enrichment_enabled'] == true;
    var enrichmentDay = (current?['enrichment_day'] as int?) ?? 0;
    final form = GlobalKey<FormState>();
    final value = await showDialog<Map<String, Object?>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          title: Text(
            current == null
                ? 'Ajouter une compétition'
                : 'Modifier la planification',
          ),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (current == null)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Le numéro API-Football sert uniquement à l’ajout. Le serveur le vérifie et récupère le nom officiel.',
                        ),
                      ),
                    TextFormField(
                      controller: id,
                      enabled: current == null,
                      decoration: const InputDecoration(
                        labelText: 'Numéro API-Football',
                      ),
                      validator: (s) => (int.tryParse(s ?? '') ?? 0) > 0
                          ? null
                          : 'Numéro positif requis',
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: name,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la compétition',
                      ),
                      validator: (s) =>
                          s == null || s.trim().isEmpty ? 'Nom requis' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: time,
                      decoration: const InputDecoration(
                        labelText: 'Heure quotidienne à Paris (HH:MM)',
                      ),
                      validator: (s) =>
                          RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s ?? '')
                          ? null
                          : 'Exemple : 02:30',
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Enrichissement hebdomadaire'),
                      value: enrichmentEnabled,
                      onChanged: (v) => update(() => enrichmentEnabled = v),
                    ),
                    DropdownButtonFormField<int>(
                      initialValue: enrichmentDay,
                      decoration: const InputDecoration(labelText: 'Jour'),
                      items: [
                        for (var i = 0; i < 7; i++)
                          DropdownMenuItem(value: i, child: Text(_weekdays[i])),
                      ],
                      onChanged: (v) => update(() => enrichmentDay = v ?? 0),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: enrichmentTime,
                      decoration: InputDecoration(
                        labelText:
                            'Heure hebdomadaire (${current?['enrichment_timezone'] ?? 'Europe/Paris'})',
                      ),
                      validator: (s) =>
                          RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(s ?? '')
                          ? null
                          : 'Exemple : 04:15',
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                if (form.currentState!.validate()) {
                  Navigator.pop(context, {
                    'league_id': int.parse(id.text),
                    'name': name.text.trim(),
                    'daily_time': time.text,
                    'enabled': current?['enabled'] ?? false,
                    'enrichment_enabled': enrichmentEnabled,
                    'enrichment_day': enrichmentDay,
                    'enrichment_time': enrichmentTime.text,
                  });
                }
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    // Dialog route owns the text fields until its closing animation completes.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    id.dispose();
    name.dispose();
    time.dispose();
    enrichmentTime.dispose();
    if (value != null) await _action('ops_competition', value);
  }

  Widget _api(BuildContext context, OpsOverview data) {
    final budget = opsMap(data.json['budget']);
    final failed = data.tasks.where((t) => t.status == 'failed').toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'API-Football',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _metric(
                context,
                'Appels réservés le ${budget['budget_date'] ?? '—'}',
                budget['request_count'] ?? '—',
                context.brand.accent,
              ),
              const SizedBox(height: 12),
              const Text(
                'Ce compteur inclut les appels réservés, même si le fournisseur renvoie une erreur. Les données relues du cache ne consomment pas d’appel fournisseur.',
              ),
              const SizedBox(height: 16),
              const Text(
                'Disponibilité observée',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(
                data.cycleId == null
                    ? 'Aucun cycle sélectionné. Les erreurs des batchs lancés hors pilotage sont consultables dans Historique.'
                    : failed.isEmpty
                    ? 'Aucune erreur signalée dans le cycle sélectionné. Cela ne constitue pas un test de disponibilité du fournisseur.'
                    : '${failed.length} batch(s) en échec dans ce cycle.',
              ),
              for (final t in failed)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(t.name),
                  subtitle: _issue(t.error ?? ''),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    setState(() {
                      _tab = 0;
                      _selectedTask = t.id;
                    });
                    _load();
                  },
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _panel(
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Comment lire les données',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 12),
              Text(
                'Collecte → ce que le fournisseur renvoie ou ce qui est encore valide dans le cache.\n\nSnapshot → ce qui a été consolidé pour la compétition.\n\nPublication → ce qui est réellement mis à disposition de l’application.\n\nUn batch à 100 % a terminé les quatre étapes. Une collecte réussie ne suffit pas à prouver que les données sont visibles dans l’application.',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _issue(String message, {bool adminRequest = false, String? heading}) =>
      OperationsIssueCard(
        message: message,
        adminRequest: adminRequest,
        heading: heading,
        onReconnect: _auth == null
            ? null
            : () async {
                try {
                  await _auth!.signOut();
                  await _auth!.signInWithGoogle();
                } catch (e) {
                  if (mounted) setState(() => _commandError = e.toString());
                }
              },
      );

  Widget _panel({required Widget child}) => Card(
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget _notice(BuildContext context, String message, bool error) => Container(
    margin: const EdgeInsets.symmetric(vertical: 8),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: (error ? context.semantic.error : context.semantic.warning)
          .withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppRadius.odds),
    ),
    child: Text(
      message,
      style: TextStyle(
        color: error ? context.semantic.error : context.semantic.warning,
      ),
    ),
  );
  Widget _metric(
    BuildContext context,
    String label,
    Object? value,
    Color color,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        '$value',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(color: context.textColors.secondary, fontSize: 12),
      ),
    ],
  );
  Widget _badge(BuildContext context, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
    ),
  );
  Widget _json(BuildContext context, Object? value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    color: context.surfaces.backgroundSecondary,
    child: SelectableText(
      const JsonEncoder.withIndent('  ').convert(value),
      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
    ),
  );
}

class OperationsDag extends StatelessWidget {
  const OperationsDag({super.key, required this.task, required this.onStage});
  final OpsTask task;
  final ValueChanged<int> onStage;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final vertical = c.maxWidth < 450;
      final nodes = <Widget>[];
      for (var i = 0; i < 4; i++) {
        final done = i < task.stage, active = i == task.stage;
        final color = done
            ? context.semantic.success
            : active
            ? _color(context, task.status)
            : context.textColors.secondary;
        final label = done
            ? 'Terminé'
            : active
            ? task.label
            : 'À venir';
        final node = Semantics(
          label: '${opsStageNames[i]} : $label',
          button: true,
          child: InkWell(
            onTap: () => onStage(i),
            borderRadius: BorderRadius.circular(AppRadius.button),
            child: Container(
              width: vertical ? double.infinity : null,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(AppRadius.button),
                border: Border.all(color: color.withValues(alpha: .5)),
              ),
              child: Column(
                children: [
                  Icon(
                    done
                        ? Icons.check_circle
                        : active && task.status == 'running'
                        ? Icons.sync
                        : Icons.circle_outlined,
                    color: color,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    opsStageNames[i],
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: color),
                  ),
                ],
              ),
            ),
          ),
        );
        nodes.add(vertical ? node : Expanded(child: node));
        if (i < 3) {
          nodes.add(
            Icon(
              vertical ? Icons.south : Icons.east,
              size: 18,
              color: context.textColors.secondary,
            ),
          );
        }
      }
      return vertical
          ? Column(children: nodes)
          : Row(crossAxisAlignment: CrossAxisAlignment.center, children: nodes);
    },
  );
}

Color _color(BuildContext context, String status) => switch (status) {
  'running' => context.semantic.info,
  'succeeded' => context.semantic.success,
  'failed' => context.semantic.error,
  'cancelled' => context.textColors.weak,
  _ => context.textColors.secondary,
};
String _date(Object? value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  return d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${_time(value)}';
}

String _time(Object? value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  return d == null
      ? '—'
      : '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}:${d.second.toString().padLeft(2, '0')}';
}

String _enrichmentPhaseLabel(String phase) => switch (phase) {
  'bulk' => 'collecte des données liées aux matchs',
  'player_pages' => 'pages de statistiques joueurs',
  'activity_players' => 'profils des joueurs retenus',
  'activity_fixtures' => 'matchs de leurs clubs',
  'activity_sheets' => 'statistiques des matchs de clubs',
  'terminé' => 'enrichissement terminé',
  _ => phase,
};

String _duration(Map<String, dynamic> value) {
  final start = DateTime.tryParse('${value['started_at']}');
  if (start == null) return 'non démarré';
  final end = DateTime.tryParse('${value['finished_at']}') ?? DateTime.now();
  final seconds = end.difference(start).inSeconds;
  return seconds < 60 ? '${seconds}s' : '${seconds ~/ 60}m ${seconds % 60}s';
}

const _weekdays = [
  'Dimanche',
  'Lundi',
  'Mardi',
  'Mercredi',
  'Jeudi',
  'Vendredi',
  'Samedi',
];
