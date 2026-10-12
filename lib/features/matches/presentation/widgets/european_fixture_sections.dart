import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../core/domain/compact_match_data.dart';
import '../../../../core/theme/app_components.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/competition_card_theme.dart';
import '../../../../core/widgets/recent_form_strip.dart';
import '../../../../core/widgets/sports_asset_badge.dart';
import '../../../shortlist/presentation/shortlist_actions.dart';
import '../../domain/european_fixture_comparison.dart';
import '../../domain/match_board_item.dart';

CompetitionCardIdentity _identity(CompetitionInfo c) =>
    switch (c.apiFootballLeagueId) {
      2 => CompetitionCardIdentity.champions,
      3 => CompetitionCardIdentity.europa,
      848 => CompetitionCardIdentity.conference,
      _ => CompetitionCardIdentity.generic,
    };
String europeanPhaseLabel(String? round) => (round ?? 'Phase non précisée')
    .replaceAll('League Stage', 'Phase de ligue')
    .replaceAll('Group Stage', 'Phase de groupes')
    .replaceAll('Round of 16', 'Huitièmes de finale')
    .replaceAll('Quarter-finals', 'Quarts de finale')
    .replaceAll('Semi-finals', 'Demi-finales')
    .replaceAll('Final', 'Finale')
    .replaceAll('Qualifying', 'Qualifications');

