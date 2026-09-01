import 'package:flutter/material.dart';

import '../../../core/theme/app_components.dart';
import '../domain/match_board_item.dart';

class OpportunityDecisionPresenter {
  const OpportunityDecisionPresenter._();

  static String opportunityTitleFromTheses(List<MatchThesis> theses) {
    if (theses.isEmpty) {
      return 'Lecture combinée détectée';
    }

    if (theses.length == 1) {
      return _normalizeThesisTitle(theses.first.title);
    }

    final titles = theses.map((thesis) => _normalizeThesisTitle(thesis.title));
    final hasFavorite = titles.any(
      (title) => title.toLowerCase().contains('favori'),
    );
    final hasOpen = titles.any(
      (title) => title.toLowerCase().contains('ouvert'),
    );
    final hasDefense = titles.any(
      (title) => title.toLowerCase().contains('défense'),
    );
    final hasGap = titles.any((title) => title.toLowerCase().contains('écart'));

    if (hasFavorite && hasGap) {
      return 'Favori solide confirmé';
    }
    if (hasOpen) {
      return 'Match très ouvert';
    }
    if (hasDefense) {
      return 'Fragilité défensive exploitable';
    }

    return '${_normalizeThesisTitle(theses.first.title)} + ${theses.length - 1} signal(s)';
  }

  static String readingFor({
    required String homeTeamName,
    required String awayTeamName,
    required List<MatchThesis> theses,
  }) {
    if (theses.isEmpty) {
      return 'Lector a détecté une situation à surveiller sur cette rencontre.';
    }

    final arguments = theses.expand((thesis) => thesis.arguments).take(3);
    if (arguments.isEmpty) {
      return theses.first.summary;
    }

    final sentences = [
      'Cette rencontre apparaît dans “Pour moi” car plusieurs signaux vont dans le même sens.',
      for (final argument in arguments)
        CopilotArgumentPresenter(argument).summary,
      _scenarioSentence(theses.first, homeTeamName, awayTeamName),
    ];

    return sentences.join(' ');
  }

  static String marketRationale({
    required RecommendedMarket recommendedMarket,
    required List<MatchThesis> theses,
  }) {
    final thesis = theses.isEmpty ? null : theses.first;
    final title = thesis == null
        ? 'la lecture détectée'
        : _normalizeThesisTitle(thesis.title).toLowerCase();
    return 'Ce marché est proposé parce qu’il traduit directement $title avec une cote disponible à ${recommendedMarket.selection.odds.toStringAsFixed(2)}.';
  }

  static IconData argumentIcon(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.hierarchy => Icons.emoji_events_outlined,
      CopilotArgumentFamily.performance => Icons.trending_down_rounded,
      CopilotArgumentFamily.defense => Icons.shield_outlined,
      CopilotArgumentFamily.attack => Icons.trending_up_rounded,
      CopilotArgumentFamily.form => Icons.show_chart_rounded,
      CopilotArgumentFamily.rhythm => Icons.speed_rounded,
      CopilotArgumentFamily.market => Icons.stacked_line_chart_rounded,
      CopilotArgumentFamily.contradiction => Icons.warning_amber_rounded,
    };
  }

  static Color argumentColor(BuildContext context, CopilotArgument argument) {
    final colorScheme = Theme.of(context).colorScheme;
    final semantic = context.semantic;
    return switch (argument.family) {
      CopilotArgumentFamily.contradiction => semantic.warning,
      CopilotArgumentFamily.performance => semantic.warning,
      CopilotArgumentFamily.defense => colorScheme.error,
      CopilotArgumentFamily.attack => semantic.info,
      CopilotArgumentFamily.market => colorScheme.onSurfaceVariant,
      _ => colorScheme.primary,
    };
  }

  static String _normalizeThesisTitle(String title) {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      return 'Lecture combinée détectée';
    }
    return trimmed;
  }

  static String _scenarioSentence(
    MatchThesis thesis,
    String homeTeamName,
    String awayTeamName,
  ) {
    final title = thesis.title.toLowerCase();
    if (title.contains('favori')) {
      return 'Le scénario le plus cohérent reste un match maîtrisé par le favori.';
    }
    if (title.contains('ouvert')) {
      return 'Le scénario le plus cohérent reste une rencontre avec des espaces et des occasions.';
    }
    if (title.contains('outsider')) {
      return 'Le scénario le plus cohérent reste une vigilance sur l’outsider.';
    }
    return 'Le scénario mérite une analyse complète avant $homeTeamName - $awayTeamName.';
  }
}

