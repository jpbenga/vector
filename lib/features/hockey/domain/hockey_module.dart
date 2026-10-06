import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';
import '../../../core/sports/domain/sport_policy.dart';

abstract final class HockeyModule {
  static const definition = SportModuleDefinition(
    sport: SportId.hockey,
    stage: SportModuleStage.preparation,
    participantOrder: SportParticipantOrder.awayHome,
    provider: SportProviderPolicy(
      provider: 'api-hockey',
      quotaKey: 'api-hockey',
      dailyLimit: 7500,
      minuteLimit: 280,
    ),
    capabilities: {
      SportCapability.fixtures,
      SportCapability.standings,
      SportCapability.recentForm,
      SportCapability.teamRadar,
      SportCapability.playerRadar,
      SportCapability.readings,
    },
    readings: [
      SportReadingDefinition(
        id: 'standing_advantage',
        label: 'Avantage au classement',
        description:
            'Une équipe appartient à un tiers Lector supérieur à celui de son adversaire dans un classement comparable.',
        condition:
            'Au moins 5 matchs par équipe. Même compétition, saison et groupe de comparaison, avec au plus un match joué d’écart. Tiers différents, points et rendement supérieurs ; aucun seuil fixe de points ou de pourcentage.',
        example:
            'Dans un groupe de 12 équipes après 10 matchs, les points vont de 18 à 7 par pas de 1. Le premier est T1, le dernier T5 : l’avantage est détecté malgré l’absence de rupture exceptionnelle. Deux équipes T1 ne déclenchent pas cette lecture.',
      ),
      SportReadingDefinition(
        id: 'structural_level_gap',
        label: 'Écart de niveau structurel',
        description:
            'Une séparation de niveau est confirmée entre les adversaires dans leur classement commun.',
        condition:
            'Au moins cinq matchs et des tiers distincts : une frontière forte ou plusieurs frontières confirmées par le moteur de tiers. Les rangs de divisions différentes ne sont jamais comparés directement.',
        example:
            'Un groupe de tête se détache nettement du reste du classement ; son équipe affronte un groupe inférieur séparé par une frontière forte.',
      ),
      SportReadingDefinition(
        id: 'positive_streak',
        label: 'Dynamique positive',
        description:
            'Une équipe récolte régulièrement des points sur les cinq derniers matchs.',
        condition:
            'Des points à chacun des cinq matchs ; au moins 6/10 dans un barème à deux points, 9/15 dans un barème à trois points. Une défaite en prolongation peut rapporter un point.',
        example:
            'Quatre victoires NHL et une défaite en prolongation : 9/10 points. La dynamique est positive, sans être une série de cinq victoires.',
      ),
      SportReadingDefinition(
        id: 'negative_streak',
        label: 'Dynamique négative',
        description:
            'Une équipe récolte très peu de points sur ses cinq derniers matchs.',
        condition:
            'Au plus 2/10 dans un barème à deux points, 4/15 dans un barème à trois points.',
        example:
            'Une victoire et quatre défaites sans point en NHL : 2/10, dynamique négative.',
      ),
      SportReadingDefinition(
        id: 'improving_form',
        label: 'Forme en hausse',
        description:
            'Les deux derniers résultats sont meilleurs que les trois précédents.',
        condition:
            'Cinq matchs ; moyenne des deux derniers moins moyenne des trois précédents : au moins 0,67 point par match avec un barème à deux points, 1 avec trois points.',
        example:
            'Trois défaites à zéro point puis deux victoires NHL : la moyenne passe de 0 à 2 points par match.',
      ),
      SportReadingDefinition(
        id: 'form_gap',
        label: 'Écart de forme',
        description:
            'Une différence marquée entre les résultats récents des deux équipes.',
        condition:
            'Cinq matchs complets par équipe et au moins neuf points supplémentaires, selon le barème réel de la compétition.',
        example:
            'Une équipe NHL prend 10/10 points, son adversaire 1/10 : neuf points d’écart. En Magnus, 13/15 contre 4/15 remplit aussi la condition.',
      ),
      SportReadingDefinition(
        id: 'strong_home_team',
        label: 'Solide à domicile',
        description: 'Une équipe enchaîne les victoires à domicile.',
        condition:
            'Au moins trois victoires finales consécutives à domicile, prolongation et tirs au but inclus. Les matchs sur l’autre lieu ne changent pas cette série.',
        example:
            'Trois victoires à domicile séparées par des matchs sur l’autre lieu déclenchent la lecture ; deux ne suffisent pas.',
      ),
      SportReadingDefinition(
        id: 'weak_home_team',
        label: 'Fragile à domicile',
        description: 'Une équipe enchaîne les défaites à domicile.',
        condition:
            'Au moins trois défaites finales consécutives à domicile, prolongation et tirs au but inclus. Les matchs sur l’autre lieu ne changent pas cette série.',
        example:
            'Trois défaites à domicile séparées par des matchs sur l’autre lieu déclenchent la lecture ; deux ne suffisent pas.',
      ),
      SportReadingDefinition(
        id: 'strong_away_team',
        label: 'Solide à l’extérieur',
        description: 'Une équipe enchaîne les victoires à l’extérieur.',
        condition:
            'Au moins trois victoires finales consécutives à l’extérieur, prolongation et tirs au but inclus. Les matchs sur l’autre lieu ne changent pas cette série.',
        example:
            'Trois victoires à l’extérieur séparées par des matchs sur l’autre lieu déclenchent la lecture ; deux ne suffisent pas.',
      ),
      SportReadingDefinition(
        id: 'weak_away_team',
        label: 'Fragile à l’extérieur',
        description: 'Une équipe enchaîne les défaites à l’extérieur.',
        condition:
            'Au moins trois défaites finales consécutives à l’extérieur, prolongation et tirs au but inclus. Les matchs sur l’autre lieu ne changent pas cette série.',
        example:
            'Trois défaites à l’extérieur séparées par des matchs sur l’autre lieu déclenchent la lecture ; deux ne suffisent pas.',
      ),
      SportReadingDefinition(
        id: 'home_away_advantage',
        label: 'Avantage domicile / extérieur',
        description:
            'Une série de victoires à domicile rencontre une série de défaites à l’extérieur.',
        condition:
            'Au moins trois victoires consécutives à domicile pour cette équipe ET trois défaites consécutives à l’extérieur pour son adversaire.',
        example:
            'Quatre victoires à domicile contre trois défaites à l’extérieur : avantage détecté. Une seule des deux séries ne suffit pas.',
      ),
      SportReadingDefinition(
        id: 'away_home_advantage',
        label: 'Avantage extérieur / domicile',
        description:
            'Une série de victoires à l’extérieur rencontre une série de défaites à domicile.',
        condition:
            'Au moins trois victoires consécutives à l’extérieur pour cette équipe ET trois défaites consécutives à domicile pour son adversaire.',
        example:
            'Quatre victoires à l’extérieur contre trois défaites à domicile : avantage détecté. Une seule des deux séries ne suffit pas.',
      ),
      SportReadingDefinition(
        id: 'recent_form_advantage',
        label: 'Avantage de forme',
        description:
            'Les résultats récents opposent deux dynamiques différentes.',
        condition:
            'Les 5 derniers matchs terminés de chaque équipe, avant '
            'la rencontre. Au moins 2 points d’écart pour un barème à deux points, 3 pour un barème à trois points.',
        example:
            'En NHL, 4 victoires et 1 défaite en prolongation donnent '
            '9 points sur 10. Deux victoires et trois défaites à 60 minutes '
            'donnent 4 points sur 10 : cinq points d’écart.',
      ),
      SportReadingDefinition(
        id: 'winning_streak',
        label: 'Série de victoires',
        description: 'Une équipe enchaîne les victoires avant la rencontre.',
        condition:
            'Au moins 3 victoires consécutives, '
            'prolongation et tirs au but inclus. Comptage au-delà de cinq sur tout l’historique connu ; aucun risque de rupture déduit de la longueur.',
        example:
            'Une victoire à 60 minutes, une en prolongation puis une '
            'aux tirs au but constituent trois victoires consécutives.',
      ),
      SportReadingDefinition(
        id: 'head_to_head_dominance',
        label: 'Domination en tête-à-tête',
        description:
            'Une équipe a gagné les trois dernières confrontations comparables contre cet adversaire.',
        condition:
            'Trois victoires finales dans les trois dernières rencontres sur les trois années précédentes. Amicaux et préparation exclus. Championnat et coupes / phases finales calculés séparément ; type inconnu exclu du calcul.',
        example:
            'Trois victoires en championnat, dont une en prolongation : domination détectée en championnat. Une victoire en amical ne remplace pas une confrontation manquante.',
      ),
      SportReadingDefinition(
        id: 'goalie_advantage',
        label: 'Avantage au poste de gardien',
        description: 'Comparer les gardiens attendus et leurs performances.',
        condition: 'À définir après vérification des données disponibles.',
        example:
            'Il faut connaître le gardien attendu et un échantillon '
            'comparable ; un nom manquant ne constitue pas un avantage.',
        implemented: false,
      ),
      SportReadingDefinition(
        id: 'special_teams_advantage',
        label: 'Supériorité et infériorité numériques',
        description: 'Comparer le power play et la résistance en infériorité.',
        condition: 'À définir avec les données de situations spéciales.',
        example:
            'Comparer une attaque en supériorité numérique avec '
            'la défense adverse en infériorité sur une période commune.',
        implemented: false,
      ),
      SportReadingDefinition(
        id: 'schedule_load',
        label: 'Repos et enchaînement des matchs',
        description:
            'Repérer une différence de récupération entre les équipes.',
        condition: 'À définir avec le calendrier et les horaires exacts.',
        example:
            'Une équipe rejoue le lendemain alors que son adversaire '
            'dispose de deux jours de repos : contexte à mesurer.',
        implemented: false,
      ),
    ],
    scenarios: [
      SportScenarioDefinition(
        id: 'converging_advantages',
        label: 'Avantages convergents',
        description:
            'La même équipe présente un avantage au classement '
            'et un avantage de forme. Les deux lectures sont requises.',
        requiredReadingIds: ['standing_advantage', 'recent_form_advantage'],
      ),
    ],
  );
}
