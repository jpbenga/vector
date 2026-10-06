# Séries par lieu et confrontations

Date : 7 octobre 2026. Branche : `codex/multisport-hockey`.

Ce document complète et remplace les règles de séries par lieu du document
`2026-10-06-hockey-form-and-series-readings.md`.

## Règles communes football et hockey

| Identifiant | Lecture | Détection |
| --- | --- | --- |
| strong_home_team | Solide à domicile | Au moins trois victoires consécutives à domicile |
| weak_home_team | Fragile à domicile | Au moins trois défaites consécutives à domicile |
| strong_away_team | Solide à l'extérieur | Au moins trois victoires consécutives à l'extérieur |
| weak_away_team | Fragile à l'extérieur | Au moins trois défaites consécutives à l'extérieur |
| home_away_advantage | Avantage domicile / extérieur | Recevant solide à domicile ET visiteur fragile à l'extérieur |
| away_home_advantage | Avantage extérieur / domicile | Visiteur solide à l'extérieur ET recevant fragile à domicile |

Les résultats sur l'autre lieu ne coupent pas une série. Un nul au football
coupe une série de victoires **et** une série de défaites. Les résultats finaux
hockey, prolongation et tirs au but inclus, font foi ; le point donné pour une
défaite en prolongation ne transforme pas celle-ci en victoire.

Le compteur Dart est partagé avec les séries générales et le radar. Son
équivalent serveur fournit les lectures football publiées. Les résultats
inconnus et les lieux inconnus interrompent la preuve. Les jeux futurs, le
match étudié et les doublons sont écartés avant comptage. Le comptage continue
au-delà de cinq ; un historique tronqué prouve « au moins N », pas exactement N.
Les bilans de saison ne servent jamais de secours pour déclencher ces lectures.

Les deux anciennes préférences `home_winning_streak` et `away_winning_streak`
sont converties respectivement en `strong_home_team` et `strong_away_team`.
Les deux lectures équivalentes ne sont donc pas affichées deux fois. Les choix
existants sont conservés ; aucune autre lecture n'est activée automatiquement.
Les préférences hockey restent isolées du profil football. `Pour moi` exige
encore une compétition suivie et une lecture choisie détectée.

## Tête-à-tête hockey

La lecture `head_to_head_dominance` examine les trois dernières confrontations
admissibles dans les trois années calendaires avant le match étudié, connues à
la date de capture. Elle exige trois victoires finales sur ces trois rencontres.

Le championnat et les coupes / phases finales explicitement identifiées sont
évalués **séparément**. Une victoire en coupe ne remplace pas une confrontation
manquante de championnat. Amicaux, exhibition et préparation sont exclus.
Le domicile réel des équipes reste celui du match historique ; inverser les
lieux ne change pas l'identité du vainqueur. Le filtre d'affichage DOM./EXT.
reste celui du composant partagé.

La collecte conserve la phase explicite et la catégorie sous
`competitionPhase` / `competitionKind`. Le seul identifiant d'une ligue ne
prouve plus qu'une rencontre appartient à la saison régulière. Les anciennes
captures sont reclassifiées avec la même politique que les nouvelles.

Pour la NHL, les fenêtres officielles 2023–2026 permettent de reconnaître la
saison régulière et d'écarter la préparation même si l'API indique seulement
« NHL ». La période du 4 au 7 octobre 2024 reste incertaine sans phase explicite,
car préparation et Global Series se chevauchent. La fin de fenêtre inclut les
départs de matchs jusqu'à 07:00 UTC du lendemain de la dernière journée locale.
Les dates hors fenêtre ne sont pas automatiquement qualifiées de playoffs.

Sources des fenêtres :
- [2023–2024, calendrier NHL officiel](https://media.nhl.com/site/vasset/public/attachments/2023/07/17249/NHL-Stats-Pack_2023-24-Regular-Season-Schedule.pdf)
- [2024–2025, calendrier NHL officiel](https://media.nhl.com/site/vasset/public/attachments/2024/07/18238/2024-25%20Regular-Season%20Schedule%20FINAL.pdf)
- [Préparation 2024–2025](https://www.nhl.com/news/nhl-announces-2024-25-preseason-schedule)
- [2025–2026, calendrier NHL officiel](https://media.nhl.com/site/vasset/public/attachments/2025/07/19119/2025-26%20Regular-Season%20Schedule%20News%20Release.pdf)
- [2026–2027, calendrier NHL officiel](https://www.nhl.com/news/nhl-releases-2026-27-regular-season-schedule)

Limite explicite : les autres ligues nécessitent une phase fournie ou une
future fenêtre vérifiée pour cette lecture H2H. « League » seul ne suffit pas.
Les matchs sans phase vérifiable ne prouvent pas une domination et restent
consultables dans « Toutes compétitions ». Une compétition différente n'est
pas automatiquement une coupe. Cette abstention ne modifie pas les autres
lectures de forme ou de classement.

Les deux sports utilisent le même composant TAT et ses vues Championnat,
Coupes et Toutes compétitions. Chaque vue conserve jusqu'à six rencontres ;
un échantillon récent de coupes ne peut plus masquer l'échantillon de ligue.
La politique factuelle football sur trois ans est conservée et enrichie avec
le type de compétition fourni par l'API. La lecture de domination football
précédemment retirée n'est pas réactivée par cette itération.

## Publication football

Le calcul serveur utilise les résultats chronologiques `recent_league_matches`,
pas les compteurs `teams/statistics`. Les annonces nouvelles utilisent
`server_venue_momentum_v2`, une variante de clé et une version de règle dédiées.
La solidité se valide par une victoire finale ; la fragilité par une défaite.
Les anciennes annonces restent immuables pour leur bilan historique. La
matérialisation du flux écarte les anciennes règles de lieu sur les matchs à
venir et les noms de séries par lieu devenus redondants.

Aucun changement SQL et aucune collecte fournisseur n'ont été nécessaires pour
le développement et les tests. Les futures collectes H2H utilisent le même
appel historique : conserver deux échantillons peut demander davantage
*d'enrichissements d'événements* lorsque les deux vues contiennent des matchs
supplémentaires, avec les caches et plafonds existants.

Pour rendre ces règles visibles sur les données football distantes : déployer
`publish-reading-announcements` et `analyze-match-feed-snapshot`, puis publier
un nouveau snapshot. La conservation des échantillons H2H étendus demande
également les versions mises à jour de `api-football-sync` (helper partagé) et
`build-match-feed-snapshot`. Les captures et bilans passés ne sont pas réécrits.
Les changements restent locaux jusqu'à validation et publication demandée.
