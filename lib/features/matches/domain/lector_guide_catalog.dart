import '../../../core/domain/lector_victory_series.dart';
import '../../onboarding/domain/decision_profile_catalogs.dart';
import 'football_reading.dart';
import 'football_scenario.dart';

/// Editorial explanations of the published rules, not a second detector.
/// Examples are fictional and never enter a feed or the user's preferences.
class LectorReadingGuide {
  const LectorReadingGuide({
    required this.meaning,
    required this.conditions,
    required this.facts,
    required this.conclusion,
    required this.counterExample,
  });
  final String meaning;
  final List<String> conditions;
  final List<String> facts;
  final String conclusion;
  final String counterExample;
}

class LectorGuideCatalog {
  const LectorGuideCatalog._();

  static String readingLabel(String id) =>
      ReadingPreferenceCatalog.values
          .where((reading) => reading.id == canonicalVenueReadingId(id))
          .firstOrNull
          ?.label ??
      _supportLabels[id] ??
      id;

  static const _supportLabels = {
    'ranking_superiority': 'Supériorité au classement',
    'ranking_inferiority': 'Infériorité au classement',
    'form_advantage': 'Avantage de forme',
    'open_match_profile': 'Profil de match ouvert',
    'closed_match_profile': 'Profil de match fermé',
    'high_xg_creation': 'Création xG élevée',
    'high_xg_conceded': 'xG concédés élevés',
  };

