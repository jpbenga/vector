import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_components.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import 'sports_asset_badge.dart';

/// Shared football layout: contextual keys grouped by participant. The sport
/// adapter owns the evidence and the meaning of every fact.
class LectorMatchContextView extends StatelessWidget {
  const LectorMatchContextView({
    required this.count,
    required this.child,
    this.takeaway,
    super.key,
  });
  final int count;
  final Widget child;
  final String? takeaway;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context),
        metaAccent = context.opportunities.levelGap;
    final textColors = context.textColors;
    final quickFactCount = count;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 4, 2, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: metaAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.control),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: metaAccent,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Clés du match',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: textColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Icon(
                          Icons.info_outline_rounded,
                          size: 17,
                          color: textColors.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Ce qui caractérise cette rencontre avant le coup d’envoi.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: textColors.secondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (quickFactCount > 0) ...[
                const SizedBox(width: 8),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: metaAccent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    border: Border.all(
                      color: metaAccent.withValues(alpha: .24),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    child: Text(
                      quickFactCount == 1 ? '1 clé' : '$quickFactCount clés',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: metaAccent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          child,
          if (takeaway != null) ...[
            const SizedBox(height: 16),
            LectorContextTakeawayCard(text: takeaway!),
          ],
        ],
      ),
    );
  }
}

class LectorEvidenceTeamCard extends StatelessWidget {
  const LectorEvidenceTeamCard({
    required this.title,
    required this.children,
    this.logoUrl,
    this.logoKey,
    this.analysis = false,
    this.participantIcon,
    super.key,
  });
  final IconData? participantIcon;
  final String title;
  final String? logoUrl;
  final Key? logoKey;
  final List<Widget> children;
  final bool analysis;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: analysis
          ? context.surfaces.surfaceHover.withValues(alpha: .46)
          : context.surfaces.surface.withValues(alpha: .72),
      borderRadius: BorderRadius.circular(
        analysis ? AppRadius.input : AppRadius.control,
      ),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Padding(
      padding: const EdgeInsets.all(11),
      child: analysis
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (participantIcon != null)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: context.brand.accent.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(AppRadius.chip),
                    ),
                    child: SizedBox.square(
                      dimension: 42,
                      child: Icon(
                        participantIcon,
                        color: context.brand.accent,
                        size: 21,
                      ),
                    ),
                  )
                else
                  SportsAssetBadge(
                    key: logoKey,
                    size: 46,
                    imageUrl: logoUrl,
                    fallbackLabel: title,
                    borderRadius: 23,
                    backgroundColor: AppColors.transparent,
                    contrastPlate: true,
                  ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _title(context),
                      const SizedBox(height: 6),
                      ...children,
                    ],
                  ),
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    SportsAssetBadge(
                      key: logoKey,
                      size: 31,
                      imageUrl: logoUrl,
                      fallbackLabel: title,
                      borderRadius: 16,
                      backgroundColor: AppColors.transparent,
                      contrastPlate: true,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: _title(context)),
                  ],
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
    ),
  );
  Widget _title(BuildContext context) => Text(
    title,
    style: Theme.of(context).textTheme.titleSmall?.copyWith(
      color: context.textColors.primary,
      fontWeight: FontWeight.w900,
    ),
  );
}

class LectorEvidenceRow extends StatelessWidget {
  const LectorEvidenceRow({
    required this.title,
    required this.icon,
    required this.color,
    required this.evidence,
    this.analysis = false,
    this.leading,
    super.key,
  });
  final String title;
  final IconData icon;
  final Color color;
  final Widget? evidence;
  final bool analysis;
  final Widget? leading;
  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style:
          (analysis
                  ? Theme.of(context).textTheme.bodySmall
                  : Theme.of(context).textTheme.bodyMedium)
              ?.copyWith(color: color, fontWeight: FontWeight.w900),
    );
    if (analysis) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              leading ?? Icon(icon, color: color, size: 17),
              const SizedBox(width: 7),
              Expanded(child: titleWidget),
            ],
          ),
          if (evidence != null) ...[const SizedBox(height: 3), evidence!],
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              titleWidget,
              if (evidence != null) ...[const SizedBox(height: 3), evidence!],
            ],
          ),
        ),
      ],
    );
  }
}

class LectorAnalysisSheet extends StatelessWidget {
  const LectorAnalysisSheet({required this.children, super.key});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.surfaces.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      border: Border.all(color: context.surfaces.border),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: AppSpacing.xs),
        Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: context.textColors.secondary.withValues(alpha: .72),
            borderRadius: BorderRadius.circular(AppRadius.chip),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
          child: LectorAnalysisOverviewHeader(
            onClose: () => Navigator.of(context).pop(),
          ),
        ),
        Flexible(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
            children: children,
          ),
        ),
      ],
    ),
  );
}

class LectorContextTakeawayCard extends StatelessWidget {
  const LectorContextTakeawayCard({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.brand.accent.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(AppRadius.control),
      border: Border.all(color: context.brand.accent.withValues(alpha: .22)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded, color: context.brand.accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'À retenir',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.textColors.primary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  text,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: context.textColors.secondary,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class LectorAnalysisOverviewHeader extends StatelessWidget {
  const LectorAnalysisOverviewHeader({required this.onClose, super.key});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: context.brand.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppRadius.odds),
            border: Border.all(
              color: context.brand.accent.withValues(alpha: 0.42),
            ),
          ),
          child: SizedBox.square(
            dimension: 42,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: context.brand.accent,
              size: 23,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ANALYSE LECTOR',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: context.brand.accent,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Pourquoi ce match est proposé',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: context.textColors.primary,
                  fontWeight: FontWeight.w900,
                  height: 1.12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Fermer',
          onPressed: onClose,
          icon: Icon(
            Icons.close_rounded,
            color: context.textColors.primary,
            size: 24,
          ),
        ),
      ],
    );
  }
}
