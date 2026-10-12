# Fiche européenne — livraison du 12 octobre 2026

Démo : https://lector-sports-demo-lector1.vercel.app/sports/football

Accès vérifié dans le navigateur : Tous → mercredi 14 octobre → Europe → UEFA Champions League → Feyenoord–Como. L’authentification Vercel ne s’est pas interposée. Le compte Lector reste requis pour les fonctions personnelles et le Générateur.

## Composants et données

- `european_fixture_comparison.ts` : dossier pré-match versionné, résolution du championnat et de la saison domestiques, derniers résultats éligibles, parcours européen par phase, premier match d’un aller-retour, synthèse factuelle et provenance.
- `EuropeanFixtureComparison` : modèle commun Dart, réutilisant les types de résultats et de classements existants.
- `EuropeanMatchHero`, `EuropeanComparisonSections`, `EuropeanMatchActions` : présentation face à face, détails dépliables et actions existantes.
- `LectorMatchDetailView` / `MatchDetailPage` : variante européenne ; Synthèse, Contexte, Classement, Forme, TAT, Marchés, plus Stats pour une rencontre commencée ou terminée. Classement complet conservé lorsque la publication est antérieure au match. Aucun onglet Historique ajouté en doublon de TAT.
- Adaptateur et livraison : un seul dossier par détail de rencontre ; aucun ensemble de 108 dossiers dans les cartes de la journée.
- Générateur : référence canonique sport/identifiant/date ; `read_match_data` retourne le dossier structuré de la rencontre. Les statistiques cumulées non arrêtées au match sont exclues de cette projection européenne.

## Couverture réelle de cette publication

| Compétition | Dossiers | Contextes domestiques identifiés / équipes | Équipes avec historique européen |
| --- | ---: | ---: | ---: |
| Champions League | 36 | 64 / 72 | 72 |
| Europa League | 36 | 56 / 72 | 72 |
| Conference League | 36 | 48 / 72 | 48 |
| Total | 108 | 168 / 216 | 192 |

Les 48 contextes domestiques non résolus sont affichés comme manquants. Une absence d’historique européen avant J1 n’est pas transformée en un bilan nul. Qualifications, phase de ligue et élimination directe restent séparées. La saison domestique peut différer du millésime européen ; une saison terminée reste explicitement identifiée pendant l’interruption avant le démarrage de la suivante.

### Exemple vérifié dans la démo

Feyenoord–Como : 14 octobre à 18:45, phase de ligue J2, De Kuip / Rotterdam.

- Feyenoord : 13/15 points sur les cinq derniers matchs domestiques, 15 buts marqués et 3 encaissés.
- Como : 10/15 points, 8 buts marqués et 5 encaissés.
- Les deux équipes ont un seul résultat de phase de ligue disponible à la date de publication ; l’échantillon limité est indiqué.
- Les rangs domestiques restent contextualisés par championnat. L’écart de points par match n’est pas présenté comme une supériorité universelle.

## Vérifications

- CI complète réussie pour la dernière révision de publication : https://github.com/jpbenga/vector/actions/runs/38255353181
- Publication confirmée : https://github.com/jpbenga/vector/actions/runs/38256191233
- 11 contrats serveur : avant J1, deux résultats, plusieurs journées, élimination directe et aller-retour, championnats distincts, moins de cinq résultats, consultation historique, API partielle, saisons calendaires différentes, horodatage propre à chaque observation, interruption domestique.
- 6 contrats de livraison : conservation des lectures/cotes, archive temporelle, autorité des sources et dossier limité à la rencontre demandée.
- Analyse Flutter sans erreur ; tests de modèle et d’actions de la fiche réussis.
- Captures avec de vraies publications aux largeurs 320, 375, 390, 430 et 768 px : aucune exception de rendu.
- Contrôle des 108 dossiers servis : chaque résultat est antérieur au coup d’envoi ; chaque classement retenu possède une observation antérieure ; les dénominateurs de forme correspondent aux rencontres réellement utilisées.
- Navigateur : ouverture depuis Tous, affichage des logos, accès Contexte / Classement et présence des vues Général, Domicile, Extérieur, Forme. Les actions du Générateur ont été testées par doubles de test pour ne pas déclencher de requête payante.

## Captures réelles du lien public (390 px)

![Synthèse](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/european-detail-synthesis-mobile.png)

![Contexte](/Users/chloe/.codex/visualizations/2026/09/16/01a0aaf1-05e5-7562-8f19-7332ea8701f5/european-detail-context-mobile.png)

## Assets

Les trois assets internes existants sont réutilisés :

- `competition-champions-original-v1.png`
- `competition-europa-original-v1.png`
- `competition-conference-original-v1.png`

Logos d’équipes et de compétitions : données déjà fournies par le projet. Aucune nouvelle photographie officielle ni nouveau visuel de trophée intégré.

## Publication et limite de l’environnement

La reconstruction complète initiale a dépassé le délai du client. La publication ciblée lit les archives et le cache existants sur le runner GitHub, puis utilise l’analyseur habituel. Les observations originales restent datées ; une nouvelle date de publication n’autorise jamais une statistique postérieure au match.

Une étape facultative d’indexation cloud échouait ensuite avec `Delivery registration HTTP 404` : `feed_delivery_claim` et le protocole associé ne sont pas installés dans cet environnement. Cette capacité est désormais vérifiée avant utilisation. La démo emploie la livraison statique réellement disponible ; ces fichiers ont été reconstruits, puis publiés sur Vercel. Aucune migration ni activation d’un autre système de livraison n’a été imposée.

Le dossier est exploitable par le Générateur depuis la publication canonique. Les captures de démo utilisent les sources statiques enregistrées dans le reçu ; de nouvelles publications serveur peuvent avoir d’autres identifiants sans changer les observations sportives sous-jacentes.

Aucun nouvel appel au fournisseur sportif ni au modèle IA pendant ces publications/tests. Les dépenses éventuelles d’hébergement ne sont pas mesurées par ce compteur.

## Limites explicites

- Aucun classement historique affiché sans observation antérieure exploitable. Des résultats anciens peuvent être reconstruits depuis des scores finaux, avec indication de cette limite.
- Lorsque la collecte est postérieure au match et que la fin n’est pas horodatée, les résultats trop proches du coup d’envoi sont écartés par prudence.
- Les cas après plusieurs journées et en élimination directe sont validés par contrats ; la publication réelle actuellement consultée possède seulement une journée achevée de phase de ligue. Aucun résultat futur ajouté pour simuler les journées suivantes.
- Pas d’absences, de fatigue, de joueurs clés ou de variation de rang inventés. La qualité des adversaires n’est pas résumée par un indicateur fictif.
- Les matches domestiques manquants dépendent de la couverture du cache ; leur absence n’est pas interprétée comme une mauvaise performance.

## Éléments non modifiés

Algorithmes de lectures et de classement, règles métier des paris, modèle IA/configuration du Générateur, conservation des sessions, ajout/retrait de la Shortlist, cartes et header principal validés, fiches de championnat domestique et de hockey, données live et statistiques existantes.
