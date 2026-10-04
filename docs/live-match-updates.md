# Scores chaque minute et bilan des lectures

## État de cette livraison

La version comprend la collecte des scores chaque minute, le bilan des lectures sur les cartes et la correction du chargement après minuit. Le 4 octobre 2026, le SQL et les trois fonctions ont été installés sur le projet Supabase utilisé par l’application, puis la collecte activée : trois premiers passages ont été confirmés réussis, sans erreur, avec deux appels fournisseur chacun. Les étapes ci-dessous restent le guide d’installation pour un autre environnement ; ne pas réexécuter les migrations déjà installées.

Sur un nouveau projet, la migration installe le cron mais laisse la collecte **désactivée** jusqu’à sa configuration et son activation. Aucun cycle complet quotidien n’est nécessaire pour activer les scores si les calendriers sont déjà publiés. Le frontend doit aussi être publié pour rendre les scores et verdicts visibles aux utilisateurs.

## Vérifier l’écran en local

```sh
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
bash tool/run_web_with_env.sh 8099 release
```

Cette commande lit la configuration Supabase du `.env` existant, comme la production. Dans **Mon espace → Apparence → Live & bilan**, choisir **Avant-match**, **En direct**, puis **Terminé**. Cliquer sur **Voir les lectures** pour ouvrir le bilan : lecture annoncée, équipe concernée, critère, score et verdict. Cet aperçu utilise les vrais composants et les thèmes de l’application. Ses scores sont explicitement fictifs ; ils ne sont jamais envoyés au serveur et ne remplacent pas le flux réel.

Sur les rencontres réelles, les scores et verdicts nouveaux apparaîtront après installation du backend. Les résultats finals déjà enregistrés sont aussi lisibles par la nouvelle commande publique. Les cartes « Pour moi », « Radar » et « Tous », ainsi que le détail de rencontre, utilisent la même collecte. Le profil courant filtre les lectures et scénarios visibles. Le live ne sélectionne aucune compétition à la place de l’utilisateur et ne recalcule pas ses lectures avec les informations de fin de match.

## Installation Supabase

### Validité du calendrier au passage à minuit

Le calendrier ne doit pas disparaître à minuit simplement parce que sa dernière publication date de la veille. Le front accepte maintenant un snapshot couvrant la date demandée et collecté depuis au plus **36 heures** (24 heures entre batchs quotidiens, plus 12 heures de marge). Une fenêtre expirée ou une publication plus ancienne reste refusée ; aucun snapshot local supprimé n’est réintroduit.

Les tests couvrent le passage à minuit, la limite exacte de 36 heures et le chemin complet lecture du snapshot → adaptation des rencontres → carte affichée dans « Tous ». Cette correction est dans le frontend ; elle ne nécessite ni SQL supplémentaire ni relance d’un cycle.

### 1. SQL Editor

Copier **uniquement cette nouvelle migration**, puis la coller et l’exécuter une fois dans SQL Editor du projet utilisé par l’application :

```sh
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
pbcopy < supabase/migrations/20261004100000_live_match_collection.sql
```

Si les migrations sont toutes gérées par la CLI, employer le parcours habituel `npx supabase db push --dry-run`, vérifier la liste, puis `npx supabase db push`. Ne pas mélanger application manuelle et CLI sans réconcilier l’historique des migrations.

Cette migration crée :

- `match_live_states` : dernier statut, minute, scores reçus et bilan du résultat final ; lecture publique, écritures serveur.
- `match_live_configuration` et `match_live_runs` : activation, verrou temporaire, dernière réussite et erreurs ; accès serveur uniquement.
- Les commandes de collecte et une lecture publique bornée à 500 identifiants par appel.
- Le cron `lector-live-matches`, chaque minute, initialement inactif grâce à la configuration.
- L’inscription des scores à Supabase Realtime et la mise à jour du bilan après insertion d’un résultat immutable.
- La protection des lectures de joueurs : des événements absents ne prouvent plus qu’un joueur n’a pas été décisif.

Les calendriers bruts, snapshots compactés et commandes de lecture publique existants restent le socle du flux. Le collecteur de scores n’écrit dans aucune de ces tables de snapshot.

### 2. Déployer les fonctions

Depuis ce dépôt déjà lié au bon projet Supabase :