class EuropeanMatchHero extends StatelessWidget {
  const EuropeanMatchHero({
    required this.match,
    required this.comparison,
    super.key,
  });
  final MatchBoardItem match;
  final EuropeanFixtureComparison comparison;
  @override
  Widget build(BuildContext context) {
    final theme = CompetitionCardTheme(context, _identity(match.competition)),
        f = match.fixture,
        k = f.kickoff?.toLocal();
    return _Panel(
      title: null,
      backgroundAsset: _identity(match.competition).backgroundAsset,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  k == null
                      ? 'Horaire à confirmer'
                      : DateFormat('EEE d MMM · HH:mm', 'fr').format(k),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.textColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  europeanPhaseLabel(f.round),
                  textAlign: TextAlign.end,
                  style: TextStyle(fontSize: 11, color: theme.accent),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: _HeroTeam(
                  team: match.homeTeam,
                  contextData: comparison.home,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    if (f.score != null)
                      Text(
                        '${f.score!.home} – ${f.score!.away}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    Text(
                      switch (f.status) {
                        FixtureStatus.live => 'En direct',
                        FixtureStatus.finished => 'Terminé',
                        FixtureStatus.scheduled => 'À venir',
                        FixtureStatus.postponed => 'Reporté',
                        FixtureStatus.cancelled => 'Annulé',
                      },
                      style: TextStyle(
                        fontSize: 11,
                        color: f.status == FixtureStatus.live
                            ? context.semantic.live
                            : theme.accent,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _HeroTeam(
                  team: match.awayTeam,
                  contextData: comparison.away,
                ),
              ),
            ],
          ),
          if (f.venue?.name != null) ...[
            const SizedBox(height: 14),
            Divider(color: context.surfaces.border, height: 1),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.stadium_outlined,
                  size: 15,
                  color: context.textColors.secondary,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    [
                      f.venue!.name,
                      f.venue!.city,
                    ].whereType<String>().join(' · '),
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textColors.secondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _HeroTeam extends StatelessWidget {
  const _HeroTeam({required this.team, required this.contextData});
  final TeamInfo team;
  final EuropeanTeamContext contextData;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SportsAssetBadge(
        size: 48,
        imageUrl: team.logoUrl,
        fallbackLabel: team.name,
        backgroundColor: AppColors.transparent,
      ),
      const SizedBox(height: 6),
      Text(
        team.name,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      if (contextData.domesticCompetition != null)
        Text(
          '${contextData.domesticCompetition!.country.name}${contextData.domesticStanding?.rank == null ? '' : ' · ${contextData.domesticStanding!.rank}e'}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: context.textColors.secondary),
        ),
    ],
  );
}

class EuropeanComparisonSections extends StatelessWidget {
  const EuropeanComparisonSections({
    required this.comparison,
    required this.index,
    this.onOpenPrevious,
    super.key,
  });
  final EuropeanFixtureComparison comparison;
  final int index;
  final ValueChanged<Map<String, dynamic>>? onOpenPrevious;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      if (index == 0) ...[
        _synthesis(context),
        const SizedBox(height: 10),
        _form(context, false),
        const SizedBox(height: 10),
        _domestic(context),
        const SizedBox(height: 10),
        _europe(context, false),
      ],
      if (index == 1) ...[
        _domestic(context),
        const SizedBox(height: 10),
        _form(context, false),
        const SizedBox(height: 10),
        _europe(context, true),
      ],
      if (index == 2) ...[
        _domestic(context),
        const SizedBox(height: 10),
        _Panel(
          title: 'Classement européen',
          icon: Icons.leaderboard_outlined,
          subtitle: 'Position officielle connue avant la confrontation',
          child: _pair(
            context,
            (t) => _standing(context, t, t.europeanStanding),
          ),
        ),
      ],
      if (index == 3) ...[
        _form(context, true),
        const SizedBox(height: 10),
        _europe(context, true),
      ],
      if (index == 4) _headToHead(context),
      const SizedBox(height: 10),
      _quality(context),
    ],
  );
  Widget _pair(BuildContext c, Widget Function(EuropeanTeamContext) builder) =>
      LayoutBuilder(
        builder: (c, constraints) {
          final vertical =
              constraints.maxWidth < 290 ||
              MediaQuery.textScalerOf(c).scale(12) > 16;
          return vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    builder(comparison.home),
                    const SizedBox(height: 16),
                    builder(comparison.away),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: builder(comparison.home)),
                    const SizedBox(width: 16),
                    Expanded(child: builder(comparison.away)),
                  ],
                );
        },
      );
  Widget _team(BuildContext c, EuropeanTeamContext t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SportsAssetBadge(
          size: 25,
          imageUrl: t.team.logoUrl,
          fallbackLabel: t.team.name,
          backgroundColor: AppColors.transparent,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            t.team.name,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  Widget _synthesis(BuildContext c) => _Panel(
    title: 'Ce qu’il faut retenir',
    icon: Icons.track_changes_outlined,
    child: comparison.notices.isEmpty
        ? Text(
            'Le contexte disponible ne permet pas encore de confronter les deux dynamiques. Consultez les parcours et leurs limites.',
            style: TextStyle(fontSize: 13, color: c.textColors.secondary),
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final n
                  in (comparison.notices.toList()..sort(
                        (a, b) =>
                            const {
                              'comparison': 0,
                              'contradiction': 1,
                              'fact': 2,
                              'limit': 3,
                            }[a['kind']]!.compareTo(
                              const {
                                'comparison': 0,
                                'contradiction': 1,
                                'fact': 2,
                                'limit': 3,
                              }[b['kind']]!,
                            ),
                      ))
                      .take(4))
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        switch (n['kind']) {
                          'comparison' => 'Comparaison contextualisée',
                          'contradiction' => 'Dynamiques contrastées',
                          'limit' => 'Échantillon limité',
                          _ => 'Fait observable',
                        },
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: n['kind'] == 'limit'
                              ? c.semantic.warning
                              : c.semantic.info,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${n['text']}',
                        style: const TextStyle(fontSize: 13, height: 1.4),
                      ),
                      if ((n['fixtureIds'] as List? ?? []).isNotEmpty)
                        Text(
                          'Sources : ${(n['fixtureIds'] as List).take(5).map((id) => '#$id').join(', ')}${(n['fixtureIds'] as List).length > 5 ? ' · +${(n['fixtureIds'] as List).length - 5}' : ''}',
                          style: TextStyle(
                            fontSize: 10,
                            color: c.textColors.secondary,
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
  );
  Widget _domestic(BuildContext c) => _Panel(
    title: 'Situation domestique',
    icon: Icons.bar_chart_rounded,
    subtitle: 'Deux championnats, deux contextes · avant le match',
    child: _pair(
      c,
      (t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _team(c, t),
          if (t.domesticCompetition == null)
            _missing(c, 'Championnat et saison non résolus')
          else ...[
            Text(
              t.domesticCompetition!.name,
              style: TextStyle(fontSize: 12, color: c.semantic.info),
            ),
            Text(
              'Saison ${t.domesticCompetition!.season}',
              style: TextStyle(fontSize: 10, color: c.textColors.secondary),
            ),
            const SizedBox(height: 8),
            _standing(c, t, t.domesticStanding, showTeam: false),
          ],
        ],
      ),
    ),
  );
  Widget _standing(
    BuildContext c,
    EuropeanTeamContext t,
    TeamStandingSnapshot? s, {
    bool showTeam = true,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (showTeam) _team(c, t),
      if (s == null)
        _missing(c, 'Classement antérieur indisponible')
      else ...[
        Text(
          '${s.rank == null ? 'Position —' : '${s.rank}e position'} · ${s.points == null ? 'points —' : '${s.points} pts'}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 5),
        Text(
          '${s.played == null ? 'Matchs —' : '${s.played} matchs'} · ${s.wins ?? '—'}V ${s.draws ?? '—'}N ${s.losses ?? '—'}D',
          style: TextStyle(fontSize: 11, color: c.textColors.secondary),
        ),
        if (s.goalDiff != null)
          Text(
            'Diff. buts : ${s.goalDiff! > 0 ? '+' : ''}${s.goalDiff}',
            style: TextStyle(fontSize: 11, color: c.textColors.secondary),
          ),
      ],
    ],
  );
  Widget _form(BuildContext c, bool details) => _Panel(
    title: 'Forme récente en championnat',
    icon: Icons.auto_graph_rounded,
    subtitle: 'Jusqu’à 5 matchs · du plus ancien au plus récent',
    child: _pair(
      c,
      (t) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _team(c, t),
          RecentFormStrip(
            snapshot: RecentFormSnapshot(
              teamId: t.team.id,
              scope: MatchFormScope.championship,
              results: [
                for (final m in t.domesticMatches)
                  RecentFormObservation(
                    result: m.result,
                    playedAt: m.playedAt,
                    fixtureId: '${m.fixtureId}',
                  ),
              ],
            ),
            teamName: t.team.name,
            compact: true,
          ),
          const SizedBox(height: 8),
          _summary(c, t.domesticSummary),
          if (t.domesticMatches.isNotEmpty)
            _matches(
              c,
              t,
              t.domesticMatches,
              details ? 'Résultats de championnat' : 'Voir les résultats',
            ),
        ],
      ),
    ),
  );
  Widget _europe(BuildContext c, bool details) => _Panel(
    title: 'Parcours européen',
    icon: Icons.sports_soccer_rounded,
    subtitle:
        '${switch (comparison.home.phase) {
          'league' => 'Phase de ligue / groupes',
          'qualification' => 'Qualifications',
          'knockout' => 'Élimination directe',
          _ => 'Phase à confirmer',
        }} · saison ${((comparison.json['competition'] as Map?)?['season']) ?? '—'}',
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _pair(
          c,
          (t) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _team(c, t),
              if (t.phaseMatches.isEmpty)
                _missing(
                  c,
                  t.europeanCoverageComplete
                      ? 'Aucun résultat dans cette phase avant le match'
                      : 'Résultats européens non récupérés',
                )
              else ...[
                RecentFormStrip(
                  snapshot: RecentFormSnapshot(
                    teamId: t.team.id,
                    scope: MatchFormScope.competition,
                    results: [
                      for (final m in t.phaseMatches)
                        RecentFormObservation(
                          result: m.result,
                          playedAt: m.playedAt,
                          fixtureId: '${m.fixtureId}',
                        ),
                    ],
                  ),
                  teamName: t.team.name,
                  compact: true,
                ),
                const SizedBox(height: 8),
                _summary(c, t.europeanSummary, points: t.phase == 'league'),
                if (t.phaseMatches.length < 3)
                  Text(
                    'Échantillon limité : ${t.phaseMatches.length} match(s)',
                    style: TextStyle(fontSize: 11, color: c.semantic.warning),
                  ),
                _matches(c, t, t.phaseMatches, 'Adversaires et scores'),
              ],
              if (t.europeanMatches.length > t.phaseMatches.length)
                _matches(
                  c,
                  t,
                  t.europeanMatches,
                  'Toutes les phases (${t.europeanMatches.length})',
                ),
              if (t.europeanStanding != null) ...[
                const SizedBox(height: 8),
                _standing(c, t, t.europeanStanding, showTeam: false),
              ],
            ],
          ),
        ),
        if (comparison.firstLeg != null) ...[
          const Divider(height: 20),
          Text(
            'Avant le retour · aller : ${comparison.home.team.name} ${comparison.firstLeg!['goalsFor']} – ${comparison.firstLeg!['goalsAgainst']} ${comparison.away.team.name}',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Text(
            'Score cumulé après 1 rencontre ; le retour n’est pas inclus.',
            style: TextStyle(fontSize: 11, color: c.textColors.secondary),
          ),
        ],
      ],
    ),
  );
  Widget _summary(
    BuildContext c,
    Map<String, Object?>? s, {
    bool points = true,
  }) => s == null
      ? _missing(c, 'Bilan indisponible')
      : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s['wins']}V · ${s['draws']}N · ${s['losses']}D',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              points
                  ? '${s['points']}/${(s['played'] as num) * 3} points · ${s['played']} matchs'
                  : '${s['played']} matchs disputés',
              style: TextStyle(fontSize: 11, color: c.textColors.secondary),
            ),
            Text(
              '${s['goalsFor']} marqués · ${s['goalsAgainst']} encaissés',
              style: TextStyle(fontSize: 11, color: c.textColors.secondary),
            ),
          ],
        );
  Widget _matches(
    BuildContext c,
    EuropeanTeamContext t,
    List<TeamRecentMatchSnapshot> matches,
    String title,
  ) => Theme(
    data: Theme.of(c).copyWith(dividerColor: AppColors.transparent),
    child: ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      expandedCrossAxisAlignment: CrossAxisAlignment.start,
      minTileHeight: 44,
      title: Text(
        title,
        style: TextStyle(fontSize: 11, color: c.semantic.info),
      ),
      children: [
        for (final m in matches)
          InkWell(
            onTap: m.fixtureId == null || onOpenPrevious == null
                ? null
                : () => onOpenPrevious!({
                    'sport': 'football',
                    'matchId': 'api-fixture-${m.fixtureId}',
                    'kickoff': m.playedAt!.toIso8601String(),
                    'home': m.venue == RecentMatchVenue.home
                        ? t.team.name
                        : m.opponentName,
                    'away': m.venue == RecentMatchVenue.home
                        ? m.opponentName
                        : t.team.name,
                  }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (m.round != null)
                    Text(
                      europeanPhaseLabel(m.round),
                      style: TextStyle(
                        fontSize: 10,
                        color: c.textColors.secondary,
                      ),
                    ),
                  Text(
                    '${DateFormat('dd/MM/yy').format(m.playedAt!.toLocal())} · ${m.venue == RecentMatchVenue.home ? 'Dom.' : 'Ext.'}',
                    style: TextStyle(
                      fontSize: 10,
                      color: c.textColors.secondary,
                    ),
                  ),
                  Text(
                    '${m.opponentName} · ${m.goalsFor}–${m.goalsAgainst}${m.penaltyDecision ? ' (t.a.b.)' : ''}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
  Widget _headToHead(BuildContext c) => _Panel(
    title: 'Historique des confrontations',
    icon: Icons.history_rounded,
    subtitle:
        '${comparison.headToHead.length} rencontre(s) antérieure(s) disponibles',
    child: comparison.headToHead.isEmpty
        ? _missing(c, 'Aucun historique commun pertinent disponible')
        : Column(
            children: [
              for (final m in comparison.headToHead)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${m.homeTeamName} ${m.homeGoals} – ${m.awayGoals} ${m.awayTeamName}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(m.playedAt.toLocal())} · ${m.competitionName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: c.textColors.secondary,
                    ),
                  ),
                  trailing: m.fixtureId == null
                      ? null
                      : const Icon(Icons.chevron_right, size: 18),
                  onTap: m.fixtureId == null || onOpenPrevious == null
                      ? null
                      : () => onOpenPrevious!({
                          'sport': 'football',
                          'matchId': 'api-fixture-${m.fixtureId}',
                          'kickoff': m.playedAt.toIso8601String(),
                          'home': m.homeTeamName,
                          'away': m.awayTeamName,
                        }),
                ),
              Text(
                'Les confrontations anciennes décrivent l’historique ; elles ne déterminent pas le rapport de forces actuel.',
                style: TextStyle(fontSize: 11, color: c.textColors.secondary),
              ),
            ],
          ),
  );
  Widget _quality(BuildContext c) => _Panel(
    title: 'Données et limites',
    icon: Icons.info_outline_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Situation arrêtée au ${DateFormat('dd/MM/yyyy · HH:mm').format(comparison.kickoffAt.toLocal())}',
          style: TextStyle(fontSize: 11, color: c.textColors.secondary),
        ),
        if (comparison.capturedAt != null)
          Text(
            'Publication : ${DateFormat('dd/MM/yyyy · HH:mm').format(comparison.capturedAt!.toLocal())}',
            style: TextStyle(fontSize: 11, color: c.textColors.secondary),
          ),
        if (comparison.stale)
          Text(
            'Publication ancienne : une actualisation est recommandée.',
            style: TextStyle(fontSize: 12, color: c.semantic.warning),
          ),
        for (final l in comparison.limitations)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              l,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: c.textColors.secondary,
              ),
            ),
          ),
      ],
    ),
  );
  Widget _missing(BuildContext c, String text) => Text(
    text,
    style: TextStyle(fontSize: 12, height: 1.4, color: c.textColors.secondary),
  );
}

