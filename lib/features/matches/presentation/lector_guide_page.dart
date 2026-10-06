import '../../../core/domain/lector_victory_series.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/widgets/lector_responsive_layout.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import '../domain/football_scenario.dart';
import '../domain/lector_guide_catalog.dart';

void openReadingGuide(
  BuildContext context,
  String readingId, {
  bool? isFollowed,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          LectorReadingGuidePage(readingId: readingId, isFollowed: isFollowed),
    ),
  );
}

void openScenarioGuide(
  BuildContext context,
  String scenarioId, {
  bool? isFollowed,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => LectorScenarioGuidePage(
        scenarioId: scenarioId,
        isFollowed: isFollowed,
      ),
    ),
  );
}

class LectorReadingGuidePage extends StatelessWidget {
  const LectorReadingGuidePage({
    required this.readingId,
    this.isFollowed,
    super.key,
  });
  final String readingId;
  final bool? isFollowed;

  @override
  Widget build(BuildContext context) {
    final guide =
        LectorGuideCatalog.readings[canonicalVenueReadingId(readingId)];
    final label = LectorGuideCatalog.readingLabel(readingId);
    final identity = context.opportunities.readingIdentityForId(readingId);
    final badge = identity.badgeFor(AppReadingBadgeVariant.soft);
    return _GuideShell(
      title: label,
      children: [
        _GuideIntro(
          kind: 'Lecture',
          title: label,
          description:
              guide?.meaning ??
              'Les critères détaillés de cette lecture ne sont pas encore documentés.',
          icon: identity.icon,
          iconColor: badge.iconColor,
          background: badge.background,
          isFollowed: isFollowed,
        ),
        if (guide != null) ...[
          _GuideSection(
            title: 'Ce que Lector observe',
            child: _GuidePanel(
              child: Column(
                children: [
                  for (final entry in guide.conditions.indexed)
                    _GuideFact(text: entry.$2, number: entry.$1 + 1),
                ],
              ),
            ),
          ),
          _GuideSection(
            title: 'Un exemple concret',
            subtitle:
                'Exemple fictif · Atlas et Rivage sont des équipes imaginaires.',
            child: _GuidePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final fact in guide.facts) _GuideFact(text: fact),
                  const SizedBox(height: 8),
                  _GuideVerdict(text: guide.conclusion, detected: true),
                ],
              ),
            ),
          ),
          _GuideSection(
            title: 'Quand le critère n’est pas rempli',
            child: _GuidePanel(
              child: _GuideFact(
                text: guide.counterExample,
                icon: Icons.remove_circle_outline_rounded,
                color: context.semantic.error,
              ),
            ),
          ),
          _GuideSection(
            title: 'Si les données manquent',
            child: const _GuidePanel(
              child: Text(
                'Lector doit disposer des données nécessaires pour vérifier les critères. '
                'Une lecture absente peut correspondre à un critère non rempli ou à des '
                'informations insuffisantes. Cela ne prouve pas le constat inverse.',
              ),
            ),
          ),
        ],
        _GuidePanel(
          child: Text(
            ReadingPreferenceCatalog.contains(readingId)
                ? 'Suivre cette lecture permet de la prendre en compte dans vos informations personnalisées. '
                      'Elle apparaît sur un match lorsque ses critères sont effectivement détectés.'
                : 'Cette lecture contribue aux scénarios. Elle n’est pas proposée comme réglage de suivi séparé.',
            style: TextStyle(color: context.textColors.secondary),
          ),
        ),
      ],
    );
  }
}

class LectorScenarioGuidePage extends StatefulWidget {
  const LectorScenarioGuidePage({
    required this.scenarioId,
    this.isFollowed,
    super.key,
  });
  final String scenarioId;
  final bool? isFollowed;
  @override
  State<LectorScenarioGuidePage> createState() =>
      _LectorScenarioGuidePageState();
}

class _LectorScenarioGuidePageState extends State<LectorScenarioGuidePage> {
  bool _omitLast = false;

