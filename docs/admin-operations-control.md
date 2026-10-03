# Poste de pilotage des batchs — `/admin`

## Écran

- **Pilotage** : cycle sélectionné, liste de compétitions nommées, filtre d’état, recherche, progression, durée et commandes. Le batch actif est sélectionné automatiquement.
- **Graphe interactif** : collecte API → résultats → snapshot → publication. Cliquer une étape affiche les données attendues et le résumé réel de son exécution.
- **Données** : compteurs de collecte et de résultats, exemple factuel de match, champs présents/absents, provenance cache/fournisseur lorsqu’elle est disponible, détail JSON. Un match absent ou un score nul reste absent ; aucun exemple de démonstration n’est injecté dans l’application.
- **Historique** : une seule source à la fois (cycles, batchs lancés hors pilotage, commandes). Les exécutions sont séparées en listes « En erreur » et « Réussis », chacune paginée par 10 ; les batchs en cours, en attente ou interrompus restent distincts. La pagination porte sur les 50 derniers cycles, les 100 derniers batchs hors pilotage ou les 100 dernières commandes chargés ; les données plus anciennes restent conservées en base.
- **Planification** : activation quotidienne par compétition, horaires et dernière mise en file quotidienne, enrichissement hebdomadaire, lancement individuel et ajout d’une compétition vérifiée auprès d’API-Football.
- **API & données** : consommation du quota, erreurs, signification des données publiées.
- Actualisation toutes les **5 secondes**, suspendue lorsque l’application est en arrière-plan. La dernière réponse reste visible si la connexion échoue.
- Les accès testeurs et l’ancien diagnostic restent accessibles par l’icône de réglages.

La progression mesure **les étapes accomplies** (0/25/50/75/100 %), pas une estimation du temps restant. Le cycle compte les échecs et interruptions comme traités, avec un compteur de réussites distinct. Les compteurs de données évoluent à l’intérieur des phases de collecte/résultats. La moyenne sur 48 h repose uniquement sur les batchs pilotés réussis ; elle inclut les pauses éventuelles.

## Commandes

| Action | Effet |
| --- | --- |
| Lancer un cycle | Crée un cycle pour toutes les compétitions quotidiennes activées |
| Lancer maintenant | Crée un batch quotidien pour la compétition choisie |
| Enrichir les joueurs | Crée le même pipeline avec collecte des statistiques joueurs activée |
| Mettre en pause | Laisse finir la phase active, bloque les phases suivantes de ce cycle |
| Reprendre | Remet le cycle dans la file |
| Interrompre | Annule l’attente et demande un arrêt coopératif du travail actif |
| Reprendre les échecs | Nouveau cycle pour les échecs et interruptions, en conservant le type de traitement |
| Désactiver un horaire | Empêche les prochaines mises en file ; n’annule pas celles déjà créées |

L’arrêt est coopératif : un appel déjà parti ou une écriture déjà engagée peut finir. Les phases vérifient le jeton avant les appels fournisseur et avant les principales publications. Les données enregistrées avant l’arrêt sont conservées.

Un seul batch piloté est actif à la fois. La fin d’une phase déclenche immédiatement la suivante ; la minute de cron sert à récupérer la file et à détecter les horaires dus, **elle n’impose pas d’espacement entre batchs**. Les nouvelles relances reprennent le pipeline complet ; les réponses API encore valides sont relues du cache.

## Mise en service Supabase

À faire dans le projet Supabase utilisé par le `.env` local. La mise en service distante n’a pas été exécutée par Codex.

### 1. Migration SQL

La base doit déjà contenir les migrations du projet jusqu’au catalogue des compétitions et au quota API-Football.

Pour utiliser l’éditeur SQL Supabase, copier **tout** le fichier :

```sh
cd /Users/chloe/vector/vector
pbcopy < supabase/migrations/20261001100000_operations_control.sql
```

