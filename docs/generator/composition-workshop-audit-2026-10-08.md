# Générateur Lector — audit et atelier de compositions

Audit du **8 octobre 2026**, sur `codex/multisport-hockey`.

Cet audit décrit l’état avant intégration. L’[itération suivante](workshop-implementation-2026-10-08.md)
décrit le raccordement au service de démo et le protocole des deux modèles.

## Conclusion

Le chantier est bien celui de la construction et de la comparaison des
compositions. Le modèle comprend la demande ; **il ne choisit pas les rencontres**.
Le moteur actuel ordonne les candidats puis s’arrête à la première combinaison
admissible. Il ne compare ni les structures possibles ni l’apport d’un remplacement.

Un prototype déterministe est désormais disponible dans
[`workshop.ts`](../../supabase/functions/_shared/generator/workshop.ts).
Il conserve plusieurs compositions, leurs sources, leurs compromis et leurs
différences. **Il n’est pas branché sur le service actif ni publié dans la démo.**
Le comportement existant reste la référence pour le rejeu ; seul un point
d’observation facultatif a été ajouté à sa recherche.

Le prototype valide la faisabilité de cette méthode. Il ne constitue pas encore
une évaluation complète des marchés : les contradictions précises, les fenêtres
de données et les cohortes du Bilan manquent au contrat actuel.

## 1. Parcours actuel, vérifié dans le code

| Étape | Code | Fonctionnement réel |
|---|---|---|
| Interprétation | [`openai.ts`](../../supabase/functions/_shared/generator/openai.ts) | Un appel Responses transforme la demande en intention structurée. Le modèle reçoit le contexte, les tickets résumés et les huit derniers messages, pas les snapshots sportifs. |
| Configuration | [`lector-generator/index.ts`](../../supabase/functions/lector-generator/index.ts) et [`service.ts`](../../supabase/functions/_shared/generator/service.ts) | Nouvelle génération : profil effectif. Révision/alternative : contraintes et configuration figées du ticket de référence. |
| Sources | `sourcesFor` dans le handler | Publications serveur du jour demandé, filtrées par profil ; pas de cotes fournies par le modèle ou le client. |
| Bilan | RPC `match_reading_bilan_breakdown` | Lecture descriptive sur 90 jours, avec délai maximal de trois secondes. Son absence ne bloque pas le catalogue. |
| Candidats | [`catalog.ts`](../../supabase/functions/_shared/generator/catalog.ts) | Couples rencontre/marché/sélection/bookmaker, avec cote horodatée et références. |
| Classement | `rankCandidates` dans [`engine.ts`](../../supabase/functions/_shared/generator/engine.ts) | Nombre de familles de lectures décroissant, nombre d’avertissements croissant, horaire, identifiant. |
| Recherche | `compose` dans `engine.ts` | Parcours en profondeur ; arrêt dès la première composition conforme. Au plus 48 rencontres, 16 lignes par rencontre et 16 000 états par passage. |
| Remplacement | `revise` dans `engine.ts` | Première sélection compatible ; une sélection du même match est explicitement exclue, même si son marché change. |
| Explication et sauvegarde | `service.ts` et RPC de commit | Textes construits à partir des faits publiés, sans second appel rédactionnel IA. Historisation privée et confirmation des modifications. |

### Ce qui fonctionne déjà

- Une sélection par rencontre, aucune équipe répétée dans un ticket et un
  bookmaker commun.
- Mise bornée par le budget, calcul monétaire déterministe en centimes.
- Rencontres avant match uniquement ; publications de moins de 36 heures et
  cotes de moins de 48 heures.
- Marchés explicitement reliés aux lectures : une forme générique n’autorise pas
  automatiquement « les deux équipes marquent ».
- Empreinte sémantique des compositions, indépendante du prix, du bookmaker,
  du snapshot et de l’ordre. Une cote légèrement différente ne crée pas un
  « autre ticket ».
- Conservation des contraintes lors des alternatives et propositions de
  remplacement soumises à confirmation.

### Les défauts à corriger

1. **Première solution, sans comparaison.** Une combinaison qui dépasse très
   largement le retour minimal peut être retenue immédiatement. « Environ »
   doit devenir un objectif de proximité explicite ; un minimum seul ne suffit
   pas à représenter cette intention.
2. **Soutien et contexte mélangés dans le classement.** Le catalogue distingue
   `supportsMarket:false`, mais le classement compte aussi les familles de ces
   lectures. Une lecture qui ne soutient pas le marché peut donc améliorer sa
   position.