```sh
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
npx supabase functions deploy sync-live-matches --no-verify-jwt
npx supabase functions deploy sync-match-results --no-verify-jwt
npx supabase functions deploy admin-ops --no-verify-jwt
```

La première assure la nouvelle collecte ; la deuxième applique la même protection des données de joueurs aux résultats récupérés par les batchs quotidiens ; la troisième expose la supervision et l’interrupteur du live dans **Admin → API & données**. Il faut que les **trois commandes réussissent** avant activation.

Les secrets existants sont utilisés : `API_FOOTBALL_KEY`, `API_FOOTBALL_SYNC_SECRET`, `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`. Aucune clé fournisseur ni clé de service n’est transmise au navigateur. `--no-verify-jwt` conserve l’authentification propre aux fonctions existantes : secret serveur pour les collecteurs, session et autorisation administrateur pour `admin-ops`.

### 3. Activer après vérification

La migration crée les tables, mais ne peut pas connaître le secret des fonctions déployées. Si la configuration `ops_configuration` n’a pas encore été initialisée, la simple activation renvoie `Configure operations before enabling live collection`.

Pour initialiser les appels serveur et activer le live à partir du `.env` existant, sans saisir le secret manuellement :

```sh
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
dart tool/generate_live_setup_sql.dart --copy
```

Coller ensuite dans SQL Editor du **même projet Supabase que celui du `.env`**, puis exécuter. Ce SQL contient le secret serveur : le garder privé. Il conserve `scheduling_enabled` s’il existe déjà ; sinon il initialise uniquement les appels serveur avec la programmation quotidienne désactivée. Il active le live et demande un premier passage, sans relancer un cycle complet ni modifier les crons quotidiens. Le secret local doit correspondre au `API_FOOTBALL_SYNC_SECRET` des fonctions déployées.

Si cette configuration existe déjà et est correcte, l’activation simple suffit.

Dans SQL Editor :

```sql
select public.match_live_set_enabled(true);
select public.match_live_tick();
```

Les appels utilisent les compétitions activées dans le poste de pilotage (`ops_competitions.enabled`). La configuration serveur du poste de pilotage doit déjà exister (`ops_configuration`) : l’activation est refusée si l’URL ou le secret serveur manquent. Après publication du nouveau frontend, l’interrupteur **Admin → API & données → Scores en direct** permet aussi d’activer ou d’arrêter la collecte.

Pour arrêter immédiatement et révoquer le collecteur éventuellement en cours :

```sql
select public.match_live_set_enabled(false);
```

Le prochain passage d’un worker révoqué ne peut plus réserver d’appel ni publier ses données.

### 4. Voir l’état

L’admin montre la dernière collecte entièrement réussie, les matchs actuellement connus comme en cours, les appels du dernier passage, le cumul depuis installation et les cinq derniers passages. Les erreurs API ou les collectes différées y restent visibles.

```sql
select enabled, last_started_at, last_completed_at, last_success_at,
       last_error, requests_last_run, requests_total
from public.match_live_configuration;

select started_at, finished_at, status, provider_requests, fixture_count, error_message
from public.match_live_runs
order by started_at desc
limit 20;

select c.name as competition, l.home_team_name, l.away_team_name,
       l.status, l.elapsed, l.home_goals, l.away_goals, l.captured_at,
       l.result_snapshot_id
from public.match_live_states l
join public.ops_competitions c on c.league_id=l.league_id
where l.fixture_date=(now() at time zone 'Europe/Paris')::date
order by l.kickoff_at, c.name;
```

Ne pas considérer un lancement HTTP comme une réussite : la réussite est enregistrée après publication SQL. En cas de perte complète du worker, son verrou expire et le passage suivant peut reprendre. Le journal conserve 14 jours de passages, le cache de scores 30 jours. Les résultats et évaluations historiques restent dans les tables immutables du Bilan.

## Nombre de requêtes et reprise