  @override
  Widget build(BuildContext context) {
    final profile = OpportunityProfileCatalog.byId(widget.scenarioId);
    final definition = profile?.scenario;
    final title = profile?.displayLabel ?? 'Scénario';
    final identity = context.opportunities.scenarioIdentityForProfileId(
      widget.scenarioId,
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.combined);
    final example = definition == null
        ? null
        : LectorScenarioExample(definition);
    return _GuideShell(
      title: title,
      children: [
        _GuideIntro(
          kind: 'Scénario',
          title: title,
          description:
              profile?.description ?? 'Ce scénario n’est pas documenté.',
          icon: identity.icon,
          iconColor: badge.iconColor,
          background: badge.background,
          isFollowed: widget.isFollowed,
        ),
        if (definition != null && example != null) ...[
          _GuideSection(
            title: 'Comment Lector le détecte',
            subtitle:
                'Un scénario combine plusieurs lectures. Toutes les conditions ci-dessous doivent être réunies.',
            child: _RequirementDiagram(definition: definition, title: title),
          ),
          _GuidePanel(
            child: _GuideFact(
              icon: Icons.account_tree_outlined,
              text: definition.scope == FootballScenarioScope.team
                  ? 'Les lectures marquées « Même équipe » doivent concerner une seule '
                        'et même équipe. Un avantage pour Atlas et un autre pour Rivage ne se cumulent pas.'
                  : 'Le profil concerne le match. La tendance complémentaire doit être '
                        'détectée pour au moins une des deux équipes.',
            ),
          ),
          _GuideSection(
            title: 'Essayez sur un exemple',
            subtitle:
                'Atlas–Rivage · Exemple fictif, avec des lectures supposées déjà détectées.',
            child: _GuidePanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        key: const ValueKey('guide-example-complete'),
                        label: const Text('Conditions réunies'),
                        selected: !_omitLast,
                        onSelected: (_) => setState(() => _omitLast = false),
                      ),
                      ChoiceChip(
                        key: const ValueKey('guide-example-incomplete'),
                        label: const Text('Condition manquante'),
                        selected: _omitLast,
                        onSelected: (_) => setState(() => _omitLast = true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final entry in definition.requirements.indexed)
                    _GuideFact(
                      text:
                          '${example.subjectName(entry.$2.subject)} · '
                          '${LectorGuideCatalog.readingLabel(entry.$2.readingId)}',
                      detail:
                          _omitLast &&
                              entry.$1 == definition.requirements.length - 1
                          ? 'Lecture non détectée dans cet exemple'
                          : 'Lecture détectée dans cet exemple',
                      icon:
                          _omitLast &&
                              entry.$1 == definition.requirements.length - 1
                          ? Icons.remove_circle_outline_rounded
                          : Icons.check_circle_outline_rounded,
                      color:
                          _omitLast &&
                              entry.$1 == definition.requirements.length - 1
                          ? context.semantic.error
                          : context.semantic.success,
                    ),
                  const SizedBox(height: 8),
                  _GuideVerdict(
                    key: const ValueKey('guide-scenario-verdict'),
                    detected: example.detected(omitLast: _omitLast),
                    text: example.detected(omitLast: _omitLast)
                        ? 'Scénario détecté : toutes les lectures requises sont réunies.'
                        : 'Scénario non détecté : une condition requise manque.',
                  ),
                ],
              ),
            ),
          ),
          _GuideSection(
            title: 'Comprendre les lectures utilisées',
            subtitle:
                'Ouvrez chaque lecture pour voir ses critères et ses exemples.',
            child: _GuidePanel(
              child: Column(
                children: [
                  for (final requirement in definition.requirements)
                    ListTile(
                      key: ValueKey(
                        'guide-reading-link-${requirement.readingId}',
                      ),
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        LectorGuideCatalog.readingLabel(requirement.readingId),
                      ),
                      subtitle: Text(
                        LectorGuideCatalog.requirementSubjectLabel(
                          requirement.subject,
                        ),
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () =>
                          openReadingGuide(context, requirement.readingId),
                    ),
                ],
              ),
            ),
          ),
        ],
        const _GuidePanel(
          child: Text(
            'Le scénario décrit des constats réunis avant le match. Le résultat du match '
            'reste à observer. Suivre un scénario permet de le prendre en compte dans vos informations personnalisées.',
          ),
        ),
      ],
    );
  }
}

class _GuideShell extends StatelessWidget {
  const _GuideShell({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: context.surfaces.background,
    appBar: AppBar(
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      leading: IconButton(
        tooltip: 'Retour',
        icon: const Icon(Icons.arrow_back_rounded),
        onPressed: () => Navigator.of(context).pop(),
      ),
    ),
    body: SafeArea(
      top: false,
      child: LectorContent(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final entry in children.indexed) ...[
                entry.$2,
                if (entry.$1 != children.length - 1) const SizedBox(height: 24),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _GuideIntro extends StatelessWidget {
  const _GuideIntro({
    required this.kind,
    required this.title,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.background,
    this.isFollowed,
  });
  final String kind;
  final String title;
  final String description;
  final IconData icon;
  final Color iconColor;
  final Color background;
  final bool? isFollowed;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(AppRadius.card),
        ),
        child: Icon(icon, color: iconColor, size: 32),
      ),
      const SizedBox(height: 12),
      Text(
        kind.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: context.textColors.secondary),
      ),
      const SizedBox(height: 6),
      Text(
        title,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 10),
      Text(
        description,
        textAlign: TextAlign.center,
        style: TextStyle(color: context.textColors.secondary, height: 1.45),
      ),
      if (isFollowed != null) ...[
        const SizedBox(height: 12),
        Chip(
          avatar: Icon(
            isFollowed! ? Icons.check_rounded : Icons.remove_rounded,
            size: 18,
          ),
          label: Text(
            isFollowed! ? 'Dans vos préférences' : 'Hors de vos préférences',
          ),
        ),
      ],
    ],
  );
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({
    required this.title,
    required this.child,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 6),
        Text(subtitle!, style: TextStyle(color: context.textColors.secondary)),
      ],
      const SizedBox(height: 12),
      child,
    ],
  );
}