Coller dans SQL Editor puis exécuter. Ne pas exécuter deux fois cette migration. Si le projet est géré entièrement par la CLI, utiliser à la place le parcours habituel `npx supabase db push --dry-run` puis `npx supabase db push` après contrôle des migrations proposées. Ne pas appliquer simultanément par SQL Editor et CLI sans réconcilier l’historique des migrations.

La première migration crée les tables privées, les commandes atomiques, deux vues de synthèse et le cron `lector-ops-dispatch`. La migration `20261001130000_ops_batch_resume.sql` met à jour la commande de fin pour permettre la reprise automatique des lots. Si le poste de pilotage est déjà installé, appliquer uniquement cette migration additive ; ne pas réexécuter `20261001100000_operations_control.sql`. Aucune de ces migrations ne lance un cycle. Les horaires quotidiens du nouveau pilotage sont initialement à **02:00 Europe/Paris** : les adapter dans Planification avant activation.

Pour l’éditeur SQL, copier la migration additive :

```sh
cd /Users/chloe/vector/vector
pbcopy < supabase/migrations/20261001130000_ops_batch_resume.sql
```

Pour une installation gérée par la CLI, vérifier puis appliquer les migrations en attente :

```sh
cd /Users/chloe/vector/vector
npx supabase db push --dry-run
npx supabase db push
```

### 2. Fonctions

Depuis le dépôt déjà lié au bon projet Supabase :

```sh
cd /Users/chloe/vector/vector
for fn in api-football-sync sync-match-results build-match-feed-snapshot publish-reading-announcements analyze-match-feed-snapshot ops-worker admin-ops daily-football-sync; do
  npx supabase functions deploy "$fn" --no-verify-jwt || break
done
```

Les secrets existants sont conservés : `API_FOOTBALL_SYNC_SECRET`, `API_FOOTBALL_KEY`, `ADMIN_EMAILS`, ainsi que les variables Supabase. `--no-verify-jwt` permet aux fonctions de vérifier elles-mêmes leur authentification : JWT utilisateur + liste d’administrateurs pour `admin-ops`, secret serveur pour les workers. Aucune clé de service n’est fournie au navigateur.

### 3. Application locale en release

```sh
cd /Users/chloe/vector/vector
bash tool/run_web_with_env.sh 8099 release
```

Ouvrir `http://localhost:8099/admin`, se connecter avec le compte administrateur.

L’écran fonctionne après migration et déploiement des fonctions. Avant cela, il affiche une erreur explicite de configuration ; les données ne sont pas simulées.

### 4. Transfert de la planification

Dans **Planification**, vérifier les compétitions et horaires puis activer **Planification quotidienne pilotée**. La confirmation explique que :

- les anciens crons `api-football-*` sont désactivés pour passer à la file persistante ;
- les anciennes requêtes déjà lancées ne sont pas interrompues ; attendre leur fin avant le transfert pour éviter tout chevauchement ;
- les horaires déjà passés aujourd’hui sont rattrapés ;
- suspendre le nouveau planificateur ne réactive pas automatiquement les anciens crons.

Les lancements manuels sont possibles sans activer le quotidien. Ils n’arrêtent pas les anciens crons : éviter la coexistence des deux modes de lancement. L’ancien bouton de relance passe également par la nouvelle file. Ne plus exécuter le générateur de crons après le transfert.

## Architecture et limites explicites

