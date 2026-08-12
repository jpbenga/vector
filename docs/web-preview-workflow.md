# Workflow Web Staging avec Vercel

Ce workflow sert a partager Lector Sport a des testeurs proches sans passer par
les stores.

Objectif :

```text
Developpement -> GitHub -> Vercel -> URL publique -> QR code -> testeurs
```

## Principe

L'application Flutter est compilee en web statique :

```text
flutter build web -> build/web
```

Vercel sert ensuite le dossier `build/web`.

Cette cible est un environnement de test produit, pas une publication store.
Elle permet de valider le concept sur iPhone, Android et desktop avec un simple
lien.

## Environnement

Vercel doit recevoir ces variables d'environnement :

```text
SUPABASE_URL
SUPABASE_ANON_KEY
APP_PUBLIC_URL=https://lector-sports.vercel.app/
MATCH_FEED_SOURCE=auto
```

`APP_PUBLIC_URL` est obligatoire pour l'authentification OAuth en web.
Sans cette variable au moment du build, Supabase peut rediriger vers l'URL
courante du navigateur, par exemple `localhost`, au lieu de revenir vers le
déploiement Vercel.

Le script de build force :

```text
APP_ENV=staging
```

Aucun secret prive ne doit etre ajoute a Vercel pour le front.
Ne jamais exposer :

```text
SUPABASE_SERVICE_ROLE_KEY
API_FOOTBALL_KEY
API_FOOTBALL_SYNC_SECRET
```

## Fichiers

```text
vercel.json
tool/build_web_staging.sh
web/index.html
web/manifest.json
```

## Test local du build web

Depuis la racine du projet :

```sh
set -a
source .env
set +a

bash tool/build_web_staging.sh
```

Le build doit produire :

```text
build/web
```

## Creer le projet Vercel

1. Aller sur `https://vercel.com`.
2. Se connecter avec GitHub.
3. Cliquer sur `Add New...` puis `Project`.
4. Importer le repository GitHub de Lector.
5. Framework Preset : `Other`.
6. Build Command : laisser Vercel lire `vercel.json`.
7. Output Directory : laisser Vercel lire `vercel.json`.
8. Ajouter les variables d'environnement :
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `APP_PUBLIC_URL` avec l'URL publique Vercel, par exemple
     `https://lector-sports.vercel.app/`
   - `MATCH_FEED_SOURCE` avec la valeur `auto`
9. Lancer le premier deploy.

Si `APP_PUBLIC_URL` manque, le build doit échouer. C'est volontaire : une build
web sans URL publique ne peut pas garantir un callback OAuth correct.

## Configurer Supabase Auth

Une fois l'URL Vercel obtenue, aller dans Supabase :

```text
Authentication -> URL Configuration
```

Ajouter dans Redirect URLs :

```text
https://<project-vercel>.vercel.app/**
```

Pour l'URL stable actuelle :

```text
https://lector-sports.vercel.app/**
```

Si un domaine custom est ajoute plus tard :

```text
https://staging.lector-sport.com/**
```

Verifier aussi que le provider Google reste active.

## Partager aux testeurs

Une fois le deploy valide :

1. ouvrir l'URL Vercel sur mobile ;
2. verifier le lancement ;
3. verifier la connexion Google ;
4. verifier l'onboarding ou le mode invite ;
5. generer un QR code depuis l'URL.

Le QR code peut pointer vers l'URL stable Vercel ou vers un domaine custom.

## Nouvelle version

Workflow simple :

```text
branche de travail -> Pull Request -> merge main -> deploy Vercel
```

Vercel cree aussi des previews pour les branches/PR. Ces previews servent a
valider une iteration avant de la partager plus largement.

## Limites

- Ce n'est pas une app native iOS ou Android.
- Les performances et comportements peuvent differer d'une future app store.
- Les deep links natifs iOS/Android ne sont pas testes ici.
- TestFlight et Play Console restent une future etape.

## Checklist avant partage

- [ ] `flutter analyze`
- [ ] `flutter test`
- [ ] `bash tool/build_web_staging.sh`
- [ ] Variables Vercel presentes
- [ ] Redirect URL Vercel ajoutee dans Supabase
- [ ] Connexion Google testee sur l'URL Vercel
- [ ] Snapshot Supabase charge ou fallback local clairement visible
- [ ] QR code genere depuis l'URL stable
