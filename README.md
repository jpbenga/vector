# Vector Copilot

Application Flutter mobile-first destinée à devenir un copilote de décision
football.

Le front local permet aujourd'hui de valider le MVP avant backend : onboarding
V3, lectures simples, lectures combinées, opportunités personnalisées, tickets,
historique local et variantes de thème. Le moteur reste déterministe et
explicable : l'application n'affiche pas de probabilité, de promesse de gain ou
de score prédictif.

## Stack

- Flutter / Dart
- Supabase
- PostgreSQL via Supabase
- Supabase Auth
- Internationalisation français / anglais

## Prérequis

- Flutter installé
- Xcode pour iOS
- Android Studio ou le SDK Android pour Android

## Lancer l'application

```sh
flutter pub get
flutter run \
  --dart-define=APP_ENV=development \
  --dart-define=SUPABASE_URL=https://example.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=replace-me
```

En développement, Supabase peut être omis :

```sh
flutter run --dart-define=APP_ENV=development
```

Pour tester dans un navigateur :

```sh
flutter run -d chrome --dart-define=APP_ENV=development
```

## Vérifications

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build web --no-wasm-dry-run
```

## Staging web

Le prototype partageable aux testeurs proches est deploye comme application web
statique.

```sh
set -a
source .env
set +a

bash tool/build_web_staging.sh
```

Voir [Workflow Web Staging avec Vercel](docs/web-preview-workflow.md) et
[Guide testeur](docs/testers/tester-guide.md).

## Preview mobile locale

Pour tester l'application locale depuis un telephone sur le meme Wi-Fi :

```sh
bash tool/mobile_preview.sh
```

Le script affiche une URL locale, la copie dans le presse-papiers et ouvre un QR
code scannable. Voir [Preview mobile locale](docs/mobile-local-preview.md).

## Documentation

- [Architecture](docs/architecture.md)
- [Preview mobile locale](docs/mobile-local-preview.md)
- [Workflow IA Design ImageGen, Penpot et Codex](docs/ai-design-workflow/README.md)
- [Workflow Web Staging avec Vercel](docs/web-preview-workflow.md)
- [Guide testeur](docs/testers/tester-guide.md)
- [Backend Lot 1A — Schema Supabase](docs/backend-lot-1a-schema.md)
- [Backend Lot 1B — Repositories distants](docs/backend-lot-1b-repositories.md)
- [Backend Lot 2 — API-Football serveur](docs/backend-lot-2-api-football-server.md)
- [Backend Lot 3A — Contrat snapshot](docs/backend-lot-3a-snapshot-contract.md)
- [Backend Lot 3B — Construction snapshot](docs/backend-lot-3b-snapshot-builder.md)
- [Backend Lot 4 — Branchement front snapshot](docs/backend-lot-4-front-snapshot-bridge.md)
- [Backend Lot 5 — Cycle de vie tickets](docs/backend-lot-5-ticket-lifecycle.md)
- [Backend Daily Football Sync MVP](docs/backend-daily-football-sync.md)
- [Opportunity Architecture](docs/opportunity-architecture.md)
- [Ticket Generator](docs/ticket-generator.md)
- [Plan d'action API-Football, moteur et générateur de ticket](docs/plan-action-api-football-moteur-ticket-builder.md)
- [Decision Profile V2 et Ticket Strategy V1](docs/decision-profile-v2-ticket-strategy-v1.md)
- [Architecture moteur, Decision Profile & Profile Compiler](docs/Architecture_Moteur_Decision_Profile_Profile_Compiler.md)
- [Audit moteur actuel et onboarding](docs/audit-moteur-onboarding.md)
- [Charte fondatrice](Charte_fondatrice_du_produit_v3.md)
- [Principes non négociables](Principes_non_negociables_v2.md)
