# Audit production football — 4 octobre 2026

Audit effectué par lectures SQL du projet lié et par le chemin REST public
anonyme utilisé par Flutter. Aucune écriture en production, aucun nouveau cycle,
aucun déploiement. Correction locale isolée sur
`codex/football-production-feed-fix`, issue de `main` à `50af53a`.
Le checkout hockey `codex/multisport-hockey` reste à `2943d26`.

## Farense–Chaves : données présentes, erreur de fusion dans Flutter

Le match fournisseur **1576482**, championnat **95**, a lieu le 4 octobre
à **12:00 Europe/Paris**, soit 10:00 UTC.

| Étape | Preuve observée |
| --- | --- |
| Collecte | Réponse `/fixtures` datée du 4 octobre : succès, une rencontre ; récupération à 00:36:09 UTC |
| Snapshot brut | `8a44c527-45c3-4a75-aebd-924f27bcffcb`, index contenant Farense–Chaves le 4 octobre |
| Snapshot compact | `1e8916b7-8640-4814-a9ec-f597e181b6bc`, un match, 15 lectures, lisible anonymement |
| Live | Activé, collectes chaque minute ; état du match à 10:39 UTC : première période, 35 minutes, 1–0 |

La sélection des lignes compactes choisissait correctement la ligne du Portugal.
L'erreur venait ensuite de `mergeMatchFeedSnapshotPayloads` : les périmètres des
publications étaient reconstruits à partir des données présentes dans le JSON.

Le snapshot de Ligue Europa capturé à **09:57:10 UTC** contient 18 rencontres
de cette compétition, mais aussi 17 classements pour contextualiser les clubs,
dont celui de la deuxième division portugaise. Son JSON ne transporte pas les
champs `scope` et `league_ids` pourtant présents sur la ligne de la table.
La fusion interprétait ce classement portugais comme un calendrier portugais
déjà chargé. Le snapshot portugais, plus ancien mais valide pour le jour choisi,
était ensuite ignoré. Le live fournit des mises à jour aux cartes existantes ;
il ne recrée pas une carte retirée par cette fusion.

### Correction locale

La requête de chargement des payloads lit également `scope` et `league_ids`.
Ces métadonnées officielles sont conservées dans le payload de fusion et priment
sur les championnats rencontrés dans les classements de contexte. Les anciens
formats de fixtures de tests conservent leur lecture compatible.

Cette correction fonctionne avec les snapshots déjà publiés. Elle ne nécessite
ni reconstruction du snapshot portugais, ni migration SQL, ni déploiement de
fonction Supabase. Le frontend corrigé doit être publié pour corriger la production.

## Erreurs de batchs : six exécutions, cinq compétitions

Les listes de l'administration montrent les 100 exécutions les plus récentes.
Elles évoluent pendant la collecte. Le dernier relevé de cet audit contient :

| Compétition | Début, heure Paris | Échec |
| --- | --- | --- |
| Supercoupe espagnole, 556 | 05:24 | Publication vide refusée, HTTP 422 |
| Supercoupe italienne, 547 | 05:32 | Publication vide refusée, HTTP 422 |
| Supercoupe belge, 519 | 05:48 | Publication vide refusée, HTTP 422 |
| Ligue des nations, 5 | 06:16 | Fin de chaîne non confirmée, classement ultérieur en échec |
| Amicaux internationaux, 10 | 06:24 | Fin de chaîne non confirmée, classement ultérieur en échec |
| Amicaux internationaux, 10 | 11:40 | Nouvelle interruption pendant le cycle demandé ce matin |

### Les trois calendriers vides

La collecte des trois supercoupes avait réussi, avec des réponses de calendrier
de saison. Le constructeur nocturne exigeait toutefois les réponses datées
pour l'ensemble de la période et refusait le snapshot vide quand elles manquaient.
Un calendrier sans match avait donc été traité à tort comme un échec de publication.

La fonction `build-match-feed-snapshot` corrigée a été déployée à **11:05 Paris**,
après ces exécutions nocturnes. Le nouveau passage de la Supercoupe italienne a
effectivement publié un compact vide à **12:30 Paris**, couvrant du 4 au 17 octobre.
Les deux autres supercoupes étaient encore en file dans le relevé ciblé ; leur
rétablissement n'est pas affirmé. Les erreurs historiques ne sont pas effacées.

