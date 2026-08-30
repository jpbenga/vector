# Apparence Validee Lector Sport

Ce document capture les choix visuels et UX valides pendant la refonte Lector Sport.
Il sert de reference avant toute nouvelle generation d'image, tout ecran Flutter et toute revue mobile.

## Direction

Lector Sport doit rester aussi simple a parcourir qu'une app de scores, tout en rendant la lecture d'une rencontre plus claire.
La valeur differenciante n'est pas d'ajouter plus de bruit, mais de montrer les bons indices au bon moment.

Principes valides :

- acces a la valeur avant authentification ;
- parcours invite possible pour consulter les scores ;
- interface sombre, premium, dense et mobile-first ;
- badges de lecture visibles mais subtils : `Domination attendue`, `Match ouvert`, `Match a suivre` ;
- navigation contextuelle via le Quick Dock, sans supprimer les reperes de navigation essentiels ;
- aucune promesse de resultat ou de certitude.

## Arrivee Dans L'App

L'ecran d'arrivee valide doit presenter Lector Sport sans bloquer l'utilisateur.

Structure :

- fond stade premium en hauteur de tribunes, pas fond noir uni ;
- lockup Lector Sport en haut, avec logo transparent propre ;
- tagline `Read the Game.` ;
- promesse courte : `Les matchs du jour, avec une lecture plus claire.` ;
- CTA primaire : `Continuer sans compte` ;
- CTA secondaire : `Se connecter` ;
- reassurance : `Aucun compte requis pour voir les scores.` ;
- apercu compact des matchs du jour.

Regles :

- ne pas forcer l'authentification avant la premiere valeur ;
- ne pas afficher de paywall sur l'arrivee ;
- ne pas utiliser un fond qui cree un halo autour du logo ;
- le fond doit etre un asset assume, pas un patch sombre qui masque un probleme de transparence.

Asset actuel :

- `assets/backgrounds/auth-stadium-stands-background.png`

## Accueil Scores

L'accueil est le socle gratuit obligatoire. Il doit rester dense, lisible et tres rapide.

Etat par defaut :

- onglet actif : `Pour moi` ;
- calendrier horizontal compact avec jour et date ;
- segmented control : `Pour moi`, `Tous`, `Generateur` ;
- pas de bottom bar classique ;
- Quick Dock flottant en bas a gauche.

`Pour moi` :

- section `A suivre aujourd'hui` avec 3 rencontres qui aident a comprendre la journee ;
- selection de championnats issue des preferences utilisateur ;
- championnats replies par defaut ;
- badges de lecture visibles, sans transformer l'ecran en detail analytique.

`Tous` :

- affiche toutes les rencontres disponibles ;
- les ligues sont replies par defaut ;
- l'utilisateur choisit quel championnat deplier ;
- ne doit pas reutiliser la liste courte `Pour moi`.

`Generateur` :

- remplace l'ancien onglet `Live` dans le segmented control ;
- donne acces au generateur de ticket ;
- les propositions doivent rester visuellement compactes, notamment les boutons d'action.

## Quick Dock

Le Quick Dock est un marqueur d'identite Lector, mais il ne doit pas devenir un menu fourre-tout.

Etat ferme :

- capsule flottante contenant le logo `LS` ;
- position en bas a gauche ;
- taille compacte, utilisable a une main.

Etat ouvert sur l'accueil :

- `LS`
- `Aujourd'hui`
- `Pour moi`
- `Generateur`
- `Recherche`

Etat ouvert sur une fiche match :

- `LS`
- `Lectures`
- `Stats`
- `Favori`

Regles :

- maximum 4 destinations en plus du bouton LS ;
- contenu contextuel selon l'ecran ;
- ne jamais cacher une action critique uniquement dans le dock ;
- animation courte et lisible ;
- les entrees analytiques n'apparaissent que si elles ont du sens.

## Detail De Match Avant-Match

Le detail de match valide concerne d'abord l'avant-match.
Il ne doit pas etre confondu avec un ecran live.

Structure :

- header operationnel sans lockup Lector Sport ;
- retour, notifications et favori visibles ;
- card rencontre avec asset stade premium ;
- ligue, journee, horaire, statut `Avant-match`, equipes, stade ;
- section `Reperes Lector` avec cartes de lecture ;
- tabs : `Contexte`, `Classement`, `Forme`, `Infos` ;
- card `Contexte rapide` ;
- card `Derniers matchs` ;
- card `Suivre`.

Differenciation Lector gratuite :

- badges de lecture sur la rencontre ;
- contexte rapide pour lire l'opposition ;
- dernieres formes et reperes factuels ;
- actions de suivi simples.

Limites :

- ne pas afficher de recommandation avancee sur les surfaces gratuites de suivi simple ;
- ne pas inventer des commentaires impossibles a produire sans contexte IA ;
- ne pas transformer l'avant-match en timeline live.

Asset actuel :

- `assets/backgrounds/match-card-stadium-premium.png`

## Preferences

Le bouton profil du header ouvre les parametres Lector, pas l'onboarding.

Les preferences doivent permettre de modifier :

- championnats suivis ;
- lectures suivies ;
- configurations du ticket builder.

Effet attendu :

- les championnats choisis impactent `Pour moi` ;
- les lectures choisies impactent les lectures mises en avant ;
- le ticket builder permet de creer et modifier des configurations, pas seulement de voir un etat statique.

## Echelle Mobile

La densite mobile est une decision produit.
Les composants doivent etre compacts, pas simplement reduits au hasard.

Regles :

- calendrier minimal : jours et dates visibles, scroll horizontal, pas de gros bloc vertical ;
- labels secondaires souvent en `11` ou `12` ;
- titres de sections denses en `titleMedium` maximum ;
- cartes compactes avec padding contenu, pas padding decoratif ;
- bouton principal dans une carte/panneau : hauteur cible `40` a `44` px ;
- eviter les boutons disproportionnes comme un `Enregistrer` trop massif dans une carte de proposition ;
- au moins plusieurs lignes de matchs doivent rester visibles sur un mobile courant.

## Assets Et Logo

Regles logo :

- utiliser uniquement les assets de logo transparents valides ;
- ne pas reconstruire le logo avec un fond sombre ;
- ne pas ajouter de halo, glow ou plaque sous le logo ;
- sur les ecrans operationnels, le lockup complet n'est pas obligatoire et peut etre retire.

Assets principaux :

- `assets/brand/ls-logo-mark-clean.png`
- `assets/brand/lector-wordmark-text-clean.png`
- `assets/brand/lector-logo-lockup-clean.png`

## QA Visuelle

Avant validation d'un nouvel ecran :

- verifier mobile reel ou viewport mobile ;
- verifier que les textes ne debordent pas ;
- verifier que `Pour moi` et `Tous` affichent bien des contenus differents ;
- verifier que les ligues sont replies par defaut ;
- verifier que le dock n'occulte pas une action importante ;
- verifier que les assets de fond ne bougent pas de maniere incoherente au scroll ;
- verifier qu'aucune couleur locale ne remplace les tokens Lector.
