import 'hockey_grouped_standings_panel.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_competition_context.dart';
import '../../../core/sports/domain/sport_fixture.dart';
import '../../../core/theme/app_components.dart';
import '../../../core/widgets/lector_match_card.dart';
import '../../../core/widgets/lector_radar.dart';
import '../../../core/widgets/lector_result_badge.dart';
import '../../../core/widgets/lector_standing_table.dart';
import '../domain/hockey_standing_tiers.dart';
import '../domain/hockey_standing_view.dart';
import 'hockey_standing_tier_presentation.dart';

class HockeyFormStrip extends StatelessWidget {
  const HockeyFormStrip({required this.results, super.key});
  final List<SportFormResult> results;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final r in results)
        Tooltip(
          message:
              '${DateFormat('dd/MM').format(r.startsAt.toLocal())} · ${r.home ? 'Dom.' : 'Ext.'} ${r.opponent} · ${r.scored}–${r.conceded}${r.providerStatus == 'AOT'
                  ? ' · Prolongation'
                  : r.providerStatus == 'AP' || r.providerStatus == 'APEN'
                  ? ' · Tirs au but'
                  : ''}',
          child: LectorResultBadge(
            result: r.outcome == SportFormOutcome.win
                ? 'W'
                : r.outcome == SportFormOutcome.loss
                ? 'L'
                : 'D',
          ),
        ),
    ],
  );
}

/// Same square form cells as the football team Radar, using hockey outcomes.
class HockeyRadarFormStrip extends StatelessWidget {
  const HockeyRadarFormStrip({
    required this.results,
    this.onMatchTap,
    super.key,
  });
  final List<SportFormResult> results;
  final ValueChanged<int>? onMatchTap;
  @override
  Widget build(BuildContext context) => LectorFormResultStrip(
    historyColumns: 5,
    results: results
        .map(
          (r) => switch (r.outcome) {
            SportFormOutcome.win => 'W',
            SportFormOutcome.loss => 'L',
            SportFormOutcome.draw => 'D',
          },
        )
        .toList(),
    tooltips: results
        .map(
          (r) =>
              '${DateFormat('dd/MM').format(r.startsAt.toLocal())} · ${r.home ? 'Dom.' : 'Ext.'} ${r.opponent} · ${r.scored}–${r.conceded}',
        )
        .toList(),
    onMatchTap: onMatchTap,
  );
}

class HockeyFormDetails extends StatelessWidget {
  const HockeyFormDetails({
    required this.team,
    required this.results,
    this.selectedIndex,
    super.key,
  });
  final SportParticipant team;
  final List<SportFormResult> results;
  final int? selectedIndex;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LectorTeamLine(name: team.name, logoUrl: team.logoUrl),
      const SizedBox(height: 8),
      if (selectedIndex != null && selectedIndex! < results.length) ...[
        Text(
          'Match sélectionné',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          '${DateFormat('dd/MM').format(results[selectedIndex!].startsAt.toLocal())} · ${results[selectedIndex!].home ? 'Dom.' : 'Ext.'} · ${results[selectedIndex!].opponent} · ${results[selectedIndex!].scored}–${results[selectedIndex!].conceded}',
        ),
        const SizedBox(height: 12),
      ],
      if (results.isEmpty)
        const Text(
          'Historique insuffisant ou phase des rencontres non renseignée.',
        )
      else ...[
        HockeyFormStrip(results: results),
        const SizedBox(height: 8),
        for (final r in results)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Text(DateFormat('dd/MM').format(r.startsAt.toLocal())),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${r.home ? 'Dom.' : 'Ext.'} · ${r.opponent}'),
                ),
                const SizedBox(width: 8),
                Text('${r.scored}–${r.conceded}'),
              ],
            ),
          ),
      ],
      const SizedBox(height: 16),
    ],
  );
}

/// Hockey supplies table data; the complete presentation belongs to Lector.
class HockeyStandingsPanel extends StatefulWidget {
  const HockeyStandingsPanel({
    required this.competition,
    this.homeTeamId,
    this.awayTeamId,
    super.key,
  });
  final SportCompetitionContext competition;
  final SportEntityId? homeTeamId, awayTeamId;
  @override
  State<HockeyStandingsPanel> createState() => _HockeyStandingsPanelState();
}

