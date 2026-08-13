# Contrat Penpot

Penpot transforme une direction ImageGen validee en maquette structuree.
Penpot est la source de verite design avant implementation Flutter.

## Entrees

- ImageGen direction validee.
- Notes de review.
- Contraintes du design system Lector.
- Contenu reel ou contenu representatif approuve.
- Liste des composants existants a reutiliser ou adapter.

## Obligatoire Dans Penpot

Chaque maquette finale doit definir :

- frame mobile cible ;
- grille ou logique d'alignement ;
- hierarchy typographique ;
- spacing ;
- couleurs/token mapping ;
- composants ;
- variants ;
- etats : normal, actif, disabled, loading, empty, error si necessaire ;
- interactions principales ;
- comportement responsive si applicable ;
- annotations des decisions UX.

## Difference ImageGen / Penpot

ImageGen peut proposer :

- ambiance ;
- composition ;
- rythme visuel ;
- direction artistique.

Penpot doit formaliser :

- dimensions ;
- composants ;
- tokens ;
- etats ;
- coherence ;
- faisabilite.

## Definition Of Done Penpot

Une maquette Penpot est prete pour implementation lorsque :

- le parcours est valide ;
- les composants sont identifies ;
- les tokens sont mappes ;
- les textes sont approuves ;
- les etats critiques sont couverts ;
- les ecarts avec l'image ImageGen sont notes ;
- l'implementation Flutter peut etre decrite sans interpretation majeure.