3. **Famille différente ne signifie pas données indépendantes.** Forme et
   domicile/extérieur peuvent reprendre les mêmes résultats. Les avertissements
   existent, mais les identifiants des matchs et fenêtres sources ne permettent
   pas de vérifier ces recoupements.
4. **Contradictions trop générales.** Le catalogue rejette une contradiction
   explicite ou certaines lectures négatives de l’équipe visée. Il ne publie pas
   une liste de contradictions évaluées pour chaque marché. Une lecture positive
   concernant l’adversaire n’est pas systématiquement traitée comme vigilance.
5. **Bilan descriptif, comparaison historique absente.** Le Bilan est ajouté sous
   forme de texte par lecture et championnat. Il n’est pas rapproché du marché,
   du rôle domicile/extérieur, du sport et d’une robustesse comparable.
   De plus, son ajout augmente le nombre d’avertissements utilisé par le tri :
   davantage de contexte historique peut pénaliser un candidat sans raison
   d’évaluation pertinente.
6. **Refus peu traçables.** Plusieurs exclusions du catalogue sont silencieuses.
   On dispose de messages généraux sur les manques, pas d’un journal complet
   expliquant chaque marché écarté.
7. **Alternative parfois trop rigide.** Le moteur privilégie toutes les nouvelles
   rencontres, puis toutes les nouvelles sélections. La diversification entre
   tickets peut également empêcher de partager des rencontres. Cette contrainte
   ne doit pas être imposée à des variantes d’une seule composition.
8. **Remplacement limité.** Le parcours actuel ne compare pas les remplacements
   et interdit de changer seulement le marché d’une rencontre conservée.

## 2. Modèle OpenAI, appels et consommation

