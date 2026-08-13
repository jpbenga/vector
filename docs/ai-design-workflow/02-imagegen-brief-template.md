# Contrat De Brief ImageGen

ImageGen sert a explorer une direction visuelle. L'image produite n'est pas une
spec technique et ne doit pas etre implementee directement.

Avant tout appel ImageGen, l'agent doit lire :

- `docs/ai-design-workflow/01-product-ux-context.md`
- `docs/theme-application.md`
- le ou les fichiers Flutter de l'ecran concerne, lorsque la demande vise un ecran existant.

## Structure Obligatoire Du Brief

Chaque brief ImageGen doit contenir :

```text
Produit :
LECTOR SPORT - Read the Game.

Ecran ou parcours :
...

Objectif utilisateur :
...

Probleme UX actuel :
...

Direction recherchee :
...

Theme / ambiance :
...

Structure attendue :
...

Contenu reel a afficher :
...

Composants Lector a respecter :
...

Contraintes design system :
...

Interdits :
...

Format :
...

Nombre de variantes :
...
```

## Contraintes Visuelles

- Respecter une experience mobile-first.
- Utiliser une densite d'information compatible avec un usage quotidien.
- Conserver la typographie Inter.
- Conserver la logique de badges, cotes, lectures et surfaces de Lector.
- Differencier les familles de lectures sans transformer les couleurs en niveau de confiance.
- Les cotes restent des donnees, pas des signaux emotionnels.
- Les CTA doivent rester clairs et peu nombreux.
- Les textes doivent rester lisibles dans leurs conteneurs.

## Interdits ImageGen

- Ne pas inventer de fonctionnalite produit majeure.
- Ne pas ajouter de probabilite de victoire.
- Ne pas afficher de gain potentiel.
- Ne pas transformer Lector en app de bookmaker.
- Ne pas creer de dashboard desktop si la cible est mobile.
- Ne pas utiliser d'effets gaming ou casino.
- Ne pas remplacer les composants operationnels par des illustrations decoratives.
- Ne pas changer arbitrairement le vocabulaire produit.

## Sortie Attendue

Pour une demande de redesign, l'agent doit demander 2 a 4 directions visuelles
distinctes, par exemple :

- direction conservatrice ;
- direction premium ;
- direction plus dense et operationnelle ;
- direction plus expressive.

Chaque direction doit rester compatible avec Lector et pouvoir etre formalisee
ensuite dans Penpot.