- **Un appel groupé par minute** à `/fixtures?live=<compétitions activées>` ; aucun appel API-Football par spectateur ou par carte.
- **Au plus un appel supplémentaire par minute** à `/fixtures?ids=<20 matchs au maximum>` pour vérifier les matchs démarrés, terminés ou disparus du flux live et récupérer leurs détails disponibles. Les matchs restants sont repris aux passages suivants.
- La réponse détaillée peut contenir événements et statistiques ; le fournisseur peut ne pas couvrir ces données pour une compétition. Les lectures de score sont évaluées lorsqu’elles le permettent ; les autres restent non évaluables.
- Les contrôles après résultat sont espacés à 5 minutes, 30 minutes, 6 heures puis 24 heures, avec rattrapage sur les 7 derniers jours. Les rencontres reportées ou encore annoncées sans démarrage sont revérifiées toutes les 15 minutes. Les identifiants omis dans une réponse réussie sont remis en attente et tournent dans la file.
- **Plafond théorique : 2 880 appels/jour**, soit **3,84 % de 75 000** pour ce nouveau collecteur fonctionnant 24 h/24. Le seul flux live représente 1 440 appels/jour (1,92 %). Il faut ajouter les batchs quotidiens déjà existants. Les réservations refusées ne font pas d’appel fournisseur.
- Les deux types d’appels réservent leur place dans le **même compteur global** : 75 000/jour UTC, 280 requêtes sur 60 secondes glissantes. Il n’existe aucun budget séparé permettant de dépasser cette limite.
- Un quota saturé diffère la collecte ; les derniers scores valides sont conservés. Un échec des détails finals n’empêche pas de publier les scores live récupérés correctement pendant ce passage.
- Une absence du flux live ne vaut jamais statut FT. Un final sans scores complets ne produit pas d’évaluation inventée. Les prolongations et tirs au but gardent la règle existante « non évaluable » pour les lectures fondées sur le résultat à 90 minutes.

Le navigateur lit Supabase à l’ouverture, après reconnexion/retour au premier plan et une fois par minute en sécurité. Une connexion Realtime partagée pousse les changements des seules cartes ouvertes ; aucun abonnement global à tous les matchs n’est créé. Les appels frontend à Supabase ne consomment pas le quota API-Football. Leur coût dépend du nombre de visiteurs, des connexions et des messages Realtime ; il ne faut pas le confondre avec les 2 880 appels fournisseur au maximum.

La cadence vise une collecte par minute, elle ne garantit pas une latence exacte de 60 secondes : disponibilité fournisseur, quota partagé, reprise d’une file et interruptions réseau peuvent la rallonger. Le live affiche l’heure de réception ; après trois minutes sans nouvelle réception sur une rencontre en cours, il indique un retard. Les lectures restent en attente jusqu’au résultat final, même si un score provisoire semble déjà les confirmer.

Documentation fournisseur : [appels détaillés par groupes de 20](https://www.api-football.com/news/post/how-to-get-all-fixtures-data-from-one-league), [statuts et collecte live](https://www.api-football.com/news/post/how-to-get-started-with-api-football-the-complete-beginners-guide). Pour Supabase : [Cron](https://supabase.com/docs/guides/cron), [comptage des messages Realtime](https://supabase.com/docs/guides/platform/manage-your-usage/realtime-messages).

## Vérifications automatisées

Le test SQL exécute les vraies fonctions de la migration dans PostgreSQL embarqué (PGlite), avec les schémas prérequis réduits. Il vérifie :

- Installation désactivée, exclusion mutuelle, révocation d’un ancien worker.
- Lecture publique des scores en cours et absence de score fictif 0–0.
- Persistance du dernier score après disparition du flux live.
- Résultat final → évaluations du Bilan → lecture publique destinée aux cartes.
- Score corrigé, idempotence et correction revenant à un score déjà observé.
- Joueur sans événements non évaluable ; absence de droit de contrôle pour le navigateur.
- Lecture d’un résultat historique même après disparition du cache live.

Les tests Deno vérifient l’adaptation API, les appels groupés, le quota partagé refusé, les réponses invalides et la conservation des scores lors d’un échec des détails finals. Les tests Flutter vérifient la réception/reprise, l’absence de régression d’un final, la conservation des lectures avant match, le filtrage du profil et le rendu des cartes dans les dix thèmes. Les tests SQL sont inclus dans la CI avec ceux du Bilan existant.

Ils ne remplacent pas la vérification après installation sur le vrai projet Supabase : cron HTTP, secret déployé et livraison Realtime dépendent de ce déploiement. Le test de contrat du snapshot brut → compacté → lecture publique continue de protéger le chemin de chargement initial.
