import 'package:flutter/material.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/widgets/lector_standing_table.dart';
import '../../../core/widgets/lector_standing_context.dart';
import '../../../core/theme/app_components.dart';
import '../domain/hockey_standing_view.dart';
import '../domain/hockey_standing_tiers.dart';
import 'hockey_standing_tier_presentation.dart';

/// Sport adapter for the common grouped-standings journey. No provider calls
/// or private ranking/row renderer belong to this widget.
class HockeyGroupedStandingsPanel extends StatefulWidget {
  const HockeyGroupedStandingsPanel({
    required this.competition,
    this.homeTeamId,
    this.awayTeamId,
    super.key,
  });
  final SportCompetitionContext competition;
  final SportEntityId? homeTeamId, awayTeamId;
  @override
  State<HockeyGroupedStandingsPanel> createState() =>
      _HockeyGroupedStandingsPanelState();
}

class _HockeyGroupedStandingsPanelState
    extends State<HockeyGroupedStandingsPanel> {
  int _group = -1, _scope = 0;
  final _panelKey = GlobalKey();
  void selectGroup(int index) {
    setState(() => _group = index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _panelKey.currentContext;
      if (mounted && target != null) {
        Scrollable.ensureVisible(
          target,
          alignment: 0,
          duration: const Duration(milliseconds: 220),
        );
      }
    });
  }

  SportCompetitionContext get c => widget.competition;
  SportStandingContext get data => c.standingContext!;
  List<int> get matchGroups => {
    for (final id in teams)
      if (HockeyStandingView.localGroup(c, id) case final int index) index,
  }.toList();
  int get activeGroup => _group >= 0
      ? _group
      : matchGroups.length == 1
      ? matchGroups.single
      : -1;
  String get comparisonLabel {
    final kinds = matchGroups
        .map((i) => data.groups.firstWhere((g) => g.tableIndex == i).kind)
        .toSet();
    if (kinds.length == 1 && kinds.single == SportStandingGroupKind.division) {
      return 'Deux divisions différentes';
    }
    if (kinds.length == 1 &&
        kinds.single == SportStandingGroupKind.conference) {
      return 'Deux conférences différentes';
    }
    return 'Deux groupes différents';
  }

  List<SportEntityId> get teams => [
    if (widget.awayTeamId != null) widget.awayTeamId!,
    if (widget.homeTeamId != null) widget.homeTeamId!,
  ];
  @override
  void didUpdateWidget(covariant HockeyGroupedStandingsPanel old) {
    super.didUpdateWidget(old);
    if (old.competition.id != c.id ||
        old.homeTeamId != widget.homeTeamId ||
        old.awayTeamId != widget.awayTeamId) {
      _group = -1;
      _scope = 0;
    } else if (_group >= 0 && !data.groups.any((g) => g.tableIndex == _group)) {
      _group = -1;
    }
  }

  LectorStandingRole role(SportEntityId id) => id == widget.homeTeamId
      ? LectorStandingRole.home
      : id == widget.awayTeamId
      ? LectorStandingRole.away
      : LectorStandingRole.none;
  String kind(SportStandingGroupContext g) => switch (g.kind) {
    SportStandingGroupKind.conference => 'conférences',
    SportStandingGroupKind.division => 'divisions',
    SportStandingGroupKind.league => 'groupes',
  };
  LectorStandingTeamContext teamContext(SportStandingRow row, int index) =>
      LectorStandingTeamContext(
        name: row.team.name,
        logoUrl: row.team.logoUrl,
        role: role(row.team.id),
        group: c.tables[index].group,
        position: row.rank,
        groupSize: c.tables[index].rows.length,
        played: row.played,
        points: row.points,
      );
  List<(int, SportStandingRow)> opposition() => [
    for (final id in teams)
      if (HockeyStandingView.localGroup(c, id) case final int index)
        if (HockeyStandingView.rows(
              c,
              index,
              _scope,
            ).where((r) => r.team.id == id).firstOrNull
            case final SportStandingRow row)
          (index, row),
  ];
  Future<void> pick() async {
    final ordered = [...data.groups]
      ..sort((a, b) {
        int priority(SportStandingGroupContext g) =>
            g.kind == SportStandingGroupKind.conference
            ? 0
            : g.kind == SportStandingGroupKind.division
            ? 1
            : 2;
        final result = priority(a).compareTo(priority(b));
        if (result != 0) return result;
        return (a.parentTableIndex ?? -1).compareTo(b.parentTableIndex ?? -1);
      });
    final selected = await showLectorStandingPicker(
      context,
      competition: '${c.name} · Saison régulière',
      selected: activeGroup,
      options: [
        const LectorStandingPickerOption(
          value: -1,
          title: 'Vue du match',
          subtitle: 'Situer les deux adversaires',
          section: '',
        ),
        for (final g in ordered)
          LectorStandingPickerOption(
            value: g.tableIndex,
            title: c.tables[g.tableIndex].group,
            subtitle: '${c.tables[g.tableIndex].rows.length} équipes',
            section: kind(g),
            parent: g.parentTableIndex == null
                ? null
                : c.tables[g.parentTableIndex!].group,
            roles: [
              for (final r in c.tables[g.tableIndex].rows)
                if (role(r.team.id) != LectorStandingRole.none)
                  (r.team.name, role(r.team.id)),
            ],
          ),
      ],
    );
    if (selected != null && mounted) selectGroup(selected);
  }

  Widget performance(
    SportStandingGroupContext group, {
    LectorStandingRole side = LectorStandingRole.none,
  }) {
    final r = group.forScope(_scope);
    return LectorStandingGroupPerformance(
      name: c.tables[group.tableIndex].group,
      kindLabel: kind(group),
      played: r?.played,
      points: r?.points,
      maximumPoints: data.maximumPoints,
      shortSample:
          r != null && r.played < HockeyStandingView.minimumInterGroupGames,
      role: side,
    );
  }

  Widget pair(List<Widget> children) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 240
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final child in children)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: child,
                ),
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(child: child),
              ],
            ],
          ),
  );
  String positionTitle(List<(int, SportStandingRow)> opposition) {
    final kinds = opposition
        .map((t) => data.groups.firstWhere((g) => g.tableIndex == t.$1).kind)
        .toSet();
    return kinds.length == 1 && kinds.single == SportStandingGroupKind.division
        ? 'POSITION DANS LEUR DIVISION'
        : kinds.length == 1 && kinds.single == SportStandingGroupKind.conference
        ? 'POSITION DANS LEUR CONFÉRENCE'
        : 'POSITION DANS LEUR GROUPE';
  }

  Widget overview() {
    final opposing = opposition();
    final groups = matchGroups;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (opposing.isEmpty)
          const Text(
            'Classement non disponible pour les équipes du match dans ce périmètre.',
          )
        else ...[
          LectorStandingPositionComparison(
            title: positionTitle(opposing),
            teams: [
              for (final (index, row) in opposing) teamContext(row, index),
            ],
          ),
        ],
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          LectorStandingContextCard(
            title: 'LEURS CLASSEMENTS',
            child: LayoutBuilder(
              builder: (context, constraints) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (i, index) in groups.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: rankingCard(index, compact: true, canOpen: true),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (opposing.isNotEmpty) ...[
          const SizedBox(height: 12),
          LectorStandingPaceComparison(
            teams: [
              for (final (index, row) in opposing) teamContext(row, index),
            ],
            competitionName: c.name,
            maximum: data.maximumPoints,
            mean: HockeyStandingView.leagueMean(c, _scope),
          ),
          const SizedBox(height: 12),
          LectorStandingContextCard(
            title: 'Face aux autres groupes',
            subtitle:
                'Points obtenus face aux équipes hors du groupe, rapportés au maximum possible. Ce n’est pas une mesure absolue de niveau.',
            child: pair([
              for (final index in groups)
                performance(
                  data.groups.firstWhere((g) => g.tableIndex == index),
                  side: groups.length == 1
                      ? LectorStandingRole.none
                      : role(
                          c.tables[index].rows
                              .firstWhere((r) => teams.contains(r.team.id))
                              .team
                              .id,
                        ),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          LectorStandingContextCard(
            title: 'Lecture du contexte',
            child: Text(synthesis(opposing)),
          ),
        ],
        const SizedBox(height: 12),
        OutlinedButton.icon(
          key: const ValueKey('explore-standing-groups'),
          onPressed: pick,
          icon: const Icon(Icons.format_list_numbered),
          label: const Text('Explorer les classements'),
        ),
      ],
    );
  }

  String synthesis(List<(int, SportStandingRow)> opposition) {
    if (opposition.length != 2 || opposition.any((t) => t.$2.played == 0)) {
      return 'Pas encore assez de résultats pour comparer le rendement des deux équipes.';
    }
    final a = opposition[0].$2, b = opposition[1].$2;
    final gap = a.pointsPerGame - b.pointsPerGame;
    final pace = gap.abs() < .005
        ? 'Les deux équipes ont le même rendement en points par match.'
        : '${gap > 0 ? a.team.name : b.team.name} obtient davantage de points par match.';
    if (opposition[0].$1 == opposition[1].$1) {
      return '$pace Les deux équipes évoluent dans le même groupe. Ces repères ne prédisent pas le résultat du match.';
    }
    final ga = data.groups.firstWhere((g) => g.tableIndex == opposition[0].$1),
        gb = data.groups.firstWhere((g) => g.tableIndex == opposition[1].$1);
    final ra = ga.forScope(_scope), rb = gb.forScope(_scope);
    if (data.maximumPoints == null ||
        ga.kind != gb.kind ||
        ra == null ||
        rb == null ||
        ra.played < HockeyStandingView.minimumInterGroupGames ||
        rb.played < HockeyStandingView.minimumInterGroupGames) {
      return '$pace La comparaison entre groupes demande davantage de résultats vérifiés. Ces repères ne prédisent pas le résultat du match.';
    }
    final diff =
        ra.share(data.maximumPoints!)! - rb.share(data.maximumPoints!)!;
    final cross = diff.abs() < .005
        ? 'Les groupes ont un rendement similaire face aux autres groupes.'
        : '${c.tables[diff > 0 ? ga.tableIndex : gb.tableIndex].group} obtient une plus grande part des points possibles face aux autres ${kind(ga)}.';
    return '$pace $cross Ces repères ne prédisent pas le résultat du match.';
  }

  Widget rankingCard(int index, {bool compact = false, bool canOpen = false}) {
    final rows = HockeyStandingView.rows(c, index, _scope);
    final classification = HockeyStandingTiers.classify(
      SportStandingTable(
        stage: c.tables[index].stage,
        group: c.tables[index].group,
        rows: rows,
      ),
      competition: c,
      scope: _scope,
    );
    return LectorStandingRankingCard(
      key: ValueKey('standing-ranking-$index'),
      title: c.tables[index].group,
      subtitle: c.tables[index].stage.toLowerCase().contains('regular')
          ? 'Saison régulière'
          : c.tables[index].stage,
      onOpen: canOpen ? () => selectGroup(index) : null,
      table: rows.isEmpty
          ? const Text('Résultats non disponibles pour ce périmètre.')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!compact)
                  HockeyStandingTierPresentation.legend(
                    context,
                    rows,
                    classification,
                  ),
                LectorStandingDataTable(
                  compact: compact,
                  cardStyle: true,
                  columns: compact
                      ? const [
                          LectorStandingColumn('J', 20),
                          LectorStandingColumn('Pts', 24, bold: true),
                        ]
                      : const [
                          LectorStandingColumn('J', 24),
                          LectorStandingColumn('V', 24),
                          LectorStandingColumn('D', 24),
                          LectorStandingColumn('OT', 24),
                          LectorStandingColumn('Pts', 30, bold: true),
                        ],
                  groups: HockeyStandingTierPresentation.groups(context, [
                    for (final r in rows)
                      LectorStandingEntry(
                        identity: r.team.id.key,
                        name: r.team.name,
                        logoUrl: r.team.logoUrl,
                        rank: '${r.rank}',
                        role: role(r.team.id),
                        rankDescription: r.description,
                        rankColor: r.description == null
                            ? null
                            : context.brand.accent,
                        secondaryText: compact
                            ? null
                            : '${lectorPointsPerGame(r.played == 0 ? null : r.pointsPerGame)} pts/match',
                        values: [
                          LectorStandingValue('${r.played}'),
                          if (!compact) ...[
                            LectorStandingValue(
                              '${r.wins + (r.overtimeWins ?? 0)}',
                            ),
                            LectorStandingValue('${r.losses}'),
                            LectorStandingValue('${r.overtimeLosses ?? '—'}'),
                          ],
                          LectorStandingValue('${r.points}'),
                        ],
                      ),
                  ], classification),
                ),
              ],
            ),
    );
  }

  Widget table(int index) {
    final group = data.groups.firstWhere((g) => g.tableIndex == index);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rankingCard(index),
        const SizedBox(height: 8),
        const Text(
          'V : toutes les victoires · D : défaites en temps réglementaire · OT : défaites après prolongation ou tirs au but.',
        ),
        const SizedBox(height: 12),
        LectorStandingContextCard(
          title: 'Face aux autres ${kind(group)}',
          child: performance(group),
        ),
        for (final (other, row) in opposition().where(
          (t) => !c.tables[index].rows.any((r) => r.team.id == t.$2.team.id),
        )) ...[
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => selectGroup(other),
            child: Text(
              '${row.team.name} ${role(row.team.id).label} · ${c.tables[other].group}',
            ),
          ),
        ],
        if (matchGroups.length > 1)
          TextButton(
            onPressed: () => selectGroup(-1),
            child: const Text('Retour à la vue du match'),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => LectorStandingPanel<int>(
    key: _panelKey,
    separateContent: true,
    segmentedViews: true,
    description: 'Situer les deux équipes · ${c.name}',
    views: [
      for (final (index, label) in ['Général', 'Domicile', 'Extérieur'].indexed)
        LectorStandingViewOption(
          value: index,
          label: label,
          key: ValueKey('hockey-standing-scope-$index'),
        ),
    ],
    selectedView: _scope,
    onSelected: (s) => setState(() => _scope = s),
    groupSelector: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (activeGroup >= 0)
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.groups_outlined),
            label: Text(
              activeGroup < 0 ? 'Vue du match' : c.tables[activeGroup].group,
            ),
          ),
        if (activeGroup < 0 && matchGroups.length > 1)
          Row(
            children: [
              const Icon(Icons.info_outline, size: 16),
              const SizedBox(width: 6),
              Expanded(child: Text(comparisonLabel)),
            ],
          ),
        if (activeGroup >= 0)
          for (final row in HockeyStandingView.rows(
            c,
            activeGroup,
            _scope,
          ).where((r) => role(r.team.id) != LectorStandingRole.none)) ...[
            const SizedBox(height: 8),
            LectorStandingFeaturedTeam(team: teamContext(row, activeGroup)),
          ],
      ],
    ),
    footer: Text(
      'Dernière collecte : ${data.collectedAt.toLocal().day}/${data.collectedAt.toLocal().month}. Ce classement ne reconstitue pas la situation au jour d’un ancien match.${_scope == 0 ? '' : ' Classement calculé par points, différence de buts, puis buts marqués ; les départages officiels peuvent différer.'}${c.venueStandings?.status == 'partial' ? ' Couverture partielle : bilans en cours de vérification.' : ''}',
    ),
    child: activeGroup < 0 ? overview() : table(activeGroup),
  );
}
