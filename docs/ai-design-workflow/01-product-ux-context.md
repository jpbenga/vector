# Contexte Produit Et UX

Ce document resume l'essence produit que tout agent doit comprendre avant de
proposer une refonte UX/UI pour Lector.

## Produit

Lector Sport est une application mobile-first d'analyse football.
Sa promesse est :

```text
LECTOR SPORT
Read the Game.
```

Lector aide l'utilisateur a lire une rencontre, comprendre des signaux et,
pour les parcours avances, construire des tickets compatibles avec ses propres
strategies. L'application ne promet pas de resultat, ne predit pas l'avenir et
ne parle pas de gain.

## Vocabulaire Produit

- Lecture simple : signal elementaire identifie sur une rencontre.
- Lecture combinee : interpretation issue de plusieurs lectures simples coherentes.
- Marche recommande : marche compatible avec la lecture combinee.
- Pick : selection exploitable dans un ticket.
- Ticket : combinaison de picks respectant une strategie.
- Strategie : contraintes utilisateur pour construire des tickets.
- Vigilance : element qui nuance ou limite une lecture.

## Principes UX

- L'utilisateur doit comprendre pourquoi une lecture est proposee.
- La lecture doit rester explicable, pas mystique.
- Les tickets doivent etre contraints par les strategies de l'utilisateur.
- Un ticket ne doit jamais melanger plusieurs jours de matchs.
- Le mode invite doit permettre d'essayer l'application sans blocage.
- La premiere valeur doit arriver avant authentification, onboarding ou paywall.
- La connexion sert a retrouver profil, strategies, favoris et tickets sur plusieurs appareils.
- Les donnees sportives doivent etre presentees comme des faits horodates, pas comme des certitudes.
- Les parcours de suivi simple ne doivent pas etre traites comme des parcours avances.

## Ecrans Principaux

- Arrivee dans l'app : voir la promesse et acceder aux matchs sans friction.
- Authentification : se connecter ou continuer en invite.
- Onboarding : creer profil et strategies lorsque le declencheur est naturel.
- Pour moi : voir les rencontres et lectures selectionnees selon les preferences.
- Tous : explorer toutes les rencontres disponibles, ligues replies par defaut.
- Detail rencontre avant-match : comprendre le contexte et les reperes Lector.
- Generateur : proposer des tickets compatibles avec les configurations utilisateur.
- Mon ticket : gerer le ticket courant.
- Historique : retrouver tickets et statuts.
- Profil/parametres : gerer compte, championnats, lectures, ticket builder et synchronisation.
- Quick Dock : acceder rapidement aux actions contextuelles sans remplacer toute la navigation.

## Anti-Patterns

- Interface de bookmaker.
- Promesse de gain.
- Probabilite artificielle ou score de confiance non fonde.
- Sur-utilisation du vert comme "bonne opportunite".
- Sur-utilisation du rouge comme "mauvais pari".
- Ecrans marketing qui remplacent l'experience produit.
- Hero decoratif sans utilite dans les ecrans operationnels.
- Redondance argumentative.
- Parcours qui force l'authentification avant que l'utilisateur comprenne la valeur.
