# Contrat D'Implementation Flutter

Codex implemente uniquement apres validation explicite d'une direction visuelle.

## Pre-Requis

Avant de coder, il faut :

- maquette Penpot, capture ou asset valide explicitement ;
- ecran ou parcours cible identifie ;
- composants Flutter concernes ;
- liste des changements autorises ;
- liste des fichiers a ne pas toucher ;
- branche dediee, sauf decision explicite de travailler sur `main`.

## Branche

Nom recommande pour les chantiers isoles :

```sh
redesign/<nom-du-parcours-ou-ecran>
```

Exemples :

```text
redesign/auth-flow
redesign/ticket-generator
redesign/match-detail
redesign/home-experience
```

## Zones Autorisees Par Defaut

```text
lib/features/**/presentation/
lib/app/view/
lib/core/theme/
lib/app/theme/
docs/
test/**/presentation/
```

## Zones Protegees Par Defaut

```text
lib/features/**/domain/
lib/features/**/data/
lib/core/services/
supabase/
tool/
```

Toute modification d'une zone protegee doit etre annoncee et justifiee avant implementation.

Sur `main`, priorite absolue :

- conserver la logique fonctionnelle existante ;
- integrer les ajouts esthetiques valides ;
- demander arbitrage utilisateur en cas de conflit entre logique main et refonte visuelle.

## Regles

- Ne pas coder depuis une image ImageGen brute non validee.
- Ne pas ajouter de couleur locale.
- Ne pas disperser de logique dark/light dans les widgets.
- Ne pas modifier les contrats metier.
- Ne pas modifier le moteur d'analyse.
- Ne pas modifier la strategie API-Football.
- Ne pas modifier Supabase ou les migrations.
- Preferer les composants et tokens existants.
- Creer une abstraction seulement si elle retire une complexite reelle.

## Verification Avant Commit

```sh
dart format --set-exit-if-changed .
flutter analyze
flutter test
```

Selon le chantier :

```sh
flutter build web --no-wasm-dry-run
```
