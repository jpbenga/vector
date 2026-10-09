import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import 'lector_glass_card.dart';
import 'lector_standing_table.dart';

/// Presentation-only data, shared by sports with grouped standings.
class LectorStandingTeamContext {
  const LectorStandingTeamContext({
    required this.name,
    required this.group,
    required this.role,
    required this.position,
    required this.groupSize,
    required this.played,
    required this.points,
    this.logoUrl,
    this.goalsDifference,
  });
  final String name, group;
  final String? logoUrl;
  final LectorStandingRole role;
  final int position, groupSize, played;
  final int? points;
  final int? goalsDifference;
  double? get pointsPerGame =>
      played == 0 || points == null ? null : points! / played;
}

String lectorPointsPerGame(double? value) =>
    value == null ? '—' : value.toStringAsFixed(2).replaceAll('.', ',');

class LectorStandingContextCard extends StatelessWidget {
  const LectorStandingContextCard({
    required this.title,
    required this.child,
    this.subtitle,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => LectorGlassCard(
    padding: const EdgeInsets.all(12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        ],
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// A complete ranking card in both its full and paired mobile presentations.
/// Sports supply the rows and factual columns to the same table renderer.
class LectorStandingRankingCard extends StatelessWidget {
  const LectorStandingRankingCard({
    required this.title,
    required this.table,
    this.subtitle,
    this.onOpen,
    super.key,
  });
  final String title;
  final String? subtitle;
  final Widget table;
  final VoidCallback? onOpen;
  @override
  Widget build(BuildContext context) => LectorGlassCard(
    padding: EdgeInsets.all(onOpen == null ? 12 : 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
        const SizedBox(height: 10),
        table,
        if (onOpen != null)
          TextButton(
            onPressed: onOpen,
            child: const Text('Voir le classement complet ›'),
          ),
      ],
    ),
  );
}

class LectorStandingFeaturedTeam extends StatelessWidget {
  const LectorStandingFeaturedTeam({required this.team, super.key});
  final LectorStandingTeamContext team;
  @override
  Widget build(BuildContext context) {
    final color = team.role.color(context) ?? context.brand.accent;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: Row(
        children: [
          Expanded(
            child: LectorStandingTeam(
              name: team.name,
              logoUrl: team.logoUrl,
              role: team.role,
              textColor: context.textColors.primary,
              secondaryMaxLines: 3,
              secondaryText:
                  '${team.points ?? '—'} pts · ${team.played} matchs · ${lectorPointsPerGame(team.pointsPerGame)} pts/match',
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${team.position}${team.position == 1 ? 'er' : 'e'} / ${team.groupSize}',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class LectorStandingPositionCard extends StatelessWidget {
  const LectorStandingPositionCard({
    required this.team,
    this.showIdentityBadge = true,
    super.key,
  });
  final LectorStandingTeamContext team;
  final bool showIdentityBadge;
  @override
  Widget build(BuildContext context) {
    final color = team.role.color(context) ?? context.brand.accent;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showIdentityBadge)
          LectorStandingTeam(
            name: team.name,
            logoUrl: team.logoUrl,
            textColor: context.textColors.primary,
            role: team.role,
          ),
        if (showIdentityBadge) const SizedBox(height: 10),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 3,
              height: 30,
              margin: const EdgeInsets.only(right: 9, top: 2),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(AppRadius.indicator),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!showIdentityBadge)
                    Text(
                      team.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  Text(
                    team.group,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${team.position}${team.position == 1 ? 'er' : 'e'}',
                style: TextStyle(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                ),
              ),
              TextSpan(
                text: ' / ${team.groupSize}',
                style: TextStyle(color: context.textColors.secondary),
              ),
            ],
          ),
          style: theme.textTheme.headlineMedium?.copyWith(
            fontSize: 28,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${team.points ?? '—'} pts · ${team.played} matchs',
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        LectorStandingPositionRail(
          position: team.position,
          groupSize: team.groupSize,
          color: color,
        ),
      ],
    );
  }
}

class LectorStandingPositionComparison extends StatelessWidget {
  const LectorStandingPositionComparison({
    required this.teams,
    required this.title,
    super.key,
  });
  final List<LectorStandingTeamContext> teams;
  final String title;
  @override
  Widget build(BuildContext context) => LectorStandingContextCard(
    title: title,
    child: Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, team) in teams.indexed) ...[
                if (i > 0)
                  VerticalDivider(
                    width: 22,
                    thickness: 1,
                    color: context.surfaces.border,
                  ),
                Expanded(
                  child: LectorStandingPositionCard(
                    team: team,
                    showIdentityBadge: false,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          teams.map((t) => t.group).toSet().length > 1
              ? 'Deux rangs locaux, deux groupes différents.'
              : 'Deux rangs locaux dans le même groupe.',
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
      ],
    ),
  );
}

/// Two official levels remain distinct; a local rank is never a league rank.
class LectorStandingHierarchyComparison extends StatelessWidget {
  const LectorStandingHierarchyComparison({
    required this.localTeams,
    required this.conferenceTeams,
    this.calculated = false,
    super.key,
  });
  final List<LectorStandingTeamContext> localTeams, conferenceTeams;
  final bool calculated;

  @override
  Widget build(BuildContext context) => LectorStandingContextCard(
    title: calculated ? 'POSITIONS DANS CE PÉRIMÈTRE' : 'POSITIONS OFFICIELLES',
    subtitle: calculated
        ? 'Classements calculés à domicile ou à l’extérieur'
        : 'Division et conférence · deux niveaux distincts',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (i, team) in localTeams.indexed) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LectorStandingPositionCard(team: team),
                if (conferenceTeams
                        .where((t) => t.role == team.role)
                        .firstOrNull
                    case final LectorStandingTeamContext conference) ...[
                  const SizedBox(height: 12),
                  Text(
                    conference.group,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: context.textColors.secondary,
                    ),
                  ),
                  Text(
                    '${conference.position}${conference.position == 1 ? 'er' : 'e'} / ${conference.groupSize}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ],
    ),
  );
}

class LectorStandingPositionRail extends StatelessWidget {
  const LectorStandingPositionRail({
    required this.position,
    required this.groupSize,
    required this.color,
    super.key,
  });
  final int position, groupSize;
  final Color color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Position $position sur $groupSize',
    excludeSemantics: true,
    child: Row(
      children: [
        Text(
          '1er',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: context.textColors.secondary,
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: SizedBox(
            height: 20,
            child: CustomPaint(
              painter: _StandingPositionPainter(
                position: position,
                groupSize: groupSize,
                color: color,
                muted: context.textColors.secondary,
                surface: context.surfaces.surface,
              ),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '${groupSize}e',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            color: context.textColors.secondary,
          ),
        ),
      ],
    ),
  );
}

class _StandingPositionPainter extends CustomPainter {
  const _StandingPositionPainter({
    required this.position,
    required this.groupSize,
    required this.color,
    required this.muted,
    required this.surface,
  });
  final int position, groupSize;
  final Color color, muted, surface;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0;
    final width = (size.width - 2 * inset).clamp(0.0, double.infinity),
        y = size.height / 2;
    canvas.drawLine(
      Offset(inset, y),
      Offset(inset + width, y),
      Paint()
        ..color = muted
        ..strokeWidth = 1,
    );
    for (var i = 1; i <= groupSize; i++) {
      final point = Offset(
        inset +
            (groupSize <= 1 ? width / 2 : width * (i - 1) / (groupSize - 1)),
        y,
      );
      canvas.drawCircle(
        point,
        i == position ? 4.5 : 2,
        Paint()..color = i == position ? color : surface,
      );
      canvas.drawCircle(
        point,
        i == position ? 4.5 : 2,
        Paint()
          ..color = i == position ? color : muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StandingPositionPainter old) =>
      old.position != position ||
      old.groupSize != groupSize ||
      old.color != color ||
      old.muted != muted ||
      old.surface != surface;
}

class LectorStandingPaceComparison extends StatelessWidget {
  const LectorStandingPaceComparison({
    required this.teams,
    required this.maximum,
    required this.mean,
    this.competitionName,
    this.summary,
    super.key,
  });
  final List<LectorStandingTeamContext> teams;
  final int? maximum;
  final double? mean;
  final String? competitionName;
  final String? summary;
  @override
  Widget build(BuildContext context) => LectorGlassCard(
    padding: const EdgeInsets.all(14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'REPÈRE COMMUN${competitionName == null ? '' : ' · $competitionName'}',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Comprendre le repère commun',
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                showDragHandle: true,
                builder: (context) => SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Text(
                      'Les points par match placent les équipes sur la même échelle, avec le barème de cette ligue. La moyenne est pondérée par les matchs joués et chaque équipe est comptée une seule fois. Ce repère ne corrige pas la difficulté du calendrier et ne prédit pas le résultat du match.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              ),
              icon: Icon(
                Icons.info_outline,
                size: 18,
                color: context.textColors.secondary,
              ),
            ),
          ],
        ),
        Text(
          'Points par match',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: context.textColors.secondary),
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, t) in teams.indexed)
              Expanded(
                child: Column(
                  crossAxisAlignment: i == 0
                      ? CrossAxisAlignment.start
                      : CrossAxisAlignment.end,
                  children: [
                    Text(
                      lectorPointsPerGame(t.pointsPerGame),
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color:
                                t.role.color(context) ?? context.brand.accent,
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            height: 1.1,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      t.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (t.goalsDifference case final int difference) ...[
                      const SizedBox(height: 4),
                      Text(
                        'Diff. buts : ${difference > 0 ? '+' : ''}$difference',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (maximum != null)
          LectorStandingPaceAxis(
            teams: teams,
            maximum: maximum!,
            mean: mean,
            competitionName: competitionName,
          )
        else
          Text(
            'Barème indisponible · moyenne de la ligue : ${lectorPointsPerGame(mean)} pts/match',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        if (summary != null) ...[
          const SizedBox(height: 12),
          Text(summary!, style: Theme.of(context).textTheme.bodySmall),
        ],
      ],
    ),
  );
}

/// One common numerical axis: unlike progress bars, every marker and the
/// weighted league mean use the same bounds. Missing values have no marker.
class LectorStandingPaceAxis extends StatelessWidget {
  const LectorStandingPaceAxis({
    required this.teams,
    required this.maximum,
    required this.mean,
    this.competitionName,
    super.key,
  });
  final List<LectorStandingTeamContext> teams;
  final int maximum;
  final double? mean;
  final String? competitionName;
  @override
  Widget build(BuildContext context) => Semantics(
    label: [
      'Échelle commune : 0 à $maximum points par match',
      'Moyenne de la ligue : ${lectorPointsPerGame(mean)}',
      for (final team in teams)
        '${team.name} : ${lectorPointsPerGame(team.pointsPerGame)}',
    ].join('. '),
    excludeSemantics: true,
    child: LayoutBuilder(
      builder: (context, constraints) {
        const inset = 5.0;
        final width = (constraints.maxWidth - 2 * inset).clamp(
          0.0,
          double.infinity,
        );
        double x(double v) => inset + width * (v / maximum).clamp(0.0, 1.0);
        double left(double v, double labelWidth) =>
            (x(v) - labelWidth / 2).clamp(
              0.0,
              (constraints.maxWidth - labelWidth).clamp(0.0, double.infinity),
            );
        final muted = context.textColors.secondary;
        return SizedBox(
          height: 114,
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _StandingPacePainter(
                    maximum: maximum,
                    mean: mean,
                    values: [
                      for (final team in teams)
                        if (team.pointsPerGame != null)
                          (
                            team.pointsPerGame!,
                            team.role.color(context) ?? context.brand.accent,
                          ),
                    ],
                    muted: muted,
                  ),
                ),
              ),
              if (mean != null)
                Positioned(
                  top: 0,
                  left: left(mean!, 164),
                  width: 164,
                  child: Text(
                    'Moyenne ${competitionName ?? 'ligue'} · ${lectorPointsPerGame(mean)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: muted,
                      fontSize: 10,
                    ),
                  ),
                ),
              for (final (i, team) in teams.indexed)
                if (team.pointsPerGame != null)
                  Positioned(
                    top: i.isEven ? 23 : 64,
                    left: left(team.pointsPerGame!, 62),
                    width: 62,
                    child: Text(
                      '${team.role.label ?? team.name}\n${lectorPointsPerGame(team.pointsPerGame)}',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: team.role.color(context) ?? context.brand.accent,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        height: 1.05,
                      ),
                    ),
                  ),
              Positioned(
                bottom: 0,
                left: 0,
                child: Text(
                  '0',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Text(
                  '$maximum pts/match',
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: muted),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _StandingPacePainter extends CustomPainter {
  const _StandingPacePainter({
    required this.maximum,
    required this.mean,
    required this.values,
    required this.muted,
  });
  final int maximum;
  final double? mean;
  final List<(double, Color)> values;
  final Color muted;
  @override
  void paint(Canvas canvas, Size size) {
    const inset = 5.0, y = 56.0;
    final width = (size.width - 2 * inset).clamp(0.0, double.infinity);
    double x(double value) => inset + width * (value / maximum).clamp(0.0, 1.0);
    final stroke = Paint()
      ..color = muted
      ..strokeWidth = 1;
    canvas.drawLine(const Offset(inset, y), Offset(inset + width, y), stroke);
    for (var i = 0; i <= 4; i++) {
      canvas.drawLine(
        Offset(inset + width * i / 4, y - 4),
        Offset(inset + width * i / 4, y + 4),
        stroke,
      );
    }
    if (mean != null) {
      for (var top = 18.0; top < y; top += 7) {
        canvas.drawLine(
          Offset(x(mean!), top),
          Offset(x(mean!), (top + 4).clamp(0.0, y)),
          stroke,
        );
      }
    }
    if (values.length > 1) {
      canvas.drawLine(
        Offset(x(values.first.$1), y),
        Offset(x(values.last.$1), y),
        Paint()
          ..color = values.first.$2
          ..strokeWidth = 2,
      );
    }
    for (final (value, color) in values) {
      canvas.drawCircle(Offset(x(value), y), 5, Paint()..color = color);
    }
    if (values.length == 2 &&
        (x(values.first.$1) - x(values.last.$1)).abs() < 1) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(x(values.first.$1), y), radius: 5),
        1.570796,
        3.141593,
        true,
        Paint()..color = values.first.$2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StandingPacePainter old) =>
      old.maximum != maximum ||
      old.mean != mean ||
      old.muted != muted ||
      !listEquals(old.values, values);
}

class LectorStandingGroupPerformance extends StatelessWidget {
  const LectorStandingGroupPerformance({
    required this.name,
    required this.kindLabel,
    required this.played,
    required this.points,
    required this.maximumPoints,
    this.role = LectorStandingRole.none,
    this.shortSample = false,
    super.key,
  });
  final bool shortSample;
  final String name, kindLabel;
  final int? played, points, maximumPoints;
  final LectorStandingRole role;
  @override
  Widget build(BuildContext context) {
    final valid =
        played != null &&
        played! > 0 &&
        points != null &&
        maximumPoints != null;
    final share = valid ? points! / (played! * maximumPoints!) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          name,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          share == null ? '—' : '${(100 * share).round()} %',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: role.color(context) ?? context.brand.accent,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          valid
              ? '$points / ${played! * maximumPoints!} points possibles · $played matchs'
              : played == 0
              ? 'Aucun match face aux autres $kindLabel.'
              : 'Comparaison indisponible : résultats à vérifier.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (valid && shortSample)
          Text(
            'Échantillon encore court',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: context.textColors.secondary,
            ),
          ),
      ],
    );
  }
}

class LectorStandingPickerOption {
  const LectorStandingPickerOption({
    required this.value,
    required this.title,
    required this.subtitle,
    required this.section,
    this.parent,
    this.roles = const [],
  });
  final int value;
  final String title, subtitle, section;
  final String? parent;
  final List<(String, LectorStandingRole)> roles;
}

Future<int?> showLectorStandingPicker(
  BuildContext context, {
  required String competition,
  required int selected,
  required List<LectorStandingPickerOption> options,
}) => showModalBottomSheet<int>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  backgroundColor: context.surfaces.surface,
  builder: (context) => SafeArea(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .8,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Voir un classement',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Fermer',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Text(competition, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (index, option) in options.indexed) ...[
                      if (option.section.isNotEmpty &&
                          (index == 0 ||
                              options[index - 1].section != option.section))
                        Padding(
                          padding: const EdgeInsets.only(top: 16, bottom: 6),
                          child: Text(
                            option.section.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: context.textColors.secondary),
                          ),
                        ),
                      if (option.parent != null &&
                          (index == 0 ||
                              options[index - 1].parent != option.parent))
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 4),
                          child: Text(
                            option.parent!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                      ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 6,
                        ),
                        key: ValueKey('standing-picker-${option.value}'),
                        title: Text(option.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(option.subtitle),
                            for (final (name, role) in option.roles)
                              Wrap(
                                spacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(name),
                                  LectorStandingSidePill(
                                    label: role.label!,
                                    color: role.color(context)!,
                                  ),
                                ],
                              ),
                          ],
                        ),
                        trailing: selected == option.value
                            ? Icon(Icons.check, color: context.brand.accent)
                            : const Icon(Icons.chevron_right),
                        onTap: () => Navigator.pop(context, option.value),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