class CopilotArgumentPresenter {
  const CopilotArgumentPresenter(this.argument);

  final CopilotArgument argument;

  String get headline => FootballReadingCopyCatalog.titleFor(argument);

  String get summary => FootballReadingCopyCatalog.summaryFor(argument);

  String get actionLabel {
    return switch (argument.evidenceAction) {
      CopilotEvidenceAction.market => 'Voir le marché',
      CopilotEvidenceAction.standings => 'Voir le classement',
      CopilotEvidenceAction.results => 'Voir les résultats',
      CopilotEvidenceAction.defensiveStats => 'Voir les données défensives',
      CopilotEvidenceAction.offensiveStats => 'Voir les données offensives',
      CopilotEvidenceAction.form => 'Voir la forme',
      CopilotEvidenceAction.rhythm => 'Voir les moyennes de buts',
    };
  }
}

class FootballReadingCopyCatalog {
  const FootballReadingCopyCatalog._();

  static String readingIdFor(CopilotArgument argument) {
    final readingId = argument.parameters['readingId'];
    if (readingId is String && readingId.trim().isNotEmpty) {
      return readingId;
    }

    return switch (argument.type) {
      CopilotArgumentType.marketFavorite => 'market_favorite',
      CopilotArgumentType.rankingGap => 'ranking_gap',
      CopilotArgumentType.poorOverallPerformance => 'poor_overall_performance',
      CopilotArgumentType.fragileDefense => 'fragile_defense',
      CopilotArgumentType.strongAttack => 'strong_attack',
      CopilotArgumentType.strongRecentForm => 'strong_recent_form',
      CopilotArgumentType.weakRecentForm => 'weak_recent_form',
      CopilotArgumentType.openMatch => 'open_match_profile',
      CopilotArgumentType.closedMatch => 'closed_match_profile',
      CopilotArgumentType.contradiction => 'contradiction',
    };
  }

  static String titleFor(CopilotArgument argument) {
    final readingId = readingIdFor(argument);
    final title = _titlesByReadingId[readingId];
    if (title != null) {
      return title;
    }

    return switch (argument.type) {
      CopilotArgumentType.marketFavorite => 'Favori du marché',
      CopilotArgumentType.rankingGap => 'Écart de niveau',
      CopilotArgumentType.poorOverallPerformance => 'Résultats insuffisants',
      CopilotArgumentType.fragileDefense => 'Défense fragile',
      CopilotArgumentType.strongAttack => 'Attaque prolifique',
      CopilotArgumentType.strongRecentForm => 'Dynamique positive',
      CopilotArgumentType.weakRecentForm => 'Dynamique négative',
      CopilotArgumentType.openMatch => 'Match ouvert',
      CopilotArgumentType.closedMatch => 'Match fermé',
      CopilotArgumentType.contradiction => 'Point de vigilance',
    };
  }

  static String summaryFor(CopilotArgument argument) {
    final factual = factualLineFor(argument);
    if (factual != null) {
      return factual;
    }

    return switch (readingIdFor(argument)) {
      'market_favorite' => _marketFavoriteSummary(argument),
      'ranking_gap' ||
      'ranking_superiority' ||
      'structural_level_gap' => 'Écart visible dans le classement disponible.',
      'poor_overall_performance' =>
        'Résultats faibles sur l’échantillon disponible.',
      'fragile_defense' => 'Buts encaissés au-dessus du seuil moteur.',
      'solid_defense' => 'Buts encaissés sous le seuil moteur.',
      'prolific_attack' ||
      'strong_attack' => 'Buts marqués au-dessus du seuil moteur.',
      'scoring_difficulty' => 'Production offensive sous le seuil moteur.',
      'positive_streak' || 'strong_recent_form' => 'Série récente favorable.',
      'negative_streak' || 'weak_recent_form' => 'Série récente défavorable.',
      'improving_form' => 'Les derniers résultats progressent.',
      'declining_form' => 'Les derniers résultats se dégradent.',
      'open_match_profile' => 'Les moyennes combinées orientent vers des buts.',
      'closed_match_profile' =>
        'Les moyennes combinées orientent vers un rythme bas.',
      'frequent_over_25' => 'Tendance récente favorable au over 2,5 buts.',
      'frequent_under_25' => 'Tendance récente favorable au under 2,5 buts.',
      'frequent_btts' => 'Les deux équipes marquent régulièrement.',
      'high_xg_creation' => 'Création xG récente au-dessus du seuil moteur.',
      'low_xg_creation' => 'Création xG récente sous le seuil moteur.',
      'high_xg_conceded' => 'xG concédés récents au-dessus du seuil moteur.',
      'offensive_underperformance' =>
        'Écart défavorable entre buts marqués et xG.',
      'offensive_overperformance' =>
        'Écart favorable entre buts marqués et xG.',
      'defensive_underperformance' =>
        'Écart défavorable entre buts encaissés et xGA.',
      'defensive_overperformance' =>
        'Écart favorable entre buts encaissés et xGA.',
      'misleading_result' =>
        'Les résultats récents doivent être nuancés par les xG.',
      'conflicting_signals' =>
        'Un signal positif est affaibli par une donnée contraire.',
      'insufficient_data' =>
        'Donnée écartée pour préserver une lecture pré-match.',
      _ => _fallbackSummary(argument),
    };
  }