class EuropeanMatchActions extends StatelessWidget {
  const EuropeanMatchActions({
    required this.match,
    this.onCompare,
    this.onAsk,
    super.key,
  });
  final MatchBoardItem match;
  final VoidCallback? onCompare, onAsk;
  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    child: Container(
      decoration: BoxDecoration(
        color: context.surfaces.background,
        border: Border(top: BorderSide(color: context.surfaces.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          ShortlistAddButton(fixture: shortlistFootball(match)),
          const SizedBox(width: 4),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCompare,
              icon: const Icon(Icons.compare_arrows, size: 18),
              label: const Text('Comparer', style: TextStyle(fontSize: 11)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onAsk,
              icon: const Icon(Icons.auto_awesome, size: 17),
              label: const Text(
                'Demander à Lector',
                style: TextStyle(fontSize: 11),
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                backgroundColor: context.semantic.info,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.child,
    this.subtitle,
    this.icon,
    this.backgroundAsset,
  });
  final String? title, subtitle, backgroundAsset;
  final IconData? icon;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      border: Border.all(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Stack(
      children: [
        if (backgroundAsset != null)
          Positioned.fill(
            child: Opacity(
              opacity: .20,
              child: Image.asset(backgroundAsset!, fit: BoxFit.cover),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null) ...[
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 19, color: context.semantic.info),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.textColors.secondary,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
              child,
            ],
          ),
        ),
      ],
    ),
  );
}
