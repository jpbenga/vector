# Guide testeur Lector Sport

Ce guide sert a partager le prototype web de Lector Sport avec des testeurs
proches, sans Flutter, Xcode, Android Studio ou acces au repository.

## Acces

URL stable :

```text
https://lector-sports.vercel.app/
```

QR code :

![QR code Lector Sport](lector-sports-qr.svg)

Le QR code pointe vers l'URL stable Vercel ci-dessus.

## Ce que le testeur doit faire

1. Ouvrir le lien ou scanner le QR code depuis un telephone.
2. Choisir `Commencer`.
3. Se connecter avec Google ou continuer sans compte.
4. Completer l'onboarding si demande.
5. Tester les ecrans principaux :
   - `Pour moi`
   - `Generateur`
   - `Toutes les rencontres`
   - detail rencontre
   - `Mon ticket`
   - historique
6. Noter les problemes rencontres avec une capture d'ecran si possible.

## Connexion

Google est actif.

Apple est affiche comme `Bientot` et ne doit pas etre teste pour le moment.

Si le projet Google OAuth est encore en mode test, chaque testeur Google doit
etre ajoute dans Google Cloud comme utilisateur de test, sinon la connexion peut
etre bloquee par Google avant le retour dans Lector.

## Donnees et synchronisation

La connexion sert principalement a retrouver sur plusieurs appareils :

- profil ;
- strategies ;
- favoris ;
- tickets ;
- historique local synchronise.

Le mode invite reste possible. Il ne doit pas bloquer l'utilisation du
prototype, mais les donnees peuvent rester limitees a l'appareil utilise.

## Installation sur mobile

Lector Sport est une web app installable.

Sur iPhone :

1. ouvrir l'URL dans Safari ;
2. toucher le bouton de partage ;
3. choisir `Sur l'ecran d'accueil`.

Sur Android :

1. ouvrir l'URL dans Chrome ;
2. ouvrir le menu ;
3. choisir `Installer l'application` ou `Ajouter a l'ecran d'accueil`.

## Feedback attendu

Demander au testeur de repondre simplement a ces questions :

- Avez-vous compris ce que Lector essaie de faire ?
- L'onboarding est-il clair ?
- Les lectures et lectures combinees sont-elles comprehensibles ?
- Le generateur de tickets vous semble-t-il utile ?
- Avez-vous confiance dans les explications affichees ?
- Ou avez-vous bloque ?
- Quel ecran faudrait-il simplifier en priorite ?

## Limites connues

- Ce prototype est une version web de test, pas une app native App Store ou Play
  Store.
- Les performances peuvent varier selon l'appareil et le navigateur.
- Apple Sign-In n'est pas encore active.
- Les donnees sportives dependent du snapshot et des synchronisations backend
  disponibles.
- Certaines fonctionnalites IA restent preparees mais non activees.

## Regeneration du QR code

Si l'URL change, regenerer le QR code depuis la racine du projet :

```sh
curl -L "https://quickchart.io/qr?text=https%3A%2F%2Flector-sports.vercel.app%2F&size=640&margin=2&format=svg" \
  -o docs/testers/lector-sports-qr.svg
```

Puis verifier que le QR code ouvre bien l'URL attendue sur mobile.