  static String? factualLineFor(CopilotArgument argument) {
    final value = argument.parameters['evidenceValue'];
    final sampleSize = argument.parameters['sampleSize'];
    final readingId = readingIdFor(argument);

    if (value is String && _isFormReading(readingId)) {
      return _formSummary(value, sampleSize);
    }

    if (value is Map) {
      final rankGap = value['rankGap'];
      final pointsGap = value['pointsGap'];
      if (rankGap is int && pointsGap is int) {
        return '$rankGap place${rankGap > 1 ? 's' : ''} d’écart · '
            '$pointsGap point${pointsGap > 1 ? 's' : ''} d’écart.';
      }
    }

    if (value is double) {
      return _numericSummary(readingId, value, sampleSize);
    }

    if (value is int && readingId == 'balanced_hierarchy') {
      return '$value place${value > 1 ? 's' : ''} d’écart au classement.';
    }

    return null;
  }

  static String evidenceLineFor(
    CopilotArgument argument,
    ThesisEvidence evidence,
  ) {
    return factualLineFor(argument) ?? evidence.label;
  }

  static bool hasStructuredEvidence(CopilotArgument argument) {
    return factualLineFor(argument) != null;
  }

  static const Map<String, String> _titlesByReadingId = {
    'balanced_hierarchy': 'Hiérarchie proche',
    'ranking_superiority': 'Avantage au classement',
    'structural_level_gap': 'Écart de niveau structurel',
    'positive_streak': 'Dynamique positive',
    'negative_streak': 'Dynamique négative',
    'improving_form': 'Dynamique en hausse',
    'declining_form': 'Dynamique en baisse',
    'strong_home_team': 'Solide à domicile',
    'weak_home_team': 'Fragile à domicile',
    'strong_away_team': 'Solide à l’extérieur',
    'weak_away_team': 'Fragile à l’extérieur',
    'home_away_mismatch': 'Avantage domicile / extérieur',
    'prolific_attack': 'Attaque prolifique',
    'attack_in_form': 'Attaque en forme',
    'scoring_difficulty': 'Production offensive faible',
    'solid_defense': 'Défense solide',
    'fragile_defense': 'Défense fragile',
    'declining_defense': 'Défense en baisse',
    'frequent_clean_sheet': 'Clean sheets fréquents',
    'open_match_profile': 'Match ouvert',
    'closed_match_profile': 'Match fermé',
    'frequent_btts': 'BTTS fréquent',
    'frequent_over_25': 'Tendance over 2,5 buts',
    'frequent_under_25': 'Tendance under 2,5 buts',
    'high_xg_creation': 'Création xG élevée',
    'low_xg_creation': 'Création xG faible',
    'high_xg_conceded': 'xG concédés élevés',
    'offensive_underperformance': 'Sous-performance offensive',
    'offensive_overperformance': 'Surperformance offensive',
    'defensive_underperformance': 'Sous-performance défensive',
    'defensive_overperformance': 'Surperformance défensive',
    'misleading_result': 'Résultats à nuancer',
    'conflicting_signals': 'Signal contradictoire',
    'insufficient_data': 'Donnée non exploitable',
  };

  static bool _isFormReading(String readingId) {
    return readingId == 'positive_streak' ||
        readingId == 'negative_streak' ||
        readingId == 'improving_form' ||
        readingId == 'declining_form' ||
        readingId == 'strong_recent_form' ||
        readingId == 'weak_recent_form';
  }

