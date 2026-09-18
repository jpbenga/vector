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

Les migrations, Edge Functions et le front font partie du même changement :

- `20260918110000_server_computed_match_feed.sql` crée le read model compact ;
- `20260918113000_bilan_reading_outcomes_and_nuances.sql` étend les verdicts ;
- `analyze-match-feed-snapshot` matérialise le flux mobile ;
- `daily-football-sync` déclenche la chaîne complète.

Le fonctionnement quotidien ne dépend d’aucun lancement GitHub manuel, secret
GitHub ou intervention dans le dashboard. Les secrets restent uniquement dans
Supabase Edge Functions.