- Tables `ops_cycles`, `ops_tasks`, `ops_events`, `ops_competitions`, `ops_configuration` protégées par RLS et droits service uniquement ; commandes auditées avec l’administrateur.
- Jeton unique par phase, réservation atomique, refus des doubles mises en file d’une compétition, confirmation de réception unique.
- Une interruption du navigateur n’interrompt pas le batch ; PostgreSQL porte son état.
- Les workers défaillants expirent après 10 minutes et passent en erreur ; aucune relance automatique ambiguë après expiration.
- La collecte conserve un seul `api_football_sync_run_id` pendant toute sa reprise. Les enrichissements sont découpés en sous-batchs de 40 appels au maximum par passage ; une fois un lot terminé, le worker remet automatiquement le même batch en file avec le curseur suivant. Les passages suivants réutilisent le cache et continuent jusqu’au dernier lot. Cette limite protège le temps d’exécution et le rythme des appels par passage ; elle ne réduit pas le volume final demandé. Les limites d’exécution restent celles du fournisseur d’hébergement : [Supabase Edge Functions](https://supabase.com/docs/guides/functions/limits).
- Un flux vide est publiable lorsque la collecte couvre avec succès chaque journée de la période et que l’API ne renvoie aucun match. Une erreur de publication signifie que les données sont vides **et** que la couverture du calendrier n’est pas complète.
- Une erreur d’envoi du worker ne remet pas en cause une phase déjà terminée. Le cron retente l’envoi et le journal montre l’incident.
- API-Football est soumis à la réservation partagée de quota, y compris pour les résultats et la vérification d’une nouvelle compétition.
- Ajouter une compétition active sa collecte et sa publication par ce pipeline. Les écrans grand public dont le périmètre est fixé par le catalogue Dart ne sont pas automatiquement étendus par cet ajout.
- Les anciennes exécutions restent consultables mais ne possèdent pas rétroactivement les nouveaux compteurs ni le nouveau mécanisme d’arrêt.

## Vérifications locales

```sh
flutter analyze --no-pub
flutter test --no-pub test/features/admin/operations_page_test.dart
deno test --allow-env supabase/functions/_shared/ops_runtime_test.ts
```

Test PostgreSQL embarqué, avec transports HTTP et cron simulés :

```sh
npm install --prefix /tmp/lector-ops-tests @electric-sql/pglite
PGLITE_MODULE=/tmp/lector-ops-tests/node_modules/@electric-sql/pglite/dist/index.js \
  node test/backend/operations_control_test.mjs
```

Il vérifie la migration, les doubles lancements, les jetons périmés, pause/reprise, interruption, progression des quatre phases, récupération après expiration, quotas de planification, conservation des horaires hebdomadaires et absence d’accès client aux secrets/commandes.

L’aperçu `test/fixtures/operations_preview.dart` est une entrée de test séparée ; `lib/main.dart` ne l’importe pas.

## Explications des erreurs

Le catalogue partagé `lib/features/admin/domain/operations_issue.dart` fournit un titre, une explication et une action conseillée. Il est utilisé pour l’accès à l’administration, les commandes, les détails des batchs, l’historique et l’écran API. Les messages bruts restent copiables dans « Détail technique ».

| Message reçu | Explication affichée |
| --- | --- |
| `401 Invalid user token` | Session de connexion refusée ; proposer une reconnexion, sans déclarer les batchs en échec |
| `stale running window` | Fin du batch non confirmée dans le délai ; la cause de l’absence de confirmation reste inconnue |
| `No match-feed data could be published, and the fixture collection does not cover the full requested period` | Aucun match trouvé et collecte du calendrier incomplète ; vérifier les réponses source et relancer les jours manquants. Une compétition sans match sur toute la période peut maintenant publier un flux vide valide |
| `Missing api_football_sync_run_id for quota reservation` | Référence manquante entre collecte et résultats ; ne pas présenter cela comme un quota épuisé |
| `Enrichment scope exceeds one sync run` | Ancienne exécution arrêtée par une limite globale ; les nouveaux batchs poursuivent les appels par lots de 40 jusqu’à la fin |

Le catalogue couvre aussi les quotas quotidien et par minute, l’accès refusé entre services, les droits insuffisants, les doublons de lancement, les délais, les erreurs réseau et les erreurs serveur. Pour une erreur inconnue, l’écran dit explicitement que sa cause n’est pas identifiée.

Le nouveau mécanisme de reprise par lots utilise la migration de pilotage et les versions mises à jour de `api-football-sync`, `ops-worker`, `daily-football-sync` et `admin-ops`. Les anciennes lignes d’historique restent les comptes rendus de leur version d’origine ; les relancer avec ces versions applique le découpage automatique.
