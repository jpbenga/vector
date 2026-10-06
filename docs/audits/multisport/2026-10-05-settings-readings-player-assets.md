# Paramètres, lectures et photos hockey — 5 octobre 2026

## Périmètre

Branche `codex/multisport-hockey`. Corrections locales ; aucune publication sur
`main`, aucune modification de l'authentification ou de la collecte en production.

## Paramètres : cause et correction

Le bouton Paramètres du workspace hockey ouvrait directement `AppearancePage`.
Il ne s'agissait pas d'une sous-page mémorisée après un changement de thème.

Il ouvre désormais `SportSpacePage` (« Mon espace »), qui donne accès à
Apparence, Mes compétitions, Mes lectures et Compte et connexion. Le retour
depuis Apparence retrouve ce menu. Chaque nouvelle ouverture des paramètres
retrouve également ce menu.

L'en-tête et les cartes de navigation sont extraits des composants football
dans `lector_space_widgets.dart` et partagés entre les deux parcours. Le
catalogue des réglages et les préférences restent propres à chaque sport.
L'éditeur peut ouvrir séparément compétitions et lectures, sans effacer les
choix de l'autre section. Les compteurs du menu changent après enregistrement.

## Lectures : audit du compact lu par Flutter

Commande reproductible, sans appel fournisseur :

```sh
dart run tool/sports/audit_hockey_readings.dart
```

Source : `var/sports/hockey/published.json`, collectée le
`2026-10-05T17:08:08.900Z`, 491 rencontres.

| Ligue | Rencontres | Avec au moins une lecture détectée |
| --- | ---: | ---: |
| KHL | 83 | 45 |
| Extraliga | 48 | 15 |
| Liiga | 53 | 20 |
| SHL | 45 | 20 |
| Ligue Magnus | 32 | 10 |
| NHL | 134 | 0 |
| AHL | 96 | 0 |

Ces nombres concernent tout le calendrier du compact et ne correspondent pas
aux compteurs d'une seule journée. Ils recensent les règles détectées avant
filtrage par les lectures activées par un utilisateur.

Trois règles hockey sont actuellement implémentées : avantage au classement,
avantage de forme récente et série de victoires. Elles nécessitent des données
admissibles de saison, phase et historique ; une activation ne force pas une
détection. Les rencontres déjà commencées n'obtiennent pas rétroactivement une
évaluation d'avant-match dans cet adaptateur.

Exemple pour une vérification manuelle : KHL, 6 octobre 2026, 16 h à Paris,
Khabarovsk (extérieur) contre Tractor Chelyabinsk (domicile), match `430528`.
Le compact déclenche un avantage de forme récente et une série de victoires
pour Tractor. Activer ces lectures dans les préférences hockey du navigateur
utilisé permet leur affichage dans Tous et Radar. Pour moi demande également
de suivre la KHL.

Les choix football et hockey sont séparés. Les préférences hockey sont
actuellement conservées dans le navigateur, avec un périmètre compte/invité
et sport. Elles ne sont pas synchronisées avec Supabase entre appareils ou
origines (local et démo, par exemple). Le menu et l'éditeur l'indiquent.
L'audit ne prétend pas avoir lu les choix personnels enregistrés dans le
navigateur distant de l'utilisateur.

## Photos joueurs : limite du fournisseur vérifiée

Documentation officielle :
https://api-sports.io/documentation/hockey/v1

Le catalogue API-Hockey v1 consulté n'offre pas de route de profils joueurs.
`games/events` renvoie des noms dans `players` et `assists`. Les logos présents
dans `team` sont des logos d'équipes.

Vérification des réponses déjà collectées, sans nouvel appel : 2 821 fichiers
`enrichment-cache/games-events-game-*.json`, 31 331 événements, 30 707 entrées
joueurs. Toutes les entrées joueurs sont des chaînes de caractères ; aucun
identifiant fournisseur ou URL de portrait n'est fourni. Les champs des
événements sont `game_id`, `period`, `minute`, `team`, `players`, `assists`,
`comment`, `type`.

Il n'y a donc pas de portrait à récupérer depuis ces réponses. Les composants
communs supportent une photo lorsque celle-ci existe, mais les identifiants
générés à partir des noms hockey ne permettent pas de fabriquer une URL de
photo fiable. Une source supplémentaire et une correspondance d'identités
seraient nécessaires pour ajouter des portraits.

## Vérification

Les tests hockey couvrent, à 360 et 1 100 pixels, le changement réel de thème,
le retour au menu, l'ouverture séparée des sections, l'enregistrement, les
compteurs, la persistance, l'isolation football et l'affichage d'une lecture
sur une carte admissible. Les tests existants couvrent également le détail,
les changements de compte et l'exploration hors compétition suivie.

Le jeu ciblé paramètres, moteur de lectures, persistance, Apparence et design
system compte 58 tests réussis. Le fichier de navigation hockey, renforcé
avec la reconstruction du thème racine, compte 6 tests réussis.
`flutter analyze` ne signale aucun problème et `git diff --check` est propre.
Les deux tests existants ciblant l'ouverture du menu/Apparence et la déconnexion
dans Mon espace football passent également après l'extraction des composants.