  static final readings = <String, LectorReadingGuide>{
    'structural_level_gap': const LectorReadingGuide(
      meaning:
          'Une équipe présente une avance importante et suffisamment '
          'documentée dans son championnat. Être simplement mieux classée ne suffit pas.',
      conditions: [
        'Les deux équipes ont joué au moins cinq matchs et sont séparées par au moins six places.',
        'Lector compare les points par match pour tenir compte des matchs en retard.',
        'L’écart minimal est de 1 point par match après 5 ou 6 matchs, puis '
            '0,9 / 0,8 / 0,7 / 0,6 / 0,5 après 7 / 8 / 9 / 10 / 11 matchs. '
            'À partir de 12 matchs, il est de 0,4.',
      ],
      facts: [
        'Atlas : 2e, 36 points en 16 matchs, soit 2,25 points par match.',
        'Rivage : 14e, 16 points en 16 matchs, soit 1 point par match.',
        '12 places et 1,25 point par match séparent les équipes.',
      ],
      conclusion: 'L’écart de niveau structurel est détecté pour Atlas.',
      counterExample:
          'Le 2e affronte le 3e : même avec un avantage de points, '
          'l’écart de places est insuffisant pour cette lecture.',
    ),
    'winning_streak': const LectorReadingGuide(
      meaning:
          'Une équipe enchaîne au moins trois victoires tous lieux confondus.',
      conditions: [
        'Les résultats sont ordonnés du plus récent au plus ancien dans la même compétition.',
        'Trois victoires consécutives tous lieux confondus ; un nul ou une défaite dans ce périmètre arrête la série.',
        'Cinq est un jalon. La série continue à six, sept et plus. Si l’historique ne prouve pas son début, le nombre est indiqué au moins.',
      ],
      facts: [
        'Atlas : quatre victoires consécutives tous lieux confondus.',
        'La prochaine rencontre peut prolonger cette série jusqu’à cinq.',
      ],
      conclusion:
          'Série détectée dès la troisième victoire ; sa longueur décrit le passé.',
      counterExample:
          'Deux victoires suivies d’un nul tous lieux confondus ne constituent pas une série active de trois victoires. La longueur ne suffit pas à calculer un risque de rupture.',
    ),
    'positive_streak': const LectorReadingGuide(
      meaning:
          'Une équipe reste invaincue et accumule des points sur ses cinq derniers matchs.',
      conditions: [
        'Cinq résultats complets sont disponibles.',
        'Aucune défaite et au moins 9 points sur 15 : une victoire vaut 3 points, un nul 1 point.',
      ],
      facts: [
        'Atlas, du plus ancien au plus récent : V · N · V · V · V.',
        '4 victoires et 1 nul : 13 points sur 15, aucune défaite.',
      ],
      conclusion: 'La dynamique positive est détectée pour Atlas.',
      counterExample:
          'V · V · V · V · D donne 12 points, mais contient une défaite : '
          'la condition d’invincibilité n’est pas remplie.',
    ),
    'negative_streak': const LectorReadingGuide(
      meaning:
          'Une équipe récolte très peu de points sur ses cinq derniers matchs.',
      conditions: [
        'Cinq résultats complets sont disponibles.',
        'Le total est de 4 points sur 15 ou moins.',
      ],
      facts: [
        'Rivage : D · N · D · V · D.',
        'Une victoire et un nul : 4 points sur 15.',
      ],
      conclusion: 'La dynamique négative est détectée pour Rivage.',
      counterExample:
          'Deux victoires donnent déjà 6 points : cette série ne remplit pas ce critère.',
    ),
    'improving_form': const LectorReadingGuide(
      meaning:
          'Les résultats les plus récents sont meilleurs que ceux du début de la série.',
      conditions: [
        'Lector observe cinq matchs.',
        'La moyenne des points des deux derniers matchs dépasse celle des trois précédents d’au moins 1 point.',
      ],
      facts: [
        'Atlas : D · N · D, puis V · V.',
        'Les trois premiers donnent 0,33 point par match ; les deux derniers, 3 points.',
      ],
      conclusion:
          'La forme est en hausse, même si les cinq matchs ne constituent pas une série invaincue.',
      counterExample:
          'V · V · V · V · V : la forme est excellente, mais elle ne progresse pas entre les deux fenêtres.',
    ),
    'declining_form': const LectorReadingGuide(
      meaning:
          'Les résultats les plus récents sont moins bons que ceux du début de la série.',
      conditions: [
        'Lector observe cinq matchs.',
        'La moyenne des points des deux derniers matchs est inférieure d’au moins 1 point à celle des trois précédents.',
      ],
      facts: [
        'Rivage : V · V · N, puis D · D.',
        'La moyenne passe de 2,33 points par match à 0.',
      ],
      conclusion: 'La forme est en baisse pour Rivage.',
      counterExample:
          'D · D · D · D · D : la série est mauvaise, mais elle ne se dégrade pas davantage entre les deux fenêtres.',
    ),
    'form_gap': const LectorReadingGuide(
      meaning:
          'La différence de résultats récents entre les deux équipes est particulièrement grande.',
      conditions: [
        'Cinq matchs sont disponibles pour chaque équipe.',
        'Leurs totaux de points sur 15 sont séparés par au moins 9 points.',
      ],
      facts: [
        'Atlas : 13 points sur 15.',
        'Rivage : 4 points sur 15.',
        '13 − 4 = 9 points d’écart.',
      ],
      conclusion: 'L’écart de forme est détecté en faveur d’Atlas.',
      counterExample:
          '13 contre 5 donne 8 points d’écart : l’avantage existe, mais cette lecture n’est pas détectée.',
    ),
    for (final venue in [
      (id: 'strong_home_team', place: 'à domicile', strong: true),
      (id: 'weak_home_team', place: 'à domicile', strong: false),
      (id: 'strong_away_team', place: 'à l’extérieur', strong: true),
      (id: 'weak_away_team', place: 'à l’extérieur', strong: false),
    ])
      venue.id: LectorReadingGuide(
        meaning:
            'Cette lecture mesure une série actuelle ${venue.place}, sur les résultats finaux.',
        conditions: [
          'Au moins trois ${venue.strong ? "victoires" : "défaites"} consécutives ${venue.place}.',
          'Un nul ou un résultat opposé sur ce lieu interrompt la série.',
          'Les matchs sur l’autre lieu ne changent pas cette série.',
        ],
        facts: [
          'Atlas : quatre ${venue.strong ? "victoires" : "défaites"} consécutives ${venue.place}.',
        ],
        conclusion:
            'Atlas est ${venue.strong ? "solide" : "fragile"} ${venue.place} sur sa série actuelle.',
        counterExample:
            'Un bilan de 12 victoires en 20 matchs ne suffit pas : les trois derniers résultats sur ce lieu doivent être consécutifs.',
      ),
    'home_away_advantage': const LectorReadingGuide(
      meaning:
          'La force du recevant à domicile rencontre la fragilité du visiteur à l’extérieur.',
      conditions: [
        'Le recevant a au moins trois victoires consécutives à domicile.',
        'Le visiteur a au moins trois défaites consécutives à l’extérieur.',
      ],
      facts: [
        'Atlas reçoit : quatre victoires consécutives à domicile.',
        'Rivage se déplace : trois défaites consécutives à l’extérieur.',
      ],
      conclusion:
          'Les deux constats convergent en faveur d’Atlas sur le lieu du match.',
      counterExample:
          'Atlas est solide chez lui, mais Rivage gagne aussi régulièrement à l’extérieur : la deuxième condition manque.',
    ),
    'away_home_advantage': const LectorReadingGuide(
      meaning:
          'La force du visiteur en déplacement rencontre la fragilité du recevant chez lui.',
      conditions: [
        'Le visiteur a au moins trois victoires consécutives à l’extérieur.',
        'Le recevant a au moins trois défaites consécutives à domicile.',
      ],
      facts: [
        'Atlas se déplace : quatre victoires consécutives à l’extérieur.',
        'Rivage reçoit : trois défaites consécutives à domicile.',
      ],
      conclusion:
          'L’avantage sur le lieu du match concerne ici le visiteur, Atlas.',
      counterExample:
          'Atlas est solide en déplacement, mais Rivage a un bilan équilibré chez lui : la combinaison n’est pas réunie.',
    ),
    for (final metric in [
      (id: 'prolific_attack', action: 'marque', high: true, rate: '2,4'),
      (id: 'scoring_difficulty', action: 'marque', high: false, rate: '0,5'),
      (id: 'solid_defense', action: 'encaisse', high: false, rate: '0,4'),
      (id: 'fragile_defense', action: 'encaisse', high: true, rate: '2,2'),
    ])
      metric.id: LectorReadingGuide(
        meaning:
            'Lector compare le nombre de buts que l’équipe ${metric.action} par match '
            'à celui des autres équipes de son championnat.',
        conditions: [
          'Les buts et le nombre de matchs joués sont connus.',
          'Une comparaison avec les équipes du même championnat est disponible.',
          'L’équipe appartient à une zone ${metric.high ? 'haute' : 'basse'} nettement isolée de cette distribution.',
        ],
        facts: [
          'Atlas ${metric.action} ${metric.rate} buts par match.',
          'Dans ce championnat fictif, le moteur situe ce bilan dans la zone ${metric.high ? 'haute' : 'basse'} isolée.',
        ],
        conclusion:
            '${readingLabel(metric.id)} est détectée pour Atlas dans ce contexte.',
        counterExample:
            'Le même chiffre, dans un championnat où les autres équipes '
            'ont des bilans similaires, ne suffit pas : il n’existe pas de seuil universel de buts.',
      ),
    'frequent_clean_sheet': const LectorReadingGuide(
      meaning:
          'Un clean sheet est un match terminé sans encaisser de but. '
          'Lector recherche les équipes qui en obtiennent particulièrement souvent.',
      conditions: [
        'Les matchs sans but encaissé et le nombre de matchs joués sont connus.',
        'La proportion se situe dans la zone haute isolée du championnat.',
      ],
      facts: [
        'Atlas a gardé sa cage inviolée dans 7 matchs sur 10.',
        'Cette fréquence de 70 % appartient à la zone haute isolée de ce championnat fictif.',
      ],
      conclusion: 'Les clean sheets fréquents sont détectés pour Atlas.',
      counterExample:
          'Un seul match sans encaisser, ou une fréquence ordinaire dans ce championnat, ne suffit pas à caractériser cette tendance.',
    ),
    for (final goals in [
      (
        id: 'frequent_over_25',
        meaning: 'Au moins 3 buts au total',
        scores: '2–1, 3–0, 2–2',
        opposite: '1–0',
      ),
      (
        id: 'frequent_under_25',
        meaning: 'Au plus 2 buts au total',
        scores: '1–0, 0–0, 1–1',
        opposite: '2–1',
      ),
      (
        id: 'frequent_btts',
        meaning: 'Les deux équipes marquent',
        scores: '1–1, 2–1, 2–2',
        opposite: '3–0',
      ),
    ])
      goals.id: LectorReadingGuide(
        meaning:
            '${goals.meaning} : Lector recherche une fréquence élevée '
            'de ce type de score dans les matchs de l’équipe.',
        conditions: [
          'Les scores finaux des matchs de la compétition sont disponibles.',
          'La proportion de matchs concernés appartient à la zone haute isolée du championnat.',
        ],
        facts: [
          'Exemples de scores concernés : ${goals.scores}.',
          '7 des 10 matchs d’Atlas remplissent ce critère.',
          'Dans ce championnat fictif, 70 % appartient à la zone haute isolée.',
        ],
        conclusion: 'La tendance est détectée pour les matchs d’Atlas.',
        counterExample:
            'Un score ${goals.opposite} ne remplit pas le critère. '
            'Une fréquence qui ne se distingue pas du championnat ne déclenche pas la lecture.',
      ),
    'misleading_result': const LectorReadingGuide(
      meaning:
          'Une série favorable mérite une nuance quand les buts marqués '
          'dépassent nettement la qualité des occasions créées, mesurée par les xG.',
      conditions: [
        'Une série invaincue récente est observée.',
        'Les buts et les xG récents sont disponibles.',
        'L’écart buts moins xG se situe dans la zone haute isolée du championnat.',
      ],
      facts: [
        'Atlas reste invaincu dans sa série récente.',
        'Sur les matchs couverts par les xG, il marque 6 buts pour 2 xG au total.',
        'Cet écart est classé dans la zone haute isolée du championnat fictif.',
      ],
      conclusion:
          'Lector ajoute une nuance à la série favorable : les résultats '
          'et la création d’occasions ne racontent pas exactement la même chose.',
      counterExample:
          'Les xG manquent, ou les buts et les xG sont proches : '
          'Lector ne peut pas établir cette nuance à partir du score seul.',
    ),
    'head_to_head_dominance': const LectorReadingGuide(
      meaning:
          'Une équipe domine nettement les confrontations précédentes avec le même adversaire.',
      conditions: [
        'Les six dernières confrontations terminées sont disponibles.',
        'Pour les clubs, elles concernent la même compétition. Pour les sélections, '
            'les matchs internationaux officiels des trois années précédentes sont retenus, sans amicaux.',
        'La domination globale correspond à 6 victoires, 5 victoires et 1 nul, '
            'ou 5 victoires et 1 défaite. Une variante sur un lieu existe avec '
            'au moins 3 confrontations sur ce lieu, au moins 2 victoires et aucune défaite.',
      ],
      facts: [
        'Sur les six confrontations éligibles, Atlas compte 5 victoires et 1 nul contre Rivage.',
      ],
      conclusion: 'La domination en tête-à-tête est détectée pour Atlas.',
      counterExample:
          'Seules deux confrontations sont disponibles : même avec deux victoires, '
          'la fenêtre requise est incomplète.',
    ),
    for (final period in [
      (
        id: 'frequent_first_half_scoring',
        verb: 'marque',
        period: 'première mi-temps',
      ),
      (
        id: 'frequent_first_half_conceding',
        verb: 'encaisse',
        period: 'première mi-temps',
      ),
      (
        id: 'frequent_second_half_scoring',
        verb: 'marque',
        period: 'seconde mi-temps',
      ),
      (
        id: 'frequent_second_half_conceding',
        verb: 'encaisse',
        period: 'seconde mi-temps',
      ),
    ])
      period.id: LectorReadingGuide(
        meaning:
            'Cette lecture précise quand les buts arrivent : Atlas ${period.verb} '
            'particulièrement souvent en ${period.period}.',
        conditions: [
          'La répartition des buts par période est disponible.',
          'Le nombre de buts par match sur cette période dépasse la moyenne du championnat.',
        ],
        facts: [
          'Atlas ${period.verb} 0,9 but par match en ${period.period}.',
          'La moyenne de ce championnat fictif sur la même période est de 0,5.',
        ],
        conclusion: 'La lecture est détectée pour Atlas sur cette période.',
        counterExample:
            'Atlas est à 0,4 alors que la moyenne vaut 0,5 : '
            'ce bilan ne dépasse pas la référence. Un total de buts sans leur répartition ne suffit pas non plus.',
      ),
    'standout_decisive_player': const LectorReadingGuide(
      meaning:
          'Un joueur répète des contributions offensives récentes : buts et passes décisives sont additionnés.',
      conditions: [
        'Lector examine les trois derniers matchs terminés.',
        'Le joueur apparaît dans au moins deux matchs et contribue dans au moins deux.',
        'Ses buts et passes représentent au moins 0,8 action décisive pour 90 minutes jouées.',
      ],
      facts: [
        'Alex joue 270 minutes sur trois matchs.',
        'Il inscrit 2 buts et délivre 1 passe décisive, répartis sur deux matchs.',
        '3 contributions en 270 minutes = 1 action décisive pour 90 minutes.',
      ],
      conclusion: 'Alex est identifié comme joueur décisif à surveiller.',
      counterExample:
          'Trois buts dans un seul match et aucune contribution dans les deux autres : '
          'la répétition sur au moins deux matchs manque.',
    ),
    'key_player_unavailable': const LectorReadingGuide(
      meaning:
          'Une absence déclarée concerne un joueur qui présente le profil récent d’un joueur décisif.',
      conditions: [
        'Le joueur remplit les critères récents de contribution offensive.',
        'Le fournisseur le signale absent pour cette rencontre.',
        'Le match se situe dans les 24 heures suivant la collecte de cette information.',
      ],
      facts: [
        'Alex contribue dans deux des trois derniers matchs, à 1 action décisive pour 90 minutes.',
        'Il est déclaré absent pour Atlas–Rivage, prévu dans 12 heures.',
      ],
      conclusion: 'Son absence est signalée comme celle d’un joueur important.',
      counterExample:
          'Alex ne figure pas dans les informations d’absence : '
          'ne pas avoir sa composition ne permet pas de le déclarer absent.',
    ),
    'ranking_superiority': const LectorReadingGuide(
      meaning:
          'Une équipe est mieux classée que son adversaire et récolte davantage de points par match.',
      conditions: [
        'Les places, points et matchs joués des deux équipes sont connus.',
        'L’équipe est devant au classement et sa moyenne de points par match est supérieure.',
      ],
      facts: [
        'Atlas : 2e, 30 points en 15 matchs, soit 2 points par match.',
        'Rivage : 10e, 18 points en 15 matchs, soit 1,2 point par match.',
      ],
      conclusion:
          'Atlas présente une supériorité au classement. '
          'Le critère d’écart structurel est évalué séparément.',
      counterExample:
          'Atlas est devant uniquement parce qu’il a joué davantage, '
          'mais récolte moins de points par match : les deux critères ne sont pas réunis.',
    ),
    'ranking_inferiority': const LectorReadingGuide(
      meaning:
          'Une équipe est derrière son adversaire au classement et récolte moins de points par match.',
      conditions: [
        'Les bilans des deux équipes sont disponibles.',
        'La place et la moyenne de points par match sont toutes deux défavorables.',
      ],
      facts: [
        'Atlas : 10e, 1,2 point par match.',
        'Rivage : 2e, 2 points par match.',
      ],
      conclusion:
          'Atlas présente une infériorité au classement ; sa forme récente est une autre question.',
      counterExample:
          'Une position inférieure avec une meilleure moyenne de points par match '
          'ne suffit pas à réunir ces deux constats.',
    ),
    'form_advantage': const LectorReadingGuide(
      meaning:
          'Une équipe a pris plus de points que son adversaire sur les cinq derniers matchs.',
      conditions: [
        'Cinq résultats sont disponibles pour chaque équipe.',
        'Le total de points de l’équipe est strictement supérieur à celui de son adversaire.',
      ],
      facts: ['Atlas : 10 points sur 15.', 'Rivage : 7 points sur 15.'],
      conclusion:
          'Atlas possède un avantage de forme. La lecture « Écart de forme » '
          'demande, elle, au moins 9 points de différence.',
      counterExample:
          '10 points contre 10 : aucune équipe ne possède cet avantage.',
    ),
    for (final profile in [
      (id: 'open_match_profile', high: true, average: '3,4'),
      (id: 'closed_match_profile', high: false, average: '1,4'),
    ])
      profile.id: LectorReadingGuide(
        meaning:
            'Les matchs des deux équipes présentent tous deux un total de buts '
            '${profile.high ? 'élevé' : 'faible'} par rapport au championnat.',
        conditions: [
          'Le total inclut les buts des deux adversaires dans chaque match passé.',
          'Les profils des deux équipes sont dans la même zone ${profile.high ? 'haute' : 'basse'} isolée du championnat.',
        ],
        facts: [
          'Les matchs d’Atlas et ceux de Rivage comptent environ ${profile.average} buts au total.',
          'Les deux bilans sont classés dans la zone ${profile.high ? 'haute' : 'basse'} isolée de ce championnat fictif.',
        ],
        conclusion:
            'Le match présente un profil ${profile.high ? 'ouvert' : 'fermé'}.',
        counterExample:
            'Une équipe est dans la zone haute et l’autre dans la zone basse : '
            'les deux profils ne convergent pas.',
      ),
    for (final xg in [
      (
        id: 'high_xg_creation',
        action: 'crée',
        meaning: 'des occasions de qualité',
        value: '2,1',
      ),
      (
        id: 'high_xg_conceded',
        action: 'concède',
        meaning: 'des occasions de qualité à l’adversaire',
        value: '2,0',
      ),
    ])
      xg.id: LectorReadingGuide(
        meaning:
            'L’équipe ${xg.action} ${xg.meaning}. Les xG mesurent '
            'la qualité des occasions, même lorsqu’elles ne se terminent pas par un but.',
        conditions: [
          'Les xG récents sont disponibles avant le match.',
          'La moyenne se situe dans la zone haute isolée du championnat.',
        ],
        facts: [
          'Atlas ${xg.action} ${xg.value} xG par match.',
          'Cette moyenne appartient à la zone haute isolée du championnat fictif.',
        ],
        conclusion: '${readingLabel(xg.id)} est détectée pour Atlas.',
        counterExample:
            'Les scores sont connus mais les xG manquent : '
            'le nombre de buts ne permet pas de remplacer cette mesure.',
      ),
  };