class _HockeyStandingsPanelState extends State<HockeyStandingsPanel> {
  int _group = -1, _scope = 0;
  @override
  void didUpdateWidget(covariant HockeyStandingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.competition.id != widget.competition.id ||
        oldWidget.homeTeamId != widget.homeTeamId ||
        oldWidget.awayTeamId != widget.awayTeamId) {
      _group = -1;
      _scope = 0;
    }
  }

  LectorStandingRole _role(SportEntityId id) => id == widget.homeTeamId
      ? LectorStandingRole.home
      : id == widget.awayTeamId
      ? LectorStandingRole.away
      : LectorStandingRole.none;

  static const _columns = [
    LectorStandingColumn('J', 23),
    LectorStandingColumn('V', 22),
    LectorStandingColumn('D', 22),
    LectorStandingColumn('BP', 25),
    LectorStandingColumn('BC', 25),
    LectorStandingColumn('Diff', 31),
    LectorStandingColumn('Pts', 28, bold: true),
  ];

  List<SportStandingTable> _matchTables(List<SportStandingTable> tables) {
    if (tables.isEmpty) return const [];
    if (_group >= 0) return [tables[_group.clamp(0, tables.length - 1)]];
    bool includes(SportStandingTable t, SportEntityId? id) =>
        t.rows.any((r) => r.team.id == id);
    final common =
        tables
            .where(
              (t) =>
                  includes(t, widget.homeTeamId) &&
                  includes(t, widget.awayTeamId),
            )
            .toList()
          ..sort((a, b) => b.rows.length.compareTo(a.rows.length));
    if (common.isNotEmpty) return [common.first];
    final selected = <SportStandingTable>[];
    // Both official groups remain visible for a cross-conference opposition.
    // Their positions are NEVER merged into a fictitious league-wide ranking.
    for (final id in [widget.homeTeamId, widget.awayTeamId]) {
      final candidates = tables.where((t) => includes(t, id)).toList()
        ..sort((a, b) => b.rows.length.compareTo(a.rows.length));
      if (candidates.isNotEmpty && !selected.contains(candidates.first)) {
        selected.add(candidates.first);
      }
    }
    return selected.isEmpty ? [tables.first] : selected;
  }

  Widget _officialTable(BuildContext context, SportStandingTable table) {
    final classification = HockeyStandingTiers.classify(
      table,
      competition: widget.competition,
      scope: _scope,
    );
    final rows = [...table.rows]..sort((a, b) => a.rank.compareTo(b.rank));
    final entries = <LectorStandingEntry>[];
    for (final row in rows) {
      final difference = row.goalsFor == null || row.goalsAgainst == null
          ? null
          : row.goalsFor! - row.goalsAgainst!;
      final entry = LectorStandingEntry(
        identity: row.team.id.key,
        name: row.team.name,
        logoUrl: row.team.logoUrl,
        rank: '${row.rank}',
        role: _role(row.team.id),
        rankDescription: row.description,
        rankColor: row.description == null ? null : context.brand.accent,
        values: [
          LectorStandingValue('${row.played}'),
          LectorStandingValue('${row.wins + (row.overtimeWins ?? 0)}'),
          LectorStandingValue('${row.losses + (row.overtimeLosses ?? 0)}'),
          LectorStandingValue(row.goalsFor?.toString() ?? '—'),
          LectorStandingValue(row.goalsAgainst?.toString() ?? '—'),
          LectorStandingValue(
            difference == null
                ? '—'
                : '${difference > 0 ? '+' : ''}$difference',
          ),
          LectorStandingValue('${row.points}'),
        ],
      );
      entries.add(entry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HockeyStandingTierPresentation.legend(context, rows, classification),
        LectorStandingDataTable(
          columns: _columns,
          groups: HockeyStandingTierPresentation.groups(
            context,
            entries,
            classification,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.competition.standingContext != null) {
      return HockeyGroupedStandingsPanel(
        competition: widget.competition,
        homeTeamId: widget.homeTeamId,
        awayTeamId: widget.awayTeamId,
      );
    }
    final competition = widget.competition, tables = competition.tables;
    final displayed = _matchTables(tables), venue = competition.venueStandings;
    final calculated = venue?.hasCalculatedPoints ?? false;
    final venueRows = _scope == 0
        ? <SportVenueStandingRow>[]
        : [...?(_scope == 1 ? venue?.home : venue?.away)];
    if (calculated) {
      venueRows.sort((a, b) => a.rank.compareTo(b.rank));
    } else {
      venueRows.sort((a, b) => a.team.name.compareTo(b.team.name));
    }
    final scopeLabel = _scope == 1 ? 'à domicile' : 'à l’extérieur';
    return LectorStandingPanel<int>(
      description: _scope == 0
          ? 'Points et positions officiels · ${competition.name}'
          : calculated
          ? 'Classement $scopeLabel par points · saison régulière'
          : 'Bilan $scopeLabel · points et positions non fournis dans cette publication.',
      views: [
        for (final (i, label) in ['Général', 'Domicile', 'Extérieur'].indexed)
          LectorStandingViewOption(
            value: i,
            label: label,
            key: ValueKey('hockey-standing-scope-$i'),
          ),
      ],
      selectedView: _scope,
      onSelected: (value) => setState(() => _scope = value),
      groupSelector: _scope == 0 && tables.length > 1
          ? DropdownButtonFormField<int>(
              key: ValueKey(
                '${competition.id.key}-${widget.homeTeamId?.key}-${widget.awayTeamId?.key}',
              ),
              initialValue: _group,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Conférence ou division',
              ),
              items: [
                const DropdownMenuItem(
                  value: -1,
                  child: Text('Équipes du match'),
                ),
                for (final (i, t) in tables.indexed)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      t.group,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _group = value);
              },
            )
          : null,
      footer: Text(
        _scope == 0
            ? 'Classement de la dernière collecte ; il ne reconstitue pas la situation au jour d’un ancien match.'
            : calculated
            ? '${venue!.status == 'partial' ? 'Couverture à confirmer : les résultats collectés ne correspondent pas encore à tous les bilans officiels. ' : 'Bilans domicile + extérieur vérifiés contre le classement général. '}Classement calculé : points, différence de buts, puis buts marqués. Les départages officiels peuvent différer.'
            : 'Les résultats détaillés de saison sont nécessaires pour calculer les points par lieu.',
      ),
      child: _scope == 0
          ? displayed.isEmpty
                ? const Text('Classement non fourni pour cette compétition.')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, table) in displayed.indexed) ...[
                        if (i > 0) const SizedBox(height: 16),
                        Text(
                          table.group,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 8),
                        _officialTable(context, table),
                      ],
                    ],
                  )
          : calculated && displayed.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final original in displayed)
                  _officialTable(
                    context,
                    SportStandingTable(
                      stage: original.stage,
                      group: original.group,
                      rows: HockeyStandingView.rows(
                        competition,
                        tables.indexOf(original),
                        _scope,
                      ),
                    ),
                  ),
              ],
            )
          : venueRows.isEmpty
          ? const Text(
              'Résultats de saison non disponibles pour ce classement.',
            )
          : LectorStandingDataTable(
              columns: _columns,
              groups: [
                LectorStandingGroupData(
                  rows: [
                    for (final row in venueRows)
                      LectorStandingEntry(
                        identity: row.team.id.key,
                        name: row.team.name,
                        logoUrl: row.team.logoUrl,
                        rank: calculated ? '${row.rank}' : '—',
                        role: _role(row.team.id),
                        values: [
                          LectorStandingValue('${row.played}'),
                          LectorStandingValue('${row.wins}'),
                          LectorStandingValue('${row.losses}'),
                          LectorStandingValue('${row.goalsFor}'),
                          LectorStandingValue('${row.goalsAgainst}'),
                          LectorStandingValue(
                            '${row.goalsFor - row.goalsAgainst > 0 ? '+' : ''}${row.goalsFor - row.goalsAgainst}',
                          ),
                          LectorStandingValue(
                            calculated ? '${row.points}' : '—',
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}