### Les interruptions

Le message « stale running window » est un classement effectué après absence
de confirmation de fin. Il ne donne pas, seul, la cause initiale.

Pour la Ligue des nations, le sous-traitement de collecte a terminé à
06:18:18 Paris avec 26 rencontres, mais la chaîne quotidienne n'a pas enregistré
sa fin. Cela explique pourquoi une collecte peut avoir avancé tout en laissant
un batch en échec.

Pour les amicaux du cycle de ce matin, le cache montre **400 statistiques
d'équipes** traitées de 11:40:59 à 11:43:29, dans la phase initiale de collecte.
Cette phase parcourt toutes les équipes trouvées dans la saison, avant les lots
d'enrichissement. Le découpage en lots de 40 de l'enrichissement ne protège donc
pas cette boucle initiale.

Les traces HTTP de la chaîne montrent des réponses **504 / IDLE_TIMEOUT, 150 s**
et **546 / WORKER_RESOURCE_LIMIT**. Le second code ne distingue pas à lui seul
CPU et mémoire. Le timeout de 4 minutes configuré dans l'orchestration est
supérieur au délai de réponse de 150 secondes de la plateforme : il ne protège
pas le parent d'un arrêt par Supabase.

Le problème subsiste après le déploiement de ce matin. L'augmentation du quota
API ne le règle pas. La réparation à réaliser doit rendre la phase initiale et
les étapes quotidiennes reprenables : lots bornés, progression persistée, nouvelle
invocation pour le lot suivant, publication après confirmation de tous les lots.
La chaîne quotidienne doit aussi honorer `continue` et `batch_cursor` de la
collecte, plutôt que publier après le premier lot.

Référence officielle : [limites des Edge Functions Supabase](https://supabase.com/docs/guides/functions/limits).

## Vérifications

- 64 tests de fusion et d'écran des rencontres réussis lors du premier passage
  (un chemin de test inexistant avait été demandé en plus ; corrigé ensuite).
- 55 tests ciblés de repository, calendrier, carte live et contrat public réussis.
- 23 tests finaux de fusion, affichage de Farense–Chaves et publication compactée réussis.
- Test ponctuel sur les **74 payloads réellement lus anonymement** : après fusion
  corrigée, **245 rencontres**, Farense–Chaves présent, **15 lectures conservées**,
  carte mobile et score live correctement affichés. Le score injecté dans ce test
  reprend l'observation de 10:39 UTC ; ce test n'effectue pas de souscription live.
- `flutter analyze` : aucune anomalie ; formatage et `git diff --check` réussis.

Le test durable reproduit un snapshot européen plus récent portant un classement
portugais, puis le snapshot portugais. Il vérifie le match après fusion jusqu'à
la carte Flutter et son état live. Un autre test garantit qu'une publication
explicitement vide remplace son ancien calendrier sans ressusciter un match ancien.

## Vérification locale

### Indicateur visuel du direct

Le contrôle public supplémentaire de Farense–Chaves a reçu `HT`, 45 minutes,
2–0. L'ancien indicateur affichait simplement « Mi-temps » en texte de 12 pixels,
sans badge. Le composant commun `LiveMatchStatus` affiche désormais une pastille
et un badge utilisant les couleurs de direct du thème. À la pause, il indique
« Mi-temps · En direct » ; pendant le jeu, « 67′ · En direct », par exemple.
Le badge disparaît au résultat final, remplacé par « Terminé ». Les états en
retard gardent l'avertissement de fraîcheur et un repère de pause.

Cette modification s'applique aux cartes et à la fiche du match. Les tests mobiles
vérifient le jeu, la mi-temps et le résultat final pour les dix thèmes.

Le checkout d'audit contient une configuration `.env` ignorée par Git, limitée
à l'URL Supabase, la clé publique et `MATCH_FEED_SOURCE=supabase`.

```bash
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-football-production-audit
bash tool/run_web_with_env.sh 8109 release
```

Consulter le 4 octobre dans Tous. Le checkout et la configuration hockey restent
indépendants. Rien de cette correction n'a été poussé sur main ou déployé.