  static String requirementSubjectLabel(ScenarioRequirementSubject subject) =>
      switch (subject) {
        ScenarioRequirementSubject.subject => 'Même équipe',
        ScenarioRequirementSubject.opponent => 'Son adversaire',
        ScenarioRequirementSubject.home => 'Équipe à domicile',
        ScenarioRequirementSubject.away => 'Équipe à l’extérieur',
        ScenarioRequirementSubject.match => 'Le match',
        ScenarioRequirementSubject.bothTeams => 'Les deux équipes',
        ScenarioRequirementSubject.atLeastOneTeam => 'Au moins une équipe',
      };
}

/// Demonstrates the real scenario contract with identified, fictional readings.
/// Detection is delegated to the production domain detector, including subject
/// constraints. No thresholds or AND/OR rules are recreated here.
class LectorScenarioExample {
  const LectorScenarioExample(this.definition);
  final FootballScenarioDefinition definition;
  static const homeId = 'guide-atlas';
  static const awayId = 'guide-rivage';
  static const fixtureId = 'guide-atlas-rivage';

  List<FootballReading> readings({bool omitLast = false}) {
    final requirements = omitLast
        ? definition.requirements.take(definition.requirements.length - 1)
        : definition.requirements;
    return [
      for (final requirement in requirements)
        for (final side in switch (requirement.subject) {
          ScenarioRequirementSubject.match => [ReadingSubjectSide.match],
          ScenarioRequirementSubject.away ||
          ScenarioRequirementSubject.opponent => [ReadingSubjectSide.away],
          ScenarioRequirementSubject.bothTeams => [
            ReadingSubjectSide.home,
            ReadingSubjectSide.away,
          ],
          _ => [ReadingSubjectSide.home],
        })
          FootballReading(
            id: requirement.readingId,
            subjectTeamId: switch (side) {
              ReadingSubjectSide.match => fixtureId,
              ReadingSubjectSide.home => homeId,
              ReadingSubjectSide.away => awayId,
            },
            subjectSide: side,
            status: ReadingStatus.detected,
            strength: ReadingStrength.moderate,
            evidence: const [],
            warnings: const [],
            asOf: DateTime.utc(2026, 1, 1),
            sampleSize: 5,
          ),
    ];
  }

  bool detected({bool omitLast = false}) =>
      FootballScenarioDetector(definitions: [definition])
          .detect(
            analysis: FootballAnalysis(
              fixtureId: fixtureId,
              asOf: DateTime.utc(2026, 1, 1),
              readings: readings(omitLast: omitLast),
            ),
            homeTeamId: homeId,
            awayTeamId: awayId,
          )
          .isNotEmpty;

  String subjectName(ScenarioRequirementSubject subject) => switch (subject) {
    ScenarioRequirementSubject.match => 'Atlas–Rivage',
    ScenarioRequirementSubject.opponent ||
    ScenarioRequirementSubject.away => 'Rivage',
    ScenarioRequirementSubject.bothTeams => 'Atlas et Rivage',
    _ => 'Atlas',
  };
}
