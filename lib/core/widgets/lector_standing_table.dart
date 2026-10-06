import 'package:flutter/material.dart';
import '../theme/app_components.dart';
import '../theme/app_colors.dart';
import 'sports_asset_badge.dart';
import '../theme/app_radius.dart';
import 'lector_tier_band.dart';
import 'lector_glass_card.dart';
import 'lector_match_section_card.dart';

enum LectorStandingRole { none, home, away }

/// Match roles have one presentation contract, independent of the sport or
/// whether the table describes general, home or away results.
extension LectorStandingRolePresentation on LectorStandingRole {
  String? get label => switch (this) {
    LectorStandingRole.home => 'DOM.',
    LectorStandingRole.away => 'EXT.',
    LectorStandingRole.none => null,
  };
  Color? color(BuildContext context) => switch (this) {
    LectorStandingRole.home => context.brand.accent,
    LectorStandingRole.away => context.strategies.violetStyle.color,
    LectorStandingRole.none => null,
  };
}

class LectorStandingColumn {
  const LectorStandingColumn(this.label, this.width, {this.bold = false});
  final String label;
  final double width;
  final bool bold;
}

class LectorStandingValue {
  const LectorStandingValue(this.text, {this.color});
  final String text;
  final Color? color;
}

/// Sport adapters provide factual cells and annotations, never widget layout.
class LectorStandingEntry {
  const LectorStandingEntry({
    required this.identity,
    required this.name,
    required this.rank,
    required this.values,
    this.logoUrl,
    this.role = LectorStandingRole.none,
    this.rankColor,
    this.rankDescription,
    this.secondaryText,
  });
  final String identity, name, rank;
  final String? logoUrl, rankDescription, secondaryText;
  final LectorStandingRole role;
  final Color? rankColor;
  final List<LectorStandingValue> values;
}

class LectorStandingGroupData {
  const LectorStandingGroupData({required this.rows, this.label, this.color});
  final List<LectorStandingEntry> rows;
  final String? label;
  final Color? color;
}

/// The complete table renderer used by football and hockey. Column selection,
/// points rules, official rank and tier membership remain adapter data.
class LectorStandingDataTable extends StatelessWidget {
  const LectorStandingDataTable({
    required this.columns,
    required this.groups,
    this.tableKey,
    this.compact = false,
    this.cardStyle = false,
    super.key,
  });
  final List<LectorStandingColumn> columns;
  final List<LectorStandingGroupData> groups;
  final Key? tableKey;
  final bool compact;
  final bool cardStyle;

