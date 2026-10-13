import 'package:flutter/material.dart';
import '../theme/competition_card_theme.dart';

/// Competition artwork follows the selected surface and its contrast envelope.
class CompetitionCardBackground extends StatelessWidget {
  const CompetitionCardBackground({
    required this.palette,
    this.logoUrl,
    super.key,
  });
  final CompetitionCardTheme palette;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Stack(
      children: [
        if (palette.identity.backgroundAsset != null)
          Positioned.fill(
            child: Opacity(
              opacity: palette.illustrationOpacity,
              child: Image.asset(
                palette.identity.backgroundAsset!,
                fit: BoxFit.cover,
                alignment: Alignment.centerRight,
                excludeFromSemantics: true,
              ),
            ),
          )
        else if (logoUrl?.isNotEmpty == true)
          Positioned(
            right: -18,
            top: 28,
            bottom: 12,
            width: 150,
            child: Opacity(
              opacity: palette.watermarkOpacity,
              child: Image.network(
                logoUrl!,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  palette.background,
                  palette.background.withValues(alpha: .94),
                  palette.background.withValues(alpha: palette.scrimEndOpacity),
                ],
                stops: const [0, .47, 1],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
