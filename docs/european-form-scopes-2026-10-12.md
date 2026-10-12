# Périmètres de forme des cartes et de la synthèse — 12 octobre 2026

## Règle produit clarifiée

Cette correction remplace le choix de présentation de `european-card-domestic-form-fix-2026-10-12.md`.

| Surface | Source | Périmètre |
| --- | --- | --- |
| Carte européenne | `europeanRecentMatches` du dossier de la rencontre | Jusqu’aux cinq derniers résultats joués dans cette compétition et cette saison, qualifications comprises lorsqu’elles existent |
| Synthèse : situation domestique et forme récente | `domesticRecentMatches`, `domesticStanding`, `domesticSummary` | Championnat domestique, jusqu’à cinq matchs avant le coup d’envoi |
| Synthèse : parcours européen | `europeanPhaseMatches`, `europeanSummary` | Bilan de la phase en cours ; les autres phases restent consultables dans les détails |

Une série européenne vide ou courte n’est pas complétée avec des résultats de championnat. Les identifiants, dates, saisons et compétitions sont contrôlés. Le nombre de résultats réellement affichés est indiqué pour les petits échantillons européens, sans ratio trompeur « 1/5 ». Les cartes nomment leur compétition dans le libellé de forme.

## Exemple réel publié : LASK–Liverpool

Rencontre 1635674, source publique `e9e5b196-49be-46af-916c-43d470053813`.

- Liverpool : un résultat européen disponible ; cinq résultats de Premier League dans la synthèse.
- LASK : trois résultats européens disponibles, dont deux de qualification et un de phase de ligue ; cinq résultats domestiques dans la synthèse.
- Le bloc « Parcours européen » présente séparément la phase de ligue et donne accès aux autres phases. Aucun postulat « tous les clubs ont joué exactement un match » n’est codé.

## Transport et cache

La projection légère `european_card_forms` transporte désormais les résultats européens nécessaires aux cartes, avec la même identité de fixture que le dossier détaillé. Une ancienne projection domestique en cache est rejetée comme source de forme européenne ; le lecteur peut utiliser les résultats européens déjà publiés par le transport historique. Les dossiers détaillés restent intacts.

La démo est régénérée depuis les sources publiques locales déjà collectées : six journées, 108 rencontres et 446 observations européennes pour les cartes, soit 74 760 octets de moins que la projection domestique précédente. Aucun appel fournisseur ou IA n’est lancé. La correction ne comble pas les championnats domestiques non résolus dans certains dossiers.

## Vérification

45 tests Flutter ciblés réussis et 7 tests Deno du transport réussis. Les 7 contrôles de périmètre ont ensuite été exécutés à nouveau, dont le contrôle ajouté sur les anciennes projections en cache ; tous réussissent. L’analyse Flutter ne rapporte aucune anomalie. Les tests couvrent notamment les trois compétitions européennes, l’exclusion des autres saisons/compétitions et des matchs futurs, la synthèse comportant les deux périmètres, les données absentes, la fusion des sources et les largeurs 320/375/390/430/768 px.

La présentation générale, les lectures, cotes, filtres, Shortlist et actions Générateur ne sont pas modifiés. Le bloc domestique et le parcours européen de la synthèse sont conservés.

## Livraison vérifiée

- Source : `69effaa7541cf38e1ab6da7e74b40578ec1cc1b4`.
- CI complète réussie : https://github.com/jpbenga/vector/actions/runs/38286624999.
- Déploiement prêt : `dpl_7Ez2SAp6aoKKE763EnLrgPZ61eyf`.
- Alias habituel : https://lector-sports-demo-lector1.vercel.app.
- Vérification dans l’application à 390 px : Liverpool a une cellule européenne et le libellé de compétition sur la carte. La synthèse montre cinq résultats de Premier League et un résultat de phase de ligue dans deux panneaux distincts.
- Captures : `european-card-competition-form.png` et `european-synthesis-domestic-and-competition.png` dans le dossier de visualisations de cette conversation.
