# Checklist Visual QA

La Visual QA valide que l'implementation correspond a la maquette Penpot et ne
degrade pas les parcours existants.

## Ecrans A Verifier

- Authentification avant onboarding.
- Connexion depuis l'application.
- Onboarding.
- Pour moi.
- Toutes les rencontres.
- Detail rencontre.
- Generateur de tickets.
- Mon ticket.
- Historique.
- Profil / parametres.

## Etats A Verifier

- charge ;
- vide ;
- loading ;
- erreur ;
- donnees indisponibles ;
- invite ;
- connecte ;
- theme dark ;
- theme light ;
- themes alternatifs ;
- mobile et web preview.

## Elements Critiques

- navigation principale ;
- calendrier ;
- bannieres ;
- listes de competitions ;
- cartes match ;
- lectures simples ;
- lectures combinees ;
- badges ;
- cotes ;
- strategies ;
- tickets ;
- bottom sheets ;
- modales ;
- inputs ;
- chips ;
- toggles.

## Controle Technique

- Aucune erreur console critique.
- Pas d'overflow visuel.
- Pas de texte coupe dans les boutons.
- Pas de couleur locale introduite pour corriger un theme.
- Pas de regression sur les tests existants.
- Pas de modification non voulue dans les zones protegees.

## Automatisation Future

A terme, ajouter :

- screenshots Flutter web par viewport ;
- tests golden pour composants critiques ;
- comparaison visuelle sur Vercel Preview ;
- controle automatisé des contrastes lorsque possible.

