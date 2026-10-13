import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_components.dart';

enum CompetitionCardIdentity { generic, champions, europa, conference }

extension CompetitionCardIdentityAsset on CompetitionCardIdentity {
  String? get backgroundAsset => switch (this) {
    CompetitionCardIdentity.generic => null,
    CompetitionCardIdentity.champions =>
      'assets/backgrounds/competition-champions-original-v1.png',
    CompetitionCardIdentity.europa =>
      'assets/backgrounds/competition-europa-original-v1.png',
    CompetitionCardIdentity.conference =>
      'assets/backgrounds/competition-conference-original-v1.png',
  };
}

class CompetitionCardTheme {
  const CompetitionCardTheme(this.context, this.identity);
  final BuildContext context;
  final CompetitionCardIdentity identity;
  bool get light => Theme.of(context).brightness == Brightness.light;
  // Competition identity tints the chosen theme; it never replaces its surface.
  Color get identityAccent => switch (identity) {
    CompetitionCardIdentity.generic => context.semantic.info,
    CompetitionCardIdentity.champions => AppCompetitionColors.champions,
    CompetitionCardIdentity.europa => AppCompetitionColors.europa,
    CompetitionCardIdentity.conference => AppCompetitionColors.conference,
  };
  Color get background => identity == CompetitionCardIdentity.generic
      ? context.surfaces.surface
      : Color.alphaBlend(
          identityAccent.withValues(alpha: light ? .05 : .10),
          context.surfaces.surface,
        );
  Color get accent => _legible(identityAccent, [background]);
  Color get title => context.textColors.primary;
  Color get secondaryText => _legible(context.textColors.secondary, [
    background,
    illustrationExtreme(Colors.white),
    illustrationExtreme(Colors.black),
  ]);
  Color get statusText =>
      _legible(context.features.generatorAccent, [background]);
  Color get statusBorder => statusText.withValues(alpha: .26);
  Color get border => identity == CompetitionCardIdentity.generic
      ? context.surfaces.border
      : Color.alphaBlend(
          accent.withValues(alpha: .40),
          context.surfaces.border,
        );

  // The image is an underlay. A themed scrim keeps the darkest and brightest
  // image pixels below the contrast limit, including warm and light themes.
  double get illustrationOpacity => light ? .18 : .72;
  double get watermarkOpacity => light ? .16 : .36;
  double get scrimEndOpacity {
    final start = light ? .74 : .68;
    for (var step = 0; step <= 20; step++) {
      final alpha = start + (1 - start) * step / 20;
      final extremes = [Colors.white, Colors.black].map(
        (pixel) => Color.alphaBlend(
          background.withValues(alpha: alpha),
          Color.alphaBlend(
            pixel.withValues(alpha: illustrationOpacity),
            background,
          ),
        ),
      );
      if (extremes.every((color) => _contrast(title, color) >= 4.8)) {
        return alpha;
      }
    }
    return 1;
  }

  Color illustrationExtreme(Color pixel) => Color.alphaBlend(
    background.withValues(alpha: scrimEndOpacity),
    Color.alphaBlend(pixel.withValues(alpha: illustrationOpacity), background),
  );

  ThemeData get contentTheme {
    final theme = Theme.of(context);
    return theme.copyWith(
      textTheme: theme.textTheme.apply(bodyColor: title, displayColor: title),
      extensions: [
        for (final extension in theme.extensions.values)
          if (extension is AppTextPalette)
            extension.copyWith(primary: title, secondary: secondaryText)
          else
            extension,
      ],
    );
  }

  Color _legible(Color color, List<Color> backgrounds) {
    for (var step = 0; step <= 20; step++) {
      final candidate = Color.lerp(color, title, step / 20)!;
      if (backgrounds.every((b) => _contrast(candidate, b) >= 4.5)) {
        return candidate;
      }
    }
    return title;
  }

  static double _contrast(Color a, Color b) {
    final x = a.computeLuminance(), y = b.computeLuminance();
    return ((x > y ? x : y) + .05) / ((x > y ? y : x) + .05);
  }
}
