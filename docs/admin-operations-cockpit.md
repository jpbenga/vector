# Cockpit admin operations

Le cockpit admin fournit une premiere interface d'exploitation pour le pipeline
API-Football.

## Environnements

Le scope actuel reste volontairement limite a :

- `staging`
- `production`

`development` reste reserve au local. Les environnements `qa` et `demo` ne sont
pas modelises pour le moment.

## Acces

L'interface est disponible a :

```text
/admin
```

Exemples :

```text
https://lector-sports.vercel.app/admin
http://192.168.x.x:8099/admin
```

Elle est accessible depuis n'importe quelle IP. La securite repose sur :

- Supabase Auth ;
- une liste d'emails admin dans le secret Edge Function `ADMIN_EMAILS` ;
- une Edge Function service-role `admin-ops`.

Le front ne recoit jamais la service role et ne lit jamais directement
`cron.job.command`.

## Secrets requis

Pour chaque projet Supabase concerne :

```sh
supabase secrets set ADMIN_EMAILS="admin@example.com"
supabase secrets set LECTOR_ENV="staging"
```

La fonction utilise aussi les secrets deja requis par le pipeline :

```sh
SUPABASE_URL
SUPABASE_SERVICE_ROLE_KEY
API_FOOTBALL_SYNC_SECRET
```

## Deploiement

Depuis la racine du projet :

```sh
npx supabase db push
npx supabase functions deploy admin-ops --no-verify-jwt
```

`--no-verify-jwt` est volontaire : la fonction verifie elle-meme le JWT de
l'utilisateur pour pouvoir renvoyer des erreurs admin explicites.

## Capacites MVP

- voir les jobs cron API-Football planifies ;
- voir la prochaine execution locale calculee depuis le cron quotidien ;
- isoler les jobs cron en cours et les executions recentes en erreur ;
- lire le message de retour des executions cron en erreur ;
- voir les dernieres executions cron ;
- voir la sante sync/snapshot par ligue ;
- voir les dernieres relances admin ;
- relancer manuellement une ligue, avec reconstruction du snapshot.
- afficher et copier le lien release courant ;
- afficher un QR code scannable pour le lien release courant ;
- generer un lien testeur temporaire valable 1h, copie automatiquement ;
- afficher un QR code scannable pour le lien testeur temporaire.

Les liens testeurs sont stockes dans `admin_preview_links` sous forme de hash
SHA-256. Le token en clair n'est renvoye qu'une seule fois, au moment de la
generation du lien.

## Relance manuelle

Le bouton de relance par ligue appelle :

```text
admin-ops -> api-football-sync -> build-match-feed-snapshot
```

La fenetre de collecte couvre J-2 a J+3. Le snapshot couvre J a J+3.

Toutes les relances sont loggees dans `admin_operation_runs`.

## Liens testeurs temporaires

Le bouton `Lien testeur 1h` appelle `admin-ops` avec l'action
`create_test_link`. La fonction :

- verifie que l'utilisateur est un admin allow-list ;
- cree un token aleatoire ;
- stocke uniquement `token_hash` ;
- renvoie une URL du type `https://.../?tester_token=...`.

Quand un testeur ouvre ce lien, l'app appelle `admin-ops` avec l'action
`redeem_test_link`. Cette action ne demande pas de bearer admin, mais elle ne
permet que de valider un token deja cree, non expire et non revoque.