  @override
  Widget build(BuildContext context) {
    assert(
      groups.every(
        (group) =>
            group.rows.every((row) => row.values.length == columns.length),
      ),
    );
    final primary = context.textColors.primary;
    final secondary = context.textColors.secondary;
    final hasTiers = groups.any((g) => g.label != null);
    return LectorStandingTable(
      key: tableKey,
      framed: !cardStyle,
      header: LectorStandingRow(
        backgroundColor: AppColors.transparent,
        borderColor: context.surfaces.border,
        tierRailColor: null,
        highlightColor: null,
        child: Row(
          children: [
            if (hasTiers) const SizedBox(width: 24),
            LectorStandingCell(
              '#',
              width: compact ? 14 : 20,
              color: secondary,
              isHeader: true,
            ),
            Expanded(
              child: Text(
                'Équipe',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: secondary,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            for (final column in columns)
              LectorStandingCell(
                column.label,
                width: column.width,
                color: secondary,
                isHeader: true,
              ),
          ],
        ),
      ),
      groups: [
        for (final group in groups)
          LectorStandingTierGroup(
            label: group.label,
            color: group.color,
            rows: Column(
              children: [
                for (final row in group.rows)
                  LectorStandingRow(
                    key: ValueKey('standing-row-${row.identity}'),
                    backgroundColor: AppColors.transparent,
                    borderColor: context.surfaces.border,
                    tierRailColor: null,
                    highlightColor: row.role.color(context),
                    roundedHighlight: cardStyle && !compact,
                    flatHighlight: compact,
                    child: Row(
                      children: [
                        Semantics(
                          excludeSemantics: true,
                          label: [
                            'Position ${row.rank}',
                            if (row.rankDescription != null)
                              row.rankDescription!,
                          ].join(', '),
                          child: SizedBox(
                            width: compact ? 14 : 20,
                            child: Text(
                              row.rank,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(
                                    color: row.rankColor ?? primary,
                                    fontWeight: FontWeight.w900,
                                  ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: LectorStandingTeam(
                            name: row.name,
                            logoUrl: row.logoUrl,
                            textColor: primary,
                            role: row.role,
                            secondaryText: row.secondaryText,
                            compact: compact,
                          ),
                        ),
                        for (final (index, column) in columns.indexed)
                          LectorStandingCell(
                            row.values[index].text,
                            width: column.width,
                            color: row.values[index].color ?? primary,
                            bold: column.bold,
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class LectorStandingViewOption<T> {
  const LectorStandingViewOption({
    required this.value,
    required this.label,
    this.key,
    this.color,
    this.personalized = false,
  });
  final T value;
  final String label;
  final Key? key;
  final Color? color;
  final bool personalized;
}

/// Same card, heading, spacing and scope controls as the football reference.
class LectorStandingPanel<T> extends StatelessWidget {
  const LectorStandingPanel({
    required this.description,
    required this.views,
    required this.selectedView,
    required this.onSelected,
    required this.child,
    this.legend,
    this.groupSelector,
    this.footer,
    this.separateContent = false,
    this.segmentedViews = false,
    super.key,
  });
  final String description;
  final List<LectorStandingViewOption<T>> views;
  final T selectedView;
  final ValueChanged<T> onSelected;
  final Widget child;
  final bool separateContent;
  final bool segmentedViews;
  final Widget? legend, groupSelector, footer;
  @override
  Widget build(BuildContext context) {
    final controls = LectorGlassCard(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.bar_chart_rounded,
                color: context.brand.accent,
                size: 22,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'CLASSEMENT',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: context.textColors.secondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          if (views.isNotEmpty) ...[
            if (segmentedViews)
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<T>(
                  showSelectedIcon: false,
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? context.brand.accent.withValues(alpha: .2)
                          : null,
                    ),
                    foregroundColor: WidgetStateProperty.resolveWith(
                      (states) => states.contains(WidgetState.selected)
                          ? context.brand.accent
                          : context.textColors.secondary,
                    ),
                    side: WidgetStatePropertyAll(
                      BorderSide(color: context.surfaces.border),
                    ),
                  ),
                  segments: [
                    for (final view in views)
                      ButtonSegment<T>(
                        value: view.value,
                        label: Text(view.label, key: view.key),
                      ),
                  ],
                  selected: {selectedView},
                  onSelectionChanged: (values) => onSelected(values.single),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final view in views) ...[
                      LectorMatchScopeChip(
                        key: view.key,
                        label: view.label,
                        semanticsLabel: view.personalized
                            ? '${view.label}, suggéré par vos préférences'
                            : view.label,
                        selected: view.value == selectedView,
                        color: view.color ?? context.brand.accent,
                        personalized: view.personalized,
                        onPressed: () => onSelected(view.value),
                      ),
                      if (view != views.last) const SizedBox(width: 7),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 10),
          ],
          if (groupSelector != null) ...[
            groupSelector!,
            const SizedBox(height: 10),
          ],
          if (legend != null) ...[legend!, const SizedBox(height: 10)],
          if (!separateContent) ...[
            child,
            if (footer != null) ...[const SizedBox(height: 8), footer!],
          ],
        ],
      ),
    );
    return separateContent
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              controls,
              const SizedBox(height: 12),
              child,
              if (footer != null) ...[const SizedBox(height: 8), footer!],
            ],
          )
        : controls;
  }
}

class LectorStandingLegendEntry {
  const LectorStandingLegendEntry({
    required this.label,
    required this.color,
    this.rankLabel,
  });
  final String label;
  final Color color;
  final String? rankLabel;
}

class LectorStandingLegend extends StatelessWidget {
  const LectorStandingLegend({
    required this.officialZones,
    required this.tiers,
    this.tiersAreProvisional = false,
    this.tierExplanation,
    super.key,
  });
  final List<LectorStandingLegendEntry> officialZones, tiers;
  final bool tiersAreProvisional;
  final String? tierExplanation;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.surfaceHover.withValues(alpha: .34),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lecture du classement',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: context.textColors.primary,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 9),
          _LectorStandingLegendSection(
            icon: Icons.emoji_events_outlined,
            title: 'Enjeux officiels',
            emptyLabel: 'Aucune zone officielle disponible.',
            entries: officialZones,
          ),
          const SizedBox(height: 9),
          Divider(height: 1, color: context.surfaces.border),
          const SizedBox(height: 9),
          _LectorStandingLegendSection(
            icon: Icons.bar_chart_rounded,
            title: tiersAreProvisional
                ? 'Tiers Lector · provisoires'
                : 'Tiers Lector',
            emptyLabel: 'Tiers non calculables pour ce classement.',
            entries: tiers,
          ),
          if (tiers.isNotEmpty || officialZones.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              'Numéro coloré : enjeu officiel · bande T1–T5 : Tier Lector',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.secondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (tierExplanation != null || tiersAreProvisional) ...[
            const SizedBox(height: 7),
            Text(
              tierExplanation ??
                  'Échantillon encore court : les tiers sont affichés, mais restent exclus des décisions automatiques.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.semantic.warning,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LectorStandingLegendSection extends StatelessWidget {
  const _LectorStandingLegendSection({
    required this.icon,
    required this.title,
    required this.emptyLabel,
    required this.entries,
  });
  final IconData icon;
  final String title, emptyLabel;
  final List<LectorStandingLegendEntry> entries;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          Icon(icon, size: 17, color: context.brand.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: context.textColors.primary,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 7),
      if (entries.isEmpty)
        Text(
          emptyLabel,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: context.textColors.secondary,
            fontWeight: FontWeight.w700,
          ),
        )
      else
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            for (final entry in entries)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (entry.rankLabel != null)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.tight),
                        border: Border.all(color: entry.color),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          entry.rankLabel!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: entry.color,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 28,
                      height: 4,
                      decoration: BoxDecoration(
                        color: entry.color,
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                      ),
                    ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 154),
                    child: Text(
                      entry.label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
    ],
  );
}

Color lectorStandingTierColor(BuildContext context, int ordinal) =>
    Color.lerp(
      context.brand.accent,
      context.strategies.violetStyle.color,
      ((ordinal - 1) / 4).clamp(0, 1),
    ) ??
    context.brand.accent;

/// Shared table structure; adapters supply columns appropriate to their sport.
class LectorStandingTable extends StatelessWidget {
  const LectorStandingTable({
    required this.header,
    required this.groups,
    this.framed = true,
    super.key,
  });
  final Widget header;
  final List<Widget> groups;
  final bool framed;
  @override
  Widget build(BuildContext context) => !framed
      ? Column(children: [header, ...groups])
      : ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.control),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.surfaces.surfaceHover.withValues(alpha: .22),
              border: Border.all(color: context.surfaces.border),
              borderRadius: BorderRadius.circular(AppRadius.control),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) => SizedBox(
                width: constraints.maxWidth,
                child: Column(children: [header, ...groups]),
              ),
            ),
          ),
        );
}

class LectorStandingTierGroup extends StatelessWidget {
  const LectorStandingTierGroup({
    required this.rows,
    this.color,
    this.label,
    super.key,
  });
  final Widget rows;
  final Color? color;
  final String? label;
  @override
  Widget build(BuildContext context) => label == null
      ? rows
      : Stack(
          children: [
            Padding(padding: const EdgeInsets.only(left: 24), child: rows),
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 24,
              child: LectorTierBand(color: color, label: label),
            ),
          ],
        );
}

class LectorStandingRow extends StatelessWidget {
  const LectorStandingRow({
    required this.child,
    required this.backgroundColor,
    required this.borderColor,
    required this.tierRailColor,
    required this.highlightColor,
    this.isTierBoundary = false,
    this.roundedHighlight = false,
    this.flatHighlight = false,
    super.key,
  });

  final Widget child;
  final Color backgroundColor;
  final Color borderColor;
  final Color? tierRailColor;
  final Color? highlightColor;
  final bool isTierBoundary;
  final bool roundedHighlight;
  final bool flatHighlight;

  @override
  Widget build(BuildContext context) {
    final highlight = highlightColor;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlight == null
            ? backgroundColor
            : highlight.withValues(alpha: flatHighlight ? .12 : .055),
        borderRadius: highlight != null && roundedHighlight
            ? BorderRadius.circular(AppRadius.tight)
            : null,
        border: flatHighlight
            ? Border(
                left: highlight == null
                    ? BorderSide.none
                    : BorderSide(color: highlight, width: 2),
                bottom: BorderSide(color: borderColor.withValues(alpha: .7)),
              )
            : highlight != null && roundedHighlight
            ? Border.all(color: highlight, width: 1.5)
            : Border(
                left: highlight != null
                    ? BorderSide(color: highlight, width: 2)
                    : tierRailColor == null
                    ? BorderSide.none
                    : BorderSide(color: tierRailColor!, width: 3),
                top: highlight != null
                    ? BorderSide(color: highlight, width: 2)
                    : isTierBoundary
                    ? BorderSide(color: tierRailColor ?? borderColor, width: 2)
                    : BorderSide.none,
                right: highlight == null
                    ? BorderSide.none
                    : BorderSide(color: highlight, width: 2),
                bottom: highlight != null
                    ? BorderSide(color: highlight, width: 2)
                    : BorderSide(color: borderColor.withValues(alpha: 0.7)),
              ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 5),
        child: child,
      ),
    );
  }
}

class LectorStandingCell extends StatelessWidget {
  const LectorStandingCell(
    this.value, {
    required this.width,
    required this.color,
    this.isHeader = false,
    this.bold = false,
    this.alignment = Alignment.center,
    super.key,
  });

