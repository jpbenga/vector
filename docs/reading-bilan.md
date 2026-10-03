# Bilan des lectures : architecture serveur

## Chaîne de données

```text
Supabase Cron
  -> daily-football-sync, une ligue à la fois
  -> api-football-sync (cache privé API-Football)
  -> sync-match-results (scores, mi-temps et détail final seulement pour les matchs annoncés)
  -> build-match-feed-snapshot (snapshot brut privé)
  -> publish-reading-announcements (annonces immuables du Bilan)
  -> analyze-match-feed-snapshot (flux mobile compact calculé)
  -> Flutter (lecture, tri et filtrage des données déjà calculées)
```

Le téléphone ne télécharge ni l’historique des équipes, ni les pages joueurs,
ni les statistiques brutes. Les lectures, scénarios, preuves et échantillons
sont calculés une fois dans Supabase puis stockés dans
`match_feed_analysis_snapshots`. Activer ou désactiver une lecture filtre ces
objets en mémoire ; cela ne relance pas l’analyse de football ni une requête
API-Football.

## Bilan

Chaque lecture et scénario est figé avant le coup d’envoi dans
`match_reading_announcements`. Les résultats finals sont archivés dans
`match_result_snapshots` et les triggers SQL écrivent un verdict immutable.

Les règles explicitement évaluables sont : total de buts, BTTS, victoire ou
non-défaite, victoire adverse, équipe qui marque, ne marque pas, garde sa cage
invulnérable ou encaisse, ainsi que les lectures de première et seconde
période. Les projections de tirs, corners et cartons restent descriptives tant
qu’un contrat de résultat avec une tolérance produit n’a pas été défini.

Une nuance est une annonce liée à une lecture parente. Elle devient « nuance
pertinente » lorsque la lecture parente échoue dans le sens signalé, et
« nuance non confirmée » lorsque la lecture parente réussit. Elle ne constitue
pas une prédiction autonome.

Les scénarios ont deux étapes distinctes : toutes leurs lectures requises
sont nécessaires avant match ; après match, seul le contrat du scénario est
jugé. Un 1-1 peut donc confirmer « Match fermé » même si un clean sheet de
soutien ne s’est pas produit.

## Contrats et déploiement

### Exploration du bilan

Le bilan conserve les fenêtres de 7, 30 et 90 jours, mesurées sur la date du
coup d’envoi jusqu’au moment du chargement. Il affiche chaque lecture annoncée
sur cette période, puis permet de croiser championnat et équipe concernée
(domicile, extérieur, match entier). La vue « Par championnat » rassemble les
lectures d’une compétition ; son ouverture applique ce filtre à la liste des
lectures. Les préférences du compte ne réduisent pas ce bilan public.

Le taux de confirmation est `confirmées / (confirmées + contredites)`.
L’agrégation additionne les comptes et recalcule ce taux ; elle ne moyenne pas
les pourcentages des championnats. Les annonces en attente, non évaluables et
sans contrat de résultat figurent séparément. Les scénarios et les nuances ne
font pas partie du dénominateur du bilan des lectures.

L’unité comptée est une **annonce de lecture**, pas un match distinct : plusieurs
lectures peuvent concerner la même rencontre, voire chacune des deux équipes.
Le critère conservé avant match est affiché dans le détail. Par exemple, le
contrat historique de « Dynamique positive » est une non-défaite : une victoire
ou un nul le confirme, une défaite le contredit. Cette refonte ne modifie pas
les contrats des annonces historiques. Les lectures descriptives sans contrat
de résultat restent visibles, sans taux inventé.

La migration `20261003180000_reading_bilan_exploration.sql` enrichit la vue
publique avec les noms et le championnat du snapshot d’origine, même lorsque
le résultat n’existe pas encore. Le score et le verdict proviennent du dernier
résultat archivé ; un résultat plus récent sans évaluation reste en attente,
sans emprunter le verdict d’un résultat précédent. Le détail est paginé par
dix annonces, avec les mêmes filtres que la synthèse.

La nouvelle RPC `match_reading_bilan_breakdown` agrège par lecture et
championnat côté serveur. Le client parcourt toutes les pages de cette RPC
pour éviter la limite de réponse de PostgREST. Il ne télécharge pas toutes les
annonces pour calculer le tableau. L’ancienne RPC reste disponible pour les
versions précédentes de l’application.

**Déployer la migration SQL avant le nouveau front.** Aucun cycle de collecte
n’est nécessaire : le bilan utilise les annonces et résultats déjà archivés.
Si le fournisseur n’a pas encore livré de résultat, le détail indique son
absence ; si aucun nom n’a été archivé, il utilise un libellé d’équipe générique.

Vérifications :

```sh
deno test --node-modules-dir=none --no-lock --allow-read test/backend/reading_bilan_sql_test.ts
flutter test test/features/matches/presentation/reading_bilan_section_test.dart test/features/matches/data/match_reading_bilan_repository_test.dart
```

Le test SQL exécute la migration réelle sur PostgreSQL en mémoire, remplace
la vue précédente et vérifie l’accès anonyme, les noms avant résultat, les
regroupements, les filtres et la correction d’un score. Les tests Flutter
vérifient les calculs pondérés, les filtres croisés et la pagination du détail
dans les deux thèmes. Ces tests font partie de la CI.

Les migrations, Edge Functions et le front font partie du même changement :

- `20260918110000_server_computed_match_feed.sql` crée le read model compact ;
- `20260918113000_bilan_reading_outcomes_and_nuances.sql` étend les verdicts ;
- `analyze-match-feed-snapshot` matérialise le flux mobile ;
- `daily-football-sync` déclenche la chaîne complète.

Le fonctionnement quotidien ne dépend d’aucun lancement GitHub manuel, secret
GitHub ou intervention dans le dashboard. Les secrets restent uniquement dans
Supabase Edge Functions.