Le **dernier déploiement réussi vérifié** a installé
**`gpt-4.1-mini-2025-04-14`**, et non GPT-4.5. Preuve :
[exécution GitHub 37740856896](https://github.com/jpbenga/vector/actions/runs/37740856896),
job `113190988381`, commit `74867bc9c2531bf37bc8c689dd87dc5507d07d70`.
Cela vérifie l’installation ; une modification manuelle ultérieure du secret
de modèle ne peut pas être exclue par ce seul journal.

- Un appel IA par message `chat` interprété, y compris une clarification ou une
  demande d’alternative. Aucun appel supplémentaire pour chercher les combinaisons.
- `prepare`, `read`, `history`, `apply` et `save` n’appellent pas le modèle.
  La transcription audio utilise séparément `whisper-1`.
- Responses avec `store:false`, JSON Schema strict, sortie plafonnée à
  1 800 tokens et corps de requête à 32 000 octets. Les sorties structurées sont
  déjà en place ; il n’est pas nécessaire de changer d’API pour démarrer cet
  atelier. [Documentation officielle](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses).
- Les tokens retournés par OpenAI sont enregistrés dans `usage` pour les tours
  réussis. Le succès ne conserve pas encore le modèle et les durées de chaque
  étape dans le même enregistrement ; cette télémétrie reste à ajouter avant
  une mesure complète en exploitation.
- Limites installées : 5 appels par compte/jour, 20 pour toute la démo/jour,
  réservation conservatrice de 0,025 USD par appel et enveloppe cumulative
  de 3 USD. Ce sont des garde-fous de réservation, pas une facture OpenAI.

Le journal du test initial déjà réalisé donne ces compteurs, sans aucun nouvel
appel payant pour cet audit :

| Modèle daté | Cas réussis | Tokens entrée, quatre cas | Tokens sortie, quatre cas | Temps cumulé, réservation et appels |
|---|---:|---:|---:|---:|
| GPT-4.1 Mini | 4/4 | 2 754 | 369 | 11 675 ms |
| GPT-4.1 Nano | 2/4 | 2 754 | 410 | 13 832 ms |

Source : [exécution initiale 37705748388](https://github.com/jpbenga/vector/actions/runs/37705748388),
job `113079583189` ; code du test
[`benchmark_lector_generator.ts`](../../tool/benchmark_lector_generator.ts).
Ce petit test d’interprétation ne mesure ni les demandes personnelles ni la
qualité des compositions. Les tokens exacts du premier ticket personnel n’ont
pas été consultés dans cet audit. Aucun modèle n’a été remplacé.

## 3. Rejeu d’une journée chargée

Publication publique de la démo du **samedi 10 octobre**, observée au
**8 octobre, 12:00 UTC**. Profil synthétique large : toutes les compétitions et
lectures de cette publication, les quatre marchés actuellement pris en charge.
**Ce n’est pas une reconstruction du profil ou du premier ticket personnel.**
Les cotes sont celles de l’archive, sans vérification actuelle.

- 123 rencontres dans la publication, dont 121 pertinentes pour le profil de test.
- 2 412 lignes de candidats, incluant les différents bookmakers.
- 290 sélections métier distinctes, réparties sur 111 rencontres.
- Catalogue : 258 ms environ sur le Mac. Aucun appel OpenAI ni API sportive.

| Demande, mise 50 € | Moteur actuel | Prototype |
|---|---|---|
| Retour minimal 300 €, au plus six rencontres | 3 états, première solution à 1 233,70 €, 79 ms | 23 282 états, trois variantes à 300,09 / 312,50 / 303 €, 1 352 ms |
| Retour minimal 500 €, au plus six rencontres | 3 états, même première solution à 1 233,70 €, 56 ms | 23 858 états, trois variantes à 503,25 / 503,75 / 505,75 €, 1 048 ms |

Les trois états actuels comprennent l’état vide : **ce sont des états de
recherche, pas trois rencontres analysées**. La première composition admissible
contient deux sélections. Le prototype poursuit l’exploration après avoir trouvé
un résultat conforme.

Ces mesures incluent le calcul local seulement. Elles ne mesurent pas le réseau,
Supabase, OpenAI ou le rendu Flutter. La limite de 48 rencontres, celle de quatre
bookmakers et la largeur du faisceau ont été atteintes ; le plafond d’états ne
l’a pas été. Une recherche bornée peut manquer une meilleure composition.

**Un résultat instructif :** la variante « moins de rencontres » à 300 € n’a
qu’une sélection à 6,25. Elle concentre toute la composition sur ce résultat.
Cela ne la rend pas plus sûre. Ce résultat doit servir à évaluer la qualité du
soutien publié et à expliquer la concentration ; il ne justifie pas un seuil
arbitraire de cote ni une probabilité inventée.

Artifacts consultables :

- [Rejeu lisible avec les rencontres et les variantes](audit-2026-10-08/replay.md).
- [Liste brute dans l’ordre du moteur actuel](audit-2026-10-08/candidates.csv).
- [Résultats, preuves et différences structurées](audit-2026-10-08/workshop-replay.json).

Le CSV présente toutes les lignes admissibles, dont celles de différents
bookmakers. Il montre l’ordre du classement ; il ne prétend pas que le moteur
actuel a parcouru chacune de ces lignes avant de s’arrêter.

## 4. Protocole du prototype

### Évaluation d’une sélection

- Seules les lectures qui soutiennent directement le marché alimentent les
  groupes de données ; les lectures de contexte restent visibles séparément.
- Forme et domicile/extérieur sont regroupés conservativement dans
  `recent_results`. Radar et scénarios dérivés n’ajoutent pas un groupe.
- Sources, échantillon minimal, ancienneté de cote et références redondantes
  sont conservés. L’indépendance est explicitement **non vérifiée**.
- Contradictions précises : `not_published_per_market`. Historique : descriptif
  ou absent, sans score fabriqué à partir d’un taux de confirmation.
- Le prototype reçoit uniquement les candidats du catalogue serveur. Il ne
  remplace pas sa vérification de profil, de lectures autorisées et de marchés.

### Exploration et comparaison

- Réduction diversifiée par sport et compétition, plutôt que les premières
  rencontres par horaire. Au plus 48 rencontres et quatre bookmakers.
- Recherche par faisceau de largeur 48, plusieurs axes de conservation :
  soutien documentaire, proximité de l’objectif, nombre de conditions,
  concentration de la cote. Plafond de 500 000 états pour l’ensemble de la demande.
- Mise identique, un bookmaker et une sélection par rencontre dans chaque
  proposition. Le calcul final du retour utilise les centimes du moteur existant.
- Archive bornée puis conservation de compositions non dominées **dans cette
  archive seulement**. Ce n’est pas une preuve d’optimalité globale.
- Au plus trois variantes ; une ou zéro sont des résultats valides. Elles sont
  des alternatives pour **la même mise**, pas trois tickets à jouer simultanément.
- Comparaison : sélections conservées, retirées, ajoutées et marchés remplacés ;
  rencontres et sélections partagées sont comptabilisées.
- Une demande générale d’alternative exige un changement significatif : nombre
  de sélections différent ou modification d’au moins un tiers des sélections.
  C’est une règle du prototype à évaluer, pas un score de diversité statistique.
- Une substitution ciblée peut modifier une seule sélection en conservant les
  autres. L’option « mêmes rencontres » impose toutes les rencontres de référence
  et autorise leurs changements de marchés.
- L’empreinte des compositions déjà proposées empêche de répéter le même ticket
  avec un autre bookmaker ou une cote légèrement différente.

Les critères sont des heuristiques explicites, non calibrées. Ils ne mesurent
ni une probabilité de succès ni une rentabilité. Les noms internes des variantes
décrivent leur construction, sans label « sûr » ou « risqué ».

## 5. Jeu d’évaluation

[`workshop_test.ts`](../../supabase/functions/_shared/generator/workshop_test.ts)
couvre dix situations :

1. Retirer une condition à 1,04 qui n’est pas nécessaire pour atteindre le minimum.
2. Ne pas gonfler le soutien avec forme/domicile redondants, Radar, scénario ou
   lecture sans rapport avec le marché.
3. Autoriser un autre marché du même match, sans prendre un changement de cote
   pour une nouvelle variante.
4. Respecter l’historique pour « un autre ticket », sans forcer trois propositions.
5. Conserver exactement les rencontres quand cette contrainte est demandée.
6. Écarter petit échantillon, cote périmée et autre journée, sans compléter
   artificiellement l’objectif.
7. Respecter budget, bookmaker, rencontre unique, équipe unique et sport exigé.
8. Réduire le maximum de matchs sans augmenter la mise pour compenser.
9. Comparer un changement de marché en gardant les cinq autres sélections.
10. Borner le travail et obtenir les mêmes empreintes malgré un ordre d’entrée différent.

Ces tests sont sans appels payants. Ils évaluent les contraintes et la comparaison,
pas le résultat sportif des tickets.

Vérification locale : **107 tests backend réussis**, dont les dix nouveaux cas
du prototype et les dix-neuf cas du Générateur existant. Vérification des types,
lint des nouveaux fichiers et contrôle du diff réussis. Aucun fichier Flutter
n’a été modifié dans cet audit.

## 6. Suite de l’intégration

Le moteur de variantes peut être développé sans changer de modèle. Pour le
brancher correctement, les prochaines étapes sont :

1. **Publier le contrat d’évaluation par marché.** Références des matchs et
   fenêtres derrière les lectures, soutien direct, contradictions pertinentes,
   données inconnues et raisons des exclusions. Cela doit provenir du backend,
   pas d’une interprétation libre du LLM.
2. **Construire les cohortes du Bilan.** Sport, famille de lectures, marché,
   domicile/extérieur, périodes et échantillons comparables ; distinguer bilan
   de lecture et résultat d’un pari. Un faible effectif reste un manque.
3. **Mesurer sur Supabase et journaliser les étapes.** Modèle réel, usage,
   catalogue, recherche, limites et comparaison. Le temps CPU et la mémoire du
   faisceau doivent tenir dans les limites du service ; aucune latence serveur
   n’est déduite du benchmark Mac.
4. **Relier le protocole à la conversation.** Reprendre les composants Flutter
   Lector, afficher les différences et les contributions, conserver l’acceptation
   explicite d’une variante. Une explication IA supplémentaire éventuelle devra
   être bornée et comptée dans l’enveloppe de tests.
5. **Rejouer les demandes et alternatives avant activation démo.** Contrôler
   stabilité, sources, budgets et diversité ; conserver une possibilité de retour
   au moteur actuel. Le football de production reste séparé de la branche hockey.

Les publications hockey ne contiennent toujours pas de marchés/cotes utilisables
par le Générateur. Le protocole est commun aux sports, mais il ne peut proposer
un ticket hockey réel avant la collecte correspondante et l’adaptateur de preuves.

## Reproduction hors ligne

À partir de la publication publique conservée localement :

```sh
deno run --node-modules-dir=none --no-lock \
  --allow-read=build/multisport-demo/delivery/football/demo-2026-10-08/2026-10-10.json \
  --allow-write=docs/generator/audit-2026-10-08 \
  tool/audit_generator_workshop.ts \
  build/multisport-demo/delivery/football/demo-2026-10-08/2026-10-10.json \
  docs/generator/audit-2026-10-08
```

Le script ne lit ni comptes, ni conversations, ni clés. Il ne contacte aucun
service. Le fichier source de build peut être régénéré ou nettoyé ; les résultats
du rejeu sont conservés dans le dossier d’audit.
