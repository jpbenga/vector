import 'package:flutter/material.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/widgets/lector_standing_table.dart';
import '../../../core/widgets/lector_standing_context.dart';
import '../../../core/theme/app_components.dart';
import '../domain/hockey_standing_view.dart';
import '../domain/hockey_match_standing_context.dart';
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
  int _group = -1, _scope = 0, _level = 0;
  final _panelKey = GlobalKey();
  void selectGroup(int index) {
    setState(() {
      _group = index;
      if (index == -1) _level = 0;
    });
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
  HockeyMatchStandingContext get comparison =>
      HockeyMatchStandingContext(c, teams);
  List<int> get matchGroups => comparison.localGroups;
  int get activeGroup => _group;
  List<int> get displayedGroups => switch (_level) {
    1 => comparison.divisions,
    2 => comparison.conferences,
    _ => comparison.primaryGroups,
  };
  String get comparisonLabel => comparison.description;
  String get pairedTitle {
    final kinds = data.groups
        .where((g) => displayedGroups.contains(g.tableIndex))
        .map((g) => g.kind)
        .toSet();
    return kinds.length != 1
        ? 'LEURS CLASSEMENTS COMPLETS'
        : kinds.single == SportStandingGroupKind.division
        ? 'LEURS DIVISIONS COMPLÈTES'
        : kinds.single == SportStandingGroupKind.conference
        ? 'LEURS CONFÉRENCES COMPLÈTES'
        : 'LEURS CLASSEMENTS COMPLETS';
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
      _level = 0;
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
        goalsDifference: row.goalsFor == null || row.goalsAgainst == null
            ? null
            : row.goalsFor! - row.goalsAgainst!,
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
    final groups = displayedGroups;
    // A common conference table must not erase the opponents' local context.
    final performanceGroups = _level == 0 ? matchGroups : groups;
    final compareFirst =
        _level == 0 &&
        comparison.relation != HockeyStandingRelation.sameDivision &&
        comparison.relation != HockeyStandingRelation.sameGroup;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (opposing.isEmpty)
          const Text(
            'Classement complet non disponible dans ce périmètre. Les données manquantes ne sont pas remplacées par des zéros.',
          )
        else if (_level != 1 &&
            comparison.completeLevel(SportStandingGroupKind.division) &&
            comparison.completeLevel(SportStandingGroupKind.conference))
          LectorStandingHierarchyComparison(
            calculated: _scope != 0,
            localTeams: [
              for (final (index, row) in opposing) teamContext(row, index),
            ],
            conferenceTeams: [
              for (final id in teams)
                if (comparison.groupFor(id, SportStandingGroupKind.conference)
                    case final int index)
                  if (comparison.row(id, _scope, group: index)
                      case final SportStandingRow row)
                    teamContext(row, index),
            ],
          )
        else if (matchGroups.length > 1)
          LectorStandingPositionComparison(
            title: positionTitle(opposing),
            teams: [
              for (final (index, row) in opposing) teamContext(row, index),
            ],
          ),
        if (compareFirst && opposing.isNotEmpty) ...[
          const SizedBox(height: 12),
          paceComparison(opposing),
        ],
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 12),
          if (groups.length == 1)
            rankingCard(groups.single)
          else
            LectorStandingContextCard(
              title: pairedTitle,
              subtitle:
                  'Chaque tableau conserve tous les membres de son groupe.',
              child: Row(
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
          const SizedBox(height: 8),
          if (groups.length == 1)
            const Text(
              'V : toutes les victoires · D : défaites en temps réglementaire · OT : défaites après prolongation ou tirs au but.',
            ),
        ],
        if (opposing.isNotEmpty) ...[
          if (!compareFirst) ...[
            const SizedBox(height: 12),
            paceComparison(opposing),
          ],
          const SizedBox(height: 12),
          LectorStandingContextCard(
            title: 'Face aux autres groupes',
            subtitle:
                'Points obtenus face aux équipes hors du groupe, rapportés au maximum possible. Ce n’est pas une mesure absolue de niveau.',
            child: pair([
              for (final index in performanceGroups)
                performance(
                  data.groups.firstWhere((g) => g.tableIndex == index),
                  side: performanceGroups.length == 1
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
            title: 'LECTURE DU CONTEXTE LECTOR',
            subtitle:
                'Interprétation descriptive · distincte du classement officiel',
            child: Text(synthesis()),
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

  Widget paceComparison(List<(int, SportStandingRow)> opposing) =>
      LectorStandingPaceComparison(
        teams: [for (final (index, row) in opposing) teamContext(row, index)],
        competitionName: c.name,
        maximum: data.maximumPoints,
        mean: HockeyStandingView.leagueMean(c, _scope),
        summary: comparison.commonFacts(_scope),
      );

  String synthesis() {
    final facts = [comparison.interpretation(_scope)];
    for (final id in teams) {
      final row = comparison.row(id, 0);
      final scope = id == widget.homeTeamId ? 1 : 2;
      final venue = comparison.row(id, scope);
      if (venue != null && venue.played > 0) {
        facts.add(
          '${venue.team.name} ${scope == 1 ? 'à domicile' : 'à l’extérieur'} : ${venue.wins + (venue.overtimeWins ?? 0)} victoires en ${venue.played} matchs.',
        );
      }
      if (c.formPhaseVerified &&
          row != null &&
          row.form.length == 5 &&
          row.form.every(
            (g) =>
                g.startsAt.isBefore(data.collectedAt) &&
                ['FT', 'AOT', 'AP', 'APEN'].contains(g.providerStatus),
          )) {
        final wins = row.form
            .where((g) => g.outcome == SportFormOutcome.win)
            .length;
        facts.add(
          '${row.team.name} : $wins victoires sur les cinq derniers matchs vérifiés.',
        );
      }
    }
    if (!c.formPhaseVerified) {
      facts.add(
        'La forme récente n’est pas intégrée ici : sa phase de compétition n’est pas vérifiée.',
      );
    }
    return facts.join('\n\n');
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
          ? Text(
              'Classement complet indisponible : les ${c.tables[index].rows.length} équipes ne disposent pas toutes d’un bilan vérifié dans ce périmètre.',
            )
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
        if (_group >= 0)
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
        OutlinedButton.icon(
          key: const ValueKey('all-standing-groups'),
          onPressed: pick,
          icon: const Icon(Icons.format_list_numbered),
          label: const Text('Tous les classements'),
        ),
        if (teams.length == 2) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              for (final (index, label) in [
                'Vue du match',
                'Divisions',
                'Conférences',
              ].indexed)
                if (index == 0 ||
                    (index == 1 ? comparison.divisions : comparison.conferences)
                        .isNotEmpty)
                  Expanded(
                    child: TextButton(
                      key: ValueKey('hockey-standing-level-$index'),
                      onPressed: () => setState(() {
                        _group = -1;
                        _level = index;
                      }),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 10,
                        ),
                        backgroundColor: _group < 0 && _level == index
                            ? context.brand.accent.withValues(alpha: .16)
                            : null,
                        foregroundColor: _group < 0 && _level == index
                            ? context.brand.accent
                            : context.textColors.secondary,
                      ),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
            ],
          ),
          const SizedBox(height: 8),
          Text(comparisonLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
        if (activeGroup >= 0) ...[
          const SizedBox(height: 8),
          Text(
            c.tables[activeGroup].group,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ],
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