  final String value;
  final double width;
  final Color color;
  final bool isHeader;
  final bool bold;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: width,
      child: Align(
        alignment: alignment,
        child: Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: isHeader || bold ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class LectorStandingSidePill extends StatelessWidget {
  const LectorStandingSidePill({
    required this.label,
    required this.color,
    super.key,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontSize: 9,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class LectorStandingTeam extends StatelessWidget {
  const LectorStandingTeam({
    required this.name,
    this.logoUrl,
    this.secondaryText,
    required this.textColor,
    this.role = LectorStandingRole.none,
    this.compact = false,
    this.secondaryMaxLines,
    super.key,
  });
  final String name;
  final String? logoUrl, secondaryText;
  final Color textColor;
  final LectorStandingRole role;
  final bool compact;
  final int? secondaryMaxLines;
  String? get sideLabel => role.label;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final stackedRole =
          !compact && sideLabel != null && constraints.maxWidth < 105;
      final badge = compact || sideLabel == null
          ? null
          : LectorStandingSidePill(
              label: sideLabel!,
              color: role.color(context)!,
            );
      final identityRow = Row(
        children: [
          SportsAssetBadge(
            size: compact ? 16 : 18,
            imageUrl: logoUrl,
            fallbackLabel: name,
            backgroundColor: AppColors.transparent,
            padding: 1,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Tooltip(
              message: name,
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: textColor,
                  fontSize: compact ? 11 : null,
                  fontWeight: sideLabel == null
                      ? FontWeight.w700
                      : FontWeight.w900,
                ),
              ),
            ),
          ),
          if (!stackedRole && badge != null) badge,
        ],
      );
      final Widget identity = secondaryText == null
          ? identityRow
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identityRow,
                if (secondaryText != null)
                  Padding(
                    padding: EdgeInsets.only(left: compact ? 0 : 23, top: 2),
                    child: Text(
                      secondaryText!,
                      maxLines: secondaryMaxLines ?? (compact ? 4 : 1),
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: context.textColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  ),
              ],
            );
      final result = stackedRole
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [identity, const SizedBox(height: 2), badge!],
            )
          : identity;
      return compact
          ? ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 20),
              child: Semantics(
                label: sideLabel == null ? null : '$name, $sideLabel',
                child: result,
              ),
            )
          : result;
    },
  );
}
