# Audit final MVP front/local hors backend

Date : 2026-08-08

## Verdict

Le MVP front/local est complet pour une validation utilisateur avant backend.

Estimation : 100% du périmètre front/local défini dans
`docs/finition-mvp-front.md` est couvert par l'implémentation et par la recette
automatique.

Cette estimation exclut volontairement :

- backend applicatif ;
- synchronisation API-Football en production ;
- authentification ;
- persistance distante ;
- règlement automatique des tickets ;
- notifications ;
- analytics produit ;
- paiements ou fonctionnalités premium.

## Promesse produit vérifiée

Le produit reste un copilote de décision, pas un outil de prédiction :

- aucune promesse de gain ;
- aucun score prédictif visible ;
- aucune probabilité affichée comme vérité ;
- les lectures simples expliquent les signaux détectés ;
- les lectures combinées expliquent pourquoi plusieurs signaux convergent ;
- le marché recommandé traduit une lecture en sélection possible ;
- le ticket est construit depuis les opportunités et les stratégies, sans
  assouplissement silencieux.

## Couverture fonctionnelle

| Zone | Statut | Vérification |
|---|---:|---|
| Onboarding | 100% | Parcours complet, retour, annulation, édition, stratégie absente ou multiple. |
| Profil compilé | 100% | `CompiledDecisionProfile` complet, migration legacy et familles d'opportunités. |
| Stratégies | 100% | Création, édition, suppression, inactive, plusieurs `pickTypes`, bornes inclusives. |
| Pour moi | 100% | Jour courant, tri, filtres de lecture, états vides, opportunités sans marché. |
| Toutes les rencontres | 100% | Jour courant centré, sections repliées, marché global, bookmaker global, cotes absentes. |
| Détail rencontre | 100% | Lecture Copilot, arguments, contradictions, marché recommandé et données utiles. |
| Mon ticket | 100% | Source partagée, ajout/retrait, anti-doublon match, cote totale, validation, joué. |
| Générateur | 100% | Stratégies persistées seules, Copilot, modifiés, manuels, contraintes strictes. |
| Historique | 100% | Mémoire locale réelle, KPI locaux, filtres, détail, statut, suppression. |
| Design system | 100% | Couleurs, radius, ombres et overflows principaux contrôlés par tests. |
| Snapshots dev | 100% | Snapshot daté, fenêtre utile, état absent/vide/obsolète explicite. |

## Preuves de recette

Commandes exécutées :

```text
dart format lib test tool
flutter analyze
flutter test
```

Résultats :

- `dart format` : 99 fichiers vérifiés, 0 changement.
- `flutter analyze` : aucune erreur.
- `flutter test` : 114 tests passés.

## Parcours validés

- Onboarding complet jusqu'au profil terminé.
- Onboarding sans stratégie, avec profil tout de même complet.
- Onboarding avec création, édition et suppression de stratégies.
- "Pour moi" avec profil incomplet, filtres, tri, calendrier et ajout ticket.
- "Toutes les rencontres" avec recherche, filtres, expansion, marché et bookmaker.
- Détail depuis "Pour moi", "Toutes les rencontres" et "Mon ticket".
- "Mon ticket" replié, déplié, long ticket, suppression, validation et statut joué.
- Générateur Copilot, modifié, manuel, absence de stratégie et contrainte invalide.
- Historique avec KPI, période, source, statut, détail, suppression et réouverture.

## Éléments hors backend à conserver en tête

Ces points sont prêts côté front/local mais devront être reliés au backend :

- remplacer les snapshots locaux par une base alimentée par une tâche de
  synchronisation ;
- stocker les snapshots et les cotes de façon horodatée et immuable ;
- associer profil, stratégies, favoris et tickets à un vrai utilisateur ;
- régler les tickets depuis des résultats officiels ;
- sécuriser l'accès API-Football côté serveur.

## Conclusion

Le front/local peut être considéré prêt pour une recette utilisateur finale.
Le prochain audit pourra être lancé après validation visuelle et suppression du
fichier temporaire de finition.