  static String _formSummary(Object value, Object? sampleSize) {
    final form = value.toString().toUpperCase().replaceAll(
      RegExp('[^WDL]'),
      '',
    );
    if (form.isEmpty) {
      return 'Série récente disponible.';
    }
    final wins = 'W'.allMatches(form).length;
    final draws = 'D'.allMatches(form).length;
    final losses = 'L'.allMatches(form).length;
    final size = sampleSize is int ? sampleSize : form.length;
    final parts = <String>[
      if (wins > 0) '$wins victoire${wins > 1 ? 's' : ''}',
      if (draws > 0) '$draws nul${draws > 1 ? 's' : ''}',
      if (losses > 0) '$losses défaite${losses > 1 ? 's' : ''}',
    ];
    final record = parts.isEmpty ? '' : ' · ${parts.join(' · ')}';
    return '$form sur les $size derniers matchs$record.';
  }

  static String _numericSummary(
    String readingId,
    double value,
    Object? sampleSize,
  ) {
    final sampleSuffix = sampleSize is int && sampleSize > 0
        ? ' · échantillon $sampleSize matchs'
        : '';
    final formatted = value.toStringAsFixed(2);
    return switch (readingId) {
      'strong_home_team' =>
        '${_percent(value)} de victoires à domicile$sampleSuffix.',
      'weak_home_team' =>
        '${_percent(value)} de défaites à domicile$sampleSuffix.',
      'strong_away_team' =>
        '${_percent(value)} de victoires à l’extérieur$sampleSuffix.',
      'weak_away_team' =>
        '${_percent(value)} de défaites à l’extérieur$sampleSuffix.',
      'prolific_attack' ||
      'attack_in_form' => '$formatted but(s) marqué(s) par match$sampleSuffix.',
      'scoring_difficulty' =>
        '$formatted but(s) marqué(s) par match$sampleSuffix.',
      'solid_defense' || 'fragile_defense' || 'declining_defense' =>
        '$formatted but(s) encaissé(s) par match$sampleSuffix.',
      'frequent_clean_sheet' =>
        '${_percent(value)} de clean sheets$sampleSuffix.',
      'open_match_profile' || 'closed_match_profile' =>
        'Indice buts combiné : $formatted$sampleSuffix.',
      'frequent_over_25' => 'Indice over 2,5 buts : $formatted$sampleSuffix.',
      'frequent_under_25' => 'Indice under 2,5 buts : $formatted$sampleSuffix.',
      'high_xg_creation' || 'low_xg_creation' =>
        '$formatted xG créés en moyenne récente$sampleSuffix.',
      'high_xg_conceded' =>
        '$formatted xG concédés en moyenne récente$sampleSuffix.',
      'offensive_underperformance' || 'offensive_overperformance' =>
        'Écart buts - xG : $formatted$sampleSuffix.',
      'defensive_underperformance' || 'defensive_overperformance' =>
        'Écart buts encaissés - xGA : $formatted$sampleSuffix.',
      _ => '$formatted$sampleSuffix.',
    };
  }

  static String _marketFavoriteSummary(CopilotArgument argument) {
    final odds = argument.parameters['odds'];
    if (odds is double) {
      return '${argument.subjectName} est l’issue la plus basse du 1N2 à ${odds.toStringAsFixed(2)}.';
    }

    return '${argument.subjectName} est l’issue la plus basse du 1N2.';
  }

  static String _fallbackSummary(CopilotArgument argument) {
    return switch (argument.family) {
      CopilotArgumentFamily.market => _marketFavoriteSummary(argument),
      CopilotArgumentFamily.hierarchy => 'Lecture issue du classement.',
      CopilotArgumentFamily.performance =>
        'Lecture issue des performances domicile / extérieur.',
      CopilotArgumentFamily.defense => 'Lecture issue des données défensives.',
      CopilotArgumentFamily.attack => 'Lecture issue des données offensives.',
      CopilotArgumentFamily.form => 'Lecture issue de la forme récente.',
      CopilotArgumentFamily.rhythm => 'Lecture issue des moyennes de buts.',
      CopilotArgumentFamily.contradiction =>
        'Signal à vérifier avant de confirmer la lecture combinée.',
    };
  }

  static String _percent(double value) {
    return '${(value * 100).round()}%';
  }
}