class _GuidePanel extends StatelessWidget {
  const _GuidePanel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Material(
    color: context.surfaces.surface,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: context.surfaces.border),
      borderRadius: BorderRadius.circular(AppRadius.card),
    ),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  );
}

class _GuideFact extends StatelessWidget {
  const _GuideFact({
    required this.text,
    this.detail,
    this.number,
    this.icon,
    this.color,
  });
  final String text;
  final String? detail;
  final int? number;
  final IconData? icon;
  final Color? color;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 24,
          child: number != null
              ? Text(
                  '$number.',
                  style: TextStyle(
                    color: context.brand.accent,
                    fontWeight: FontWeight.w800,
                  ),
                )
              : Icon(
                  icon ?? Icons.circle,
                  size: icon == null ? 7 : 21,
                  color: color ?? context.brand.accent,
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: const TextStyle(height: 1.4)),
              if (detail != null) ...[
                const SizedBox(height: 4),
                Text(
                  detail!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuideVerdict extends StatelessWidget {
  const _GuideVerdict({required this.text, required this.detected, super.key});
  final String text;
  final bool detected;
  @override
  Widget build(BuildContext context) {
    final color = detected ? context.semantic.success : context.semantic.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .10),
        borderRadius: BorderRadius.circular(AppRadius.control),
      ),
      child: _GuideFact(
        text: text,
        icon: detected
            ? Icons.check_circle_outline_rounded
            : Icons.remove_circle_outline_rounded,
        color: color,
      ),
    );
  }
}

class _RequirementDiagram extends StatelessWidget {
  const _RequirementDiagram({required this.definition, required this.title});
  final FootballScenarioDefinition definition;
  final String title;
  @override
  Widget build(BuildContext context) => _GuidePanel(
    child: LayoutBuilder(
      builder: (context, constraints) {
        final vertical =
            constraints.maxWidth < 300 ||
            MediaQuery.textScalerOf(context).scale(14) > 18;
        final cards = [
          for (final requirement in definition.requirements)
            _RequirementCard(requirement: requirement),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (vertical) ...[
              for (final entry in cards.indexed) ...[
                entry.$2,
                if (entry.$1 < cards.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      '+',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: context.brand.accent),
                    ),
                  ),
              ],
            ] else ...[
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final entry in cards.indexed) ...[
                      Expanded(child: entry.$2),
                      if (entry.$1 < cards.length - 1) const SizedBox(width: 8),
                    ],
                  ],
                ),
              ),
              ExcludeSemantics(
                child: CustomPaint(
                  size: const Size(double.infinity, 30),
                  painter: _RequirementJoinPainter(
                    count: cards.length,
                    color: context.textColors.secondary,
                  ),
                ),
              ),
            ],
            Icon(
              Icons.arrow_downward_rounded,
              size: 22,
              color: context.brand.accent,
            ),
            const SizedBox(height: 8),
            Text(
              'Toutes requises',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: context.brand.accent,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        );
      },
    ),
  );
}

class _RequirementCard extends StatelessWidget {
  const _RequirementCard({required this.requirement});
  final ScenarioReadingRequirement requirement;
  @override
  Widget build(BuildContext context) {
    final identity = context.opportunities.readingIdentityForId(
      requirement.readingId,
    );
    final badge = identity.badgeFor(AppReadingBadgeVariant.soft);
    return Material(
      color: badge.background,
      borderRadius: BorderRadius.circular(AppRadius.control),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.control),
        onTap: () => openReadingGuide(context, requirement.readingId),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(identity.icon, color: badge.iconColor, size: 24),
              const SizedBox(height: 8),
              Text(
                LectorGuideCatalog.readingLabel(requirement.readingId),
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                LectorGuideCatalog.requirementSubjectLabel(requirement.subject),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: context.textColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RequirementJoinPainter extends CustomPainter {
  const _RequirementJoinPainter({required this.count, required this.color});
  final int count;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    if (count == 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    final first = size.width / (count * 2);
    final last = size.width - first;
    for (var i = 0; i < count; i++) {
      final x = size.width * (i + .5) / count;
      canvas.drawLine(Offset(x, 0), Offset(x, 12), paint);
    }
    canvas.drawLine(Offset(first, 12), Offset(last, 12), paint);
    canvas.drawLine(
      Offset(size.width / 2, 12),
      Offset(size.width / 2, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RequirementJoinPainter oldDelegate) =>
      oldDelegate.count != count || oldDelegate.color != color;
}
