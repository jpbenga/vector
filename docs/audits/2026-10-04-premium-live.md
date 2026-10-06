# Live commun — 4 octobre 2026

## État de livraison

Implémentation locale dans le checkout football `lector-football-production-audit`
(branch `main`, base `61503be`) et dans `lector-api-football-orchestration`
(branch `codex/multisport-hockey`, base `dcbf3cf`). La validation locale a été
effectuée par l’utilisateur, qui a autorisé la publication sur main le 5 octobre.
Cette publication concerne uniquement le football ; les travaux hockey sont
conservés sur leur branche.

La migration `20261004230000_premium_live_statistics.sql` a été appliquée au
projet Supabase existant `ednvvxxvlawaagjyshkj`. `sync-live-matches` a été
déployé depuis le checkout football avec son authentification serveur existante.
Le cron déjà actif est conservé ; aucun cycle complet n’a été lancé.
Après déploiement, les trois derniers passages vérifiés sont réussis, sans erreur.
Neuf rencontres ont déjà des statistiques enregistrées. Une lecture anonyme
réelle de trois rencontres en cours renvoie bien scores, statistiques et leurs
timestamps séparés via `match_live_for_fixtures`.

## Structure commune

`LectorTemporalState` décrit phase, période, horloge factuelle et date de réception.
Les composants `LectorLiveBadge`, `LectorTemporalFeed`, `LectorMatchCard`,
`LectorMatchDetailView`, `LectorMatchStats` et `LectorPersonalizeInvitation` sont
identiques dans les deux checkouts. Les adaptateurs décident uniquement des
faits sportifs et de l’ordre des participants : domicile/gauche au football,
extérieur/gauche au hockey. Il n’y a pas de nouvel onglet principal Live.

- Pour moi : sélection existante de l’utilisateur, puis filtrage temporel.
- Tous : Live → À venir → Terminés, regroupements pays/championnat conservés.
  Les reports/annulations restent accessibles via Autres. Les filtres vides
  disparaissent. Si le dernier match Live se termine, le filtre revient à Tous.
- Visiteur : invitation à personnaliser Pour moi ; accès public à Tous, Radar
  et aux données sportives de la fiche.
- Radar : l’historique, les lectures et les rangs restent calculés avant match.
  Le badge ajoute le contexte du match sans modifier ces éléments.
- Fiche : Stats ouvre par défaut un match Live ; une sélection manuelle d’onglet
  reste respectée. Stats reste disponible au résultat final. Les onglets peuvent
  défiler horizontalement sur les petits écrans.

`LiveMatchListBuilder` suit tous les IDs de la journée sélectionnée, y compris
ceux masqués par le filtre Live. Ainsi un match qui démarre peut apparaître sans
rechargement. Il utilise le contrôleur existant : canal Realtime partagé,
lectures RPC groupées, reprise périodique et reprise après suspension.
Les états finaux ne régressent pas vers un ancien état Live.

## Données et coût API

Le collecteur football existant utilise `fixtures?live=...` et un lot
`fixtures?ids=...` limité à 20 IDs. Ce second appel renvoie déjà des statistiques.
La présente évolution les conserve ; elle n’ajoute aucun appel au fournisseur.
Les contraintes de budget et les réservations partagées restent en place.
Voir la documentation officielle :
https://www.api-football.com/news/post/how-to-get-all-fixtures-data-from-one-league

La migration `20261004230000_premium_live_statistics.sql` ajoute deux colonnes
optionnelles à `match_live_states`, conserve les statistiques reçues lors d’un
score sans statistiques et étend la lecture publique existante. Le timestamp
statistique est séparé du timestamp du score. La rotation du lot de 20 signifie
que les statistiques de chaque match ne sont pas nécessairement renouvelées
chaque minute. Le panneau avertit lorsque les statistiques Live sont anciennes.
Il affiche les valeurs zéro reçues et conserve les valeurs absentes comme
absentes. Aucun remplacement par des moyennes de saison.

Hockey : même interface temporelle, périodes et éventuelle horloge transmises par
la publication. Scores par période dans Stats lorsque présents. La collecte
hockey actuelle reste une publication locale, sans collecteur Live récurrent
activé. Les anciens états Live portent un avertissement de fraîcheur ; cette
itération ne prétend pas activer un Live hockey toutes les minutes.

## Vérifications

- Contrôles avant publication : formatage sans modification, analyse Flutter
  sans problème, suite Flutter complète (611 tests réussis, 2 ignorés),
  27 tests Deno partagés et 2 tests SQL réussis avec les permissions de CI.
- Comparaison avant migration : les deux fonctions SQL distantes correspondaient
  exactement à la migration de collecte Live déjà versionnée dans le dépôt.
- Exécution complète des suites Flutter dans les deux checkouts : seules les
  attentes de l’ancien parcours invité et de l’ancien libellé Live ont échoué,
  ainsi que l’initialisation d’un test de page dans le checkout football.
  Ces points sont corrigés et les fichiers concernés ont été réexécutés.
- 90 tests ciblés réussis dans chacun des deux checkouts (accueil, cartes,
  sélection temporelle, lecture snapshot et parcours application).
- 64 tests application/accueil football après extraction de l’invitation commune.
- 39 tests multisport : composants, authentification, navigation, Live et thèmes.
  Une attente ambiguë du bouton de connexion a été limitée à la feuille de compte.
- 23 tests du design system réussis côté football ; analyse Flutter propre.
- 17 tests backend réussis, dont le SQL de publication/lecture publique et les
  collectes hockey. Test SQL exécuté aussi avec les permissions minimales de CI
  (`--allow-read`, sans accès environnement), réussi.
- Test de lecture hockey de P2 · 12:34 et de Pause sans horloge inventée.
- Contrôle réel dans Chrome intégré, viewport 390 × 844 : filtre Live,
  pays/championnat, accent de carte, score, ouverture Stats et accès visiteur.
  Une progression réelle de la minute a été observée sans rechargement.
  Avant déploiement SQL les statistiques distantes restent absentes : le panneau
  l’indique explicitement au lieu de remplir des valeurs fictives.

Captures locales dans le checkout multisport :
`output/live/football-live-mobile.png` et `output/live/football-stats-mobile.png`.

## Publication après validation locale

1. Publier uniquement les changements football de cette itération sur main.
   Ne pas fusionner les travaux hockey pour cette publication.
2. Appliquer la migration additive de statistiques au projet Supabase existant.
   Les privilèges et l’authentification des RPC existantes restent inchangés.
3. Déployer `sync-live-matches` avec sa dépendance `_shared/live_matches.ts`,
   selon le mécanisme d’authentification serveur existant.
4. Laisser le cron déjà activé collecter ; aucun cycle complet nécessaire.
5. Vérifier un passage sain, le timestamp et les statistiques via la RPC publique,
   puis la fiche publique. La couverture statistique dépend du fournisseur.
6. Conserver ces composants identiques dans la branche multisport.

Les colonnes ajoutées sont optionnelles : l’ancienne version du frontend continue
à lire les scores. Pour revenir au rendu antérieur, republier le frontend précédent ;
ne pas supprimer les données ni reconstruire les snapshots de calendrier.

## Relancer localement avec les données

Multisport (quitter d’abord l’ancien Flutter avec `q` si 8191 est occupé) :

```sh
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
SPORT_PREVIEW_PORT=8110 bash tool/run_multisport_local.sh 8191 release
```

Le script charge la configuration publique Supabase et la publication hockey.
Aucune clé serveur/API fournisseur n’est incluse dans l’application web.
