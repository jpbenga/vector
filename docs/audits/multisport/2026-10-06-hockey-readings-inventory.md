# État des lieux des lectures hockey — 6 octobre 2026

Audit du code de `codex/multisport-hockey` et évaluation hors ligne du compact
réel déjà compilé dans la démo. Aucun nouvel appel fournisseur, aucun changement
de préférences, de règles, de base de données ou de déploiement.

## Fonctionnel aujourd'hui

Trois détecteurs sont implémentés, proposés dans les préférences et raccordés
aux cartes, à Pour moi, à Tous/Radar et au détail du match :

| Lecture | Règle implémentée |
| --- | --- |
| Avantage au classement | Deux équipes avec au moins 10 matchs ; tableau fournisseur commun et cohérent ; écart de rendement des points disponibles ≥ 15 points de pourcentage |
| Avantage de forme | Cinq matchs terminés admissibles par équipe ; rendement des points disponibles avec le barème de la ligue ; écart ≥ 20 points de pourcentage |
| Série de victoires | Trois dernières victoires consécutives, prolongation et tirs au but inclus |

Chaque évaluation identifie l'équipe, le match, la date, l'échantillon, les
preuves et la version de politique. Elle distingue détectée, non détectée et
données insuffisantes. Les seuils sont ceux de `hockey-readings-draft-v1` :
hypothèses initiales, non calibrées et sans performance mesurée.

La configuration est séparée par sport et identité et enregistrée localement
dans le navigateur. Aucun choix n'est activé au premier accès. Pour moi exige
une compétition suivie et au moins une lecture choisie détectée. Tous et Radar
montrent les lectures choisies également dans les compétitions non suivies.
La synchronisation des préférences entre appareils n'est pas encore implémentée.

## Règles sportives représentées dans le code

Les politiques explicites distinguent NHL/AHL/KHL (famille 2/2/2/1/0) et
Extraliga/Magnus/Liiga/SHL (3/2/2/1/0). Il s'agit des politiques implémentées,
pas d'une nouvelle vérification exhaustive des règlements officiels.
Une ligue ou saison inconnue n'hérite pas par défaut du barème NHL.

Les politiques actuelles ne prennent en charge que la saison fournisseur 2026,
avec des bornes de dates régulières fixées dans l'adaptateur. L'absence de phase
vérifiable et les historiques non admissibles entraînent une abstention.
La lecture de classement exige un vrai tableau contenant les deux équipes ;
l'affichage côte à côte de divisions différentes ne crée pas de comparaison
analytique. Les matchs terminés du futur ou d'une autre identité sont rejetés.

Le Radar équipes conserve désormais l'historique complet disponible avec
cinq résultats récents et départage historique. Le Radar joueurs exploite les
contributions buts/passes sur trois matchs ; sa présence ne constitue pas encore
une lecture `standout_decisive_player` hockey activable.

## Mesure sur la publication réelle

Capture : 2026-10-05T17:08:08.900Z. 491 rencontres au total, dont 313 alors à venir.
110 rencontres portent au moins une lecture détectée, indépendamment des
préférences d'un utilisateur, sur toute la fenêtre du compact. Ce ne sont ni
110 matchs du jour ni une mesure de réussite. Les scores live peuvent avoir
évolué depuis ; les chiffres ci-dessous restent attachés à la capture de base.

| Ligue | Rencontres du compact | Rencontres avec lecture | Classement | Forme | Série |
| --- | ---: | ---: | ---: | ---: | ---: |
| KHL | 83 | 45 | 25 | 31 | 9 |
| Extraliga | 48 | 15 | 0 | 14 | 15 |
| Liiga | 53 | 20 | 8 | 16 | 5 |
| SHL | 45 | 20 | 0 | 17 | 16 |
| Ligue Magnus | 32 | 10 | 0 | 9 | 7 |
| NHL | 134 | 0 | 0 | 0 | 0 |
| AHL | 96 | 0 | 0 | 0 | 0 |

Les colonnes de lectures comptent des évaluations par équipe : elles ne
s'additionnent pas pour obtenir les rencontres uniques.
NHL : historique marqué non vérifié et échantillons insuffisants à la capture.
AHL : historiques et nombre de matchs insuffisants. Pas de lecture artificielle.

## Définitions présentes mais non activées

- Avantage au poste de gardien : non implémenté ; identité/présence/performance
  du gardien à établir.
- Supériorité et infériorité numériques : non implémenté ; les occasions de
  power play et les situations correspondantes ne sont pas établies dans le compact.
- Repos et enchaînement des matchs : non implémenté ; base calendrier disponible,
  règles et couverture historique à définir.
- Scénario Avantages convergents : définition + combinaison classement/forme
  pour la même équipe et date, testées dans le moteur. Aucun appel au combinatoire
  dans le parcours applicatif et aucune préférence scénario hockey persistée.

## Écart avec le football et suites

Le football garde son catalogue existant de 28 préférences et ses moteurs.
Le registre FootballModule ne porte pas encore ces définitions : la séparation
technique existe, mais le catalogue métier commun n'est pas encore finalisé.
La matrice documentaire identifie 18 concepts communs, 4 sous conditions et
6 variantes football ; elle ne représente pas 28 détecteurs hockey actifs.
Les trois IDs hockey actuels n'ont pas été assimilés à des lectures football
qui ont un autre sens (avantage modéré vs écart marqué, série de victoires vs
dynamique positive).

Les évaluations sont calculées avant match à la capture du compact. Lorsqu'un
match alors à venir devient live, la carte peut conserver ces évaluations via
le compact de base tandis que le score est actualisé. Elles ne sont pas
recalculées à partir du live. Une nouvelle capture après le début du match
n'invente pas de lecture antérieure : il n'y a pas d'archive indépendante des
évaluations ni de validation/invalidation après résultat, ni de bilan hockey.

Ordre proposé pour le prochain chantier :

1. Fixer les identités/sens communs et les politiques sport+ligue+saison+phase.
2. Calibrer les trois lectures existantes et définir ce qui valide chaque lecture.
3. Étendre avec données disponibles : dynamiques, évolution de forme,
   domicile/extérieur, attaque/défense et H2H ; vérifier les périmètres de score.
4. Conserver l'évaluation avant match puis produire les verdicts et le bilan.
5. Ajouter les lectures par tiers et de repos ; garder gardiens et situations
   spéciales conditionnés à des preuves réellement collectées.

Résultats détaillés reproductibles : `2026-10-06-hockey-readings-inventory.json`.
