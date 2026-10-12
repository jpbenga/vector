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
  Color get background => light
      ? context.surfaces.surface
      : switch (identity) {
          CompetitionCardIdentity.generic => AppCompetitionColors.surface,
          CompetitionCardIdentity.champions =>
            AppCompetitionColors.championsFill,
          CompetitionCardIdentity.europa => AppCompetitionColors.europaFill,
          CompetitionCardIdentity.conference =>
            AppCompetitionColors.conferenceFill,
        };
  Color get accent => light
      ? context.semantic.info
      : switch (identity) {
          CompetitionCardIdentity.generic => context.semantic.info,
          CompetitionCardIdentity.champions => AppCompetitionColors.champions,
          CompetitionCardIdentity.europa => AppCompetitionColors.europa,
          CompetitionCardIdentity.conference => AppCompetitionColors.conference,
        };
  Color get border => identity == CompetitionCardIdentity.generic
      ? (light ? context.surfaces.border : AppCompetitionColors.border)
      : accent.withValues(alpha: .42);
}
