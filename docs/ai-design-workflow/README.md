# Workflow IA Design Lector

Ce dossier decrit le workflow de redesign UX/UI assiste par IA pour Lector.
Il sert de reference avant toute generation d'image, maquette Penpot ou
implementation Flutter.

Le principe central est simple :

```text
Application actuelle
-> audit produit et UX
-> exploration visuelle avec ImageGen
-> choix et iterations
-> formalisation Penpot
-> validation finale
-> implementation Flutter sur branche dediee
-> visual QA
```

## Regles Non Negociables

- ImageGen explore une direction artistique, mais ne decide jamais de la logique produit.
- Penpot est la source de verite design avant implementation.
- Codex n'implemente jamais directement depuis une image brute non formalisee.
- Une refonte UI ne doit pas modifier le moteur, les contrats metier, Supabase ou les donnees sans decision explicite.
- Les ecrans doivent rester branches sur le design system Lector existant : tokens, ThemeExtensions, composants, typographie, espacements et rayons.

## Documents

- [Contexte produit](01-product-ux-context.md)
- [Contrat de brief ImageGen](02-imagegen-brief-template.md)
- [Checklist de review ImageGen](03-imagegen-review-checklist.md)
- [Contrat Penpot](04-penpot-spec-contract.md)
- [Contrat d'implementation Flutter](05-implementation-contract.md)
- [Checklist Visual QA](06-visual-qa-checklist.md)

## Quand Utiliser Ce Workflow

Utiliser ce workflow pour :

- redesign d'un ecran ;
- refonte d'un parcours utilisateur ;
- nouvelle direction visuelle ;
- evolution de la densite ou de la hierarchie UI ;
- validation d'un composant avant implementation ;
- audit UX/UI important.

Ne pas l'utiliser pour :

- correction bug backend ;
- migration Supabase ;
- changement de regle metier ;
- modification de moteur d'analyse ;
- petite correction visuelle locale deja clairement specifiee.

