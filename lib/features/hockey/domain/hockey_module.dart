import '../../../core/sports/domain/sport.dart';
import '../../../core/sports/domain/sport_module.dart';

abstract final class HockeyModule {
  static const definition = SportModuleDefinition(
    sport: SportId.hockey,
    stage: SportModuleStage.preparation,
    capabilities: {SportCapability.readings, SportCapability.scenarios},
    readings: [
      SportReadingDefinition(
        id: 'standing_advantage',
        label: 'Avantage au classement',
        description:
            'Une équipe obtient une part nettement supérieure des '
            'points disponibles dans un classement comparable.',
        condition:
            'Au moins 10 matchs par équipe et 15 points de pourcentage '
            'd’écart. Même compétition, saison et groupe de comparaison.',
        example:
            'En NHL, 16 points sur 20 possibles représentent 80 %, '
            'contre 10 sur 20, soit 50 % : écart de 30 points de pourcentage.',
      ),
      SportReadingDefinition(
        id: 'recent_form_advantage',
        label: 'Avantage de forme',
        description:
            'Les résultats récents opposent deux dynamiques différentes.',
        condition:
            'Les 5 derniers matchs terminés de chaque équipe, avant '
            'la rencontre. Au moins 20 points de pourcentage d’écart.',
        example:
            'En NHL, 4 victoires et 1 défaite en prolongation donnent '
            '9 points sur 10. Deux victoires et trois défaites à 60 minutes '
            'donnent 4 points sur 10.',
      ),
      SportReadingDefinition(
        id: 'winning_streak',
        label: 'Série de victoires',
        description: 'Une équipe enchaîne les victoires avant la rencontre.',
        condition:
            'Au moins 3 victoires consécutives, '
            'prolongation et tirs au but inclus.',
        example:
            'Une victoire à 60 minutes, une en prolongation puis une '
            'aux tirs au but constituent trois victoires consécutives.',
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
