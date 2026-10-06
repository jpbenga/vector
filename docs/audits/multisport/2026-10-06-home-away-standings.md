# Hockey : points domicile/extérieur et équipes du match

## Périmètre

Correction locale sur `codex/multisport-hockey`, le 6 octobre 2026.
Elle complète l'audit du 5 octobre : le bilan alphabétique sans points n'était
pas le classement domicile/extérieur demandé. Aucun push ni déploiement.

## Deux causes distinctes

1. Les agrégats `/teams/statistics` donnent victoires, défaites et buts par lieu,
   mais ne ventilent pas suffisamment les résultats après prolongation pour
   reconstruire les points. La précédente correction supprimait le pourcentage
   et les rangs calculés sur ce pourcentage, sans construire le vrai bilan par
   points. Les résultats complets de saison sont pourtant déjà collectés.
2. Le détail ouvrait la première conférence du fournisseur. Lors d'une opposition
   entre conférences, l'équipe de l'autre conférence ne figurait pas dans cette
   vue. Les badges partagés ne pouvaient pas annoter une ligne absente. Les
   anciens tests validaient les badges en changeant de conférence ; ils ne
   demandaient pas que les deux équipes soient visibles dès l'ouverture.

## Calcul des points par lieu

`hockey_venue_standings.ts` reconstruit les bilans depuis les résultats terminés
de la saison régulière prise en charge :

- NHL, AHL, KHL : victoire 2 points ; défaite après prolongation/tirs au but
  1 point ; défaite à 60 minutes 0 point.
- Extraliga, Magnus, Liiga, SHL : victoire à 60 minutes 3 points ; victoire après
  prolongation/tirs au but 2 points ; défaite après prolongation/tirs au but
  1 point ; défaite à 60 minutes 0 point.

Les périodes de saison sont celles de la politique régulière 2026 déjà utilisée
par les lectures. Une saison ou une ligue inconnue n'hérite pas du barème NHL.
Les matchs futurs, en cours, annulés et hors de cette période ne contribuent pas.
Les conférences et divisions ne dupliquent pas les matchs ou les bilans.

Les points, matchs, victoires/défaites réglementaires et après prolongation,
ainsi que les buts quand ils sont fournis, sont confrontés au classement général.
Le calendrier peut être plus frais que le classement : on recherche alors le
préfixe chronologique de résultats correspondant au nombre de matchs officiel.
Une rencontre doit être retenue pour ses deux adversaires, jamais un seul.

Lorsque toute cette vérification réussit, le statut est `reconciled` et
domicile + extérieur retrouvent exactement le bilan général. Sinon, le statut
est `partial` : les points proviennent des seuls résultats effectivement
collectés et la vue indique que sa couverture reste à confirmer. Elle ne
prétend pas constituer un classement complet ou officiel.

Ces classements par lieu sont **calculés**. Tri : points, différence de buts,
puis buts marqués ; des valeurs identiques partagent le même rang. Le nom sert
uniquement à stabiliser leur ordre d'affichage. Les départages réglementaires
propres à chaque championnat ne sont pas présentés comme reproduits.
Le classement général conserve les positions officielles du fournisseur.

Le calcul est intégré à la construction du compact. L'enrichissement ultérieur
ne peut plus le remplacer par les agrégats sans points. Il ne nécessite aucun
appel `/teams/statistics` lorsque le nouveau compact est utilisé.

## Composant et parcours

Le hockey transmet ses données à `LectorStandingPanel`,
`LectorStandingDataTable`, `LectorStandingLegend` et `LectorStandingRole`,
les composants du football. Il ne reconstruit ni lignes, ni badges spécifiques.

Les trois vues sont Général, Domicile et Extérieur. DOM./EXT. et les couleurs
du surlignage désignent toujours le rôle réel des équipes dans la rencontre
consultée, quel que soit le sélecteur actif. L'ordre extérieur/domicile du
header hockey ne modifie pas cette identité.

Dans Général, la sélection initiale « Équipes du match » affiche :

- la plus grande table officielle contenant les deux équipes, si elle existe ;
- sinon, les deux conférences/divisions officielles nécessaires, l'une sous
  l'autre, sans inventer un rang général interconférences.

Le sélecteur permet toujours de consulter une conférence ou division seule.
Dans Domicile et Extérieur, la vue calculée couvre l'ensemble des équipes de
la compétition. Les anciens snapshots restent lisibles avec leurs valeurs
indisponibles explicites.

## Reconstruction réelle sans API

La publication locale `1ac3b7ed-761e-4338-b486-59355459dec8` a été reconstruite
uniquement pour ses classements par lieu depuis ses réponses brutes conservées.
Calendrier, scores, préférences, joueurs, confrontations, identifiant et dates
de collecte sont conservés. **Zéro nouvel appel API.**

| Ligue | Équipes | Contrôle du bilan général |
| --- | ---: | --- |
| NHL | 32 | Concordant |
| AHL | 32 | Partiel : 2 équipes ne disposent pas de tous les résultats nécessaires avant la date du snapshot |
| KHL | 22 | Concordant |
| Extraliga | 14 | Concordant |
| Ligue Magnus | 12 | Concordant |
| Liiga | 17 | Concordant |
| SHL | 14 | Concordant |

Outil reproductible, sans clé ou accès réseau :

```sh
deno run --allow-read=var/sports/hockey --allow-write=var/sports/hockey tool/sports/rebuild_hockey_venue_standings.ts
```

## Vérifications

- 18 tests Deno réussis : sept barèmes, temps réglementaire/OT/tirs au but,
  retard du classement, données manquantes, saison inconnue, doublons,
  contamination de ligue/saison et publication/enrichissement existants.
- Tests Flutter sur extraction réelle KHL/SHL : points conservés par le lecteur,
  sommes des bilans comparées au général, rejet de points corrompus, équipes
  étrangères et lignes manquantes.
- À 360 et 1100 pixels, le détail d'une vraie opposition KHL entre conférences
  affiche les deux équipes, leurs badges et les bordures communes dans les
  trois vues ; aucun débordement.
- Changement de conférence et inversion des adversaires vérifiés.
- Le contrôle d'architecture interdit toujours un second assemblage de lignes
  de classement dans les fonctionnalités sportives.
- La publication réelle des sept ligues reste lisible par le codec Flutter.

Fixture : `test/fixtures/sports/hockey_venue_standings_compact.json`.

Les tests des composants football, du design system et des publications hockey
font également partie des vérifications de cette correction.

Le test mobile du classement football de référence passe. L'analyse Flutter
ne signale aucun problème ; `git diff --check` réussit.
