import '../theme/app_colors.dart';
import 'package:flutter/material.dart';
import '../theme/app_components.dart';

/// Keeps published player signals and live explanations accessible without
/// expanding every feed card. Confirmed contributions remain visible closed.
class LectorMatchSupplement extends StatelessWidget {
  const LectorMatchSupplement({
    required this.identity,
    required this.children,
    this.decisiveCount = 0,
    this.isLive = false,
    this.label = 'Lectures et signaux',
    super.key,
  });
  final String identity, label;
  final List<Widget> children;
  final int decisiveCount;
  final bool isLive;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
    child: ExpansionTile(
      key: ValueKey('match-supplement:$identity'),
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(top: 8),
      minTileHeight: 32,
      dense: true,
      visualDensity: VisualDensity.compact,
      backgroundColor: AppColors.transparent,
      collapsedBackgroundColor: decisiveCount > 0
          ? (isLive
                ? context.features.radarConfirmedLiveFill
                : context.features.radarConfirmedFinalFill)
          : AppColors.transparent,
      shape: const Border(),
      collapsedShape: const Border(),
      title: Text(
        decisiveCount > 0
            ? '$decisiveCount joueur${decisiveCount > 1 ? 's' : ''} signalé${decisiveCount > 1 ? 's' : ''} décisif${decisiveCount > 1 ? 's' : ''}'
            : label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: decisiveCount > 0
              ? context.semantic.success
              : context.textColors.secondary,
        ),
      ),
      children: children,
    ),
  );
}
