# Tiers Lector et avantage au classement hockey

## Décision issue de la discussion

Les tiers sont un outil analytique Lector commun aux sports. Un classement
régulièrement espacé possède aussi des groupes de tête, milieu et fin ; l'absence
d'une rupture exceptionnelle n'interdit pas ces repères. Le test des anciennes
zones statistiques isolées ne décrivait pas le système T1–T5 du football.

Le hockey utilise maintenant le **même noyau DynamicTierAlgorithmV1** que le
football : points officiels, repères de tête/fin, analyse robuste des ruptures,
segmentation des groupes intermédiaires, contrôle des matchs joués. Le noyau et
ses types indépendants du fournisseur résident dans `lib/core/domain/structural_tiers`.
Les anciens chemins football exportent ces mêmes types ; les paramètres par
défaut, adaptateurs et décisions football sont conservés.

## Politique hockey versionnée

Version : `hockey-standing-tiers-v1`, lectures `hockey-readings-tiers-v2`.
Compétitions API 57, 58, 35, 10, 18, 16, 47 ; saison 2026, saison régulière.
Une autre saison ou compétition nécessite une politique explicite.

- Au moins **5 matchs pour chaque ligne du classement** dans le périmètre choisi.
- T1 : trois premiers pour un groupe d'au moins huit équipes ; deux pour cinq
  à sept équipes ; un pour quatre équipes.
- T5 : les deux derniers pour six équipes ou plus ; le dernier pour quatre/cinq.
- Ces repères sont des choix **analytiques Lector**, indépendants des quotas de
  playoffs. Ils n'appliquent aucune règle de relégation football à la NHL/AHL/KHL.
- Les égalités de points à ces limites restent ensemble. Si les repères se
  recouvrent, les tiers sont indisponibles.
- T2/T3/T4 proviennent de la segmentation dynamique du noyau football ; un tier
  peut être absent. Sans rupture interne : milieu T3, et repères T1/T5 maintenus.
- Le rang officiel, les points, l'appartenance au groupe et les indications
  officielles ne sont pas remplacés par les tiers.
- Les tiers affichés sont présentés comme provisoires. Le seuil de cinq matchs
  permet cette première lecture fonctionnelle ; il ne certifie pas un niveau
  sportif définitif ni une rupture structurelle confirmée dans le temps.

## Détection

`standing_advantage` exige :

1. même compétition, saison et table réelle commune aux deux adversaires ;
2. au moins cinq matchs par adversaire, avec au plus un match joué d'écart ;
3. tiers supérieur, meilleur rang, davantage de points ET meilleur rendement
   en points par match.

Il n'existe plus de seuil fixe de 10/15 points ni de seuil en pourcentage pour
cette lecture. Deux équipes dans le même tier ne la déclenchent pas.

La table commune la plus spécifique est choisie : division si les deux équipes
s'y trouvent ; conférence commune sinon. Si aucune table fournisseur ne contient
les deux adversaires, la lecture s'abstient. Les tiers de deux divisions locales
ne sont pas comparés directement. Le groupe exact et les deux tiers sont dans
l'explication et les preuves de la lecture. Les contrôles existants de phase,
date, cohérence des vues et isolement des préférences sont conservés.

La forme et les séries de victoires restent hors de cette modification.

## Présentation

Les parcours hockey avec et sans contexte de groupes utilisent le tableau et
la légende Lector communs au football, les mêmes couleurs et bandes T1–T5,
ainsi que les surlignages et badges DOM./EXT. Les vues Général, Domicile et
Extérieur calculent leurs tiers sur leurs propres bilans et groupes. Une vue
lieu sans cinq matchs par équipe affiche son motif d'indisponibilité. Les tables
côte à côte restent compactes (position, équipe, J, Pts) et conservent les bandes.

## Contrôle sur les données existantes

Capture du 5 octobre 2026 à 17:08:08.900 UTC ; **ce n'est pas une nouvelle
collecte ni un contrôle du live actuel**. Le script hors ligne
`tool/sports/audit_hockey_readings.dart` appelle l'adaptateur réel.

| Ligue | Lectures d'avantage au classement |
| --- | ---: |
| KHL | 20 |
| Extraliga | 13 |
| Liiga | 16 |
| Magnus | 10 |
| SHL | 0 |
| NHL | 0 |
| AHL | 0 |

Comptage de lectures sur les rencontres de cette capture, avec oppositions
potentiellement répétées. NHL/AHL : échantillon inférieur à cinq matchs ; SHL :
le classement contient encore des équipes avec seulement quatre matchs.

Exemple fictif testé : 12 équipes à 18, 17, …, 7 points après dix matchs donnent
T1 pour les trois premières, T3 pour le milieu et T5 pour les deux dernières.
Premier contre dernier : avantage détecté. Les valeurs de cette simulation ne
représentent pas un classement officiel réel.

Les tests comparent le découpage hockey au noyau football sur cinq distributions,
contrôlent les égalités et les petits groupes, les préférences, les scopes
Général/Domicile/Extérieur, les rôles et les points sur mobile. Les tests existants
du moteur football vérifient la conservation de ses décisions.

Cette itération ne nécessite ni migration Supabase ni appel fournisseur : le
compact contient déjà les classements nécessaires. Travail sur la branche
multisport ; aucune publication de production dans cette itération.

## Résultat de vérification

Les 147 cas ciblés ont réussi après correction de deux assertions de test qui
attendaient encore une table domicile/extérieur fusionnant les conférences.
Les deux conférences restent maintenant distinctes dans tous les périmètres ;
les tests vérifient leurs membres, points, positions et rôles. L’analyse statique
des fichiers de moteur et des adaptateurs modifiés ne signale aucun problème.
Les vues de classement ont été contrôlées notamment à 360 et 390 pixels.
