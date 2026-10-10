# Étape 2 — Fiches individuelles et comparaison

Branche : `codex/multisport-hockey`. Fonction : `lector-generator-workshop`.
Le football sur main et les collecteurs ne sont pas modifiés.

## Parcours

1. `search_matches` ouvre le périmètre demandé et récupère toutes les publications épinglées (étape 1).
2. `evaluate_matches(queryId, criteria, matchKeys=null)` prépare une fiche par rencontre du périmètre entier, y compris les pages non affichées. Une liste de clés explicite restreint exactement ce périmètre.
3. Chaque fiche contient les lectures autorisées, le Radar, les résultats récents publiés disponibles, les marchés admissibles, les contradictions, les échantillons et la provenance. La fenêtre de résultats est explicitement limitée aux dix rencontres antérieures disponibles ; ce n’est pas une lecture exhaustive de toutes les statistiques brutes. Le modèle peut approfondir avec `read_match_data`.
4. Le modèle de la session évalue chaque fiche : adéquation au critère de 0 à 4, arguments, références, limites, marché éventuel. Ce repère ordinal n’est jamais une probabilité ni un taux de réussite.
5. Le serveur vérifie une réponse par rencontre, toutes les références et le soutien direct du marché. Un lot invalide ne compte aucune rencontre comme évaluée.
6. La conversation reçoit TOUTES les évaluations compactes pour la comparaison globale, sans présélection des premiers matchs ni arrêt au premier choix adéquat. `read_matches` fournit ensuite les preuves et marchés détaillés des rencontres retenues.
7. Le résultat conserve les six choix (ou le nombre demandé), les limites et la couverture. `read_match_evaluations` permet à l’utilisateur de demander les motifs des choix non retenus dans la même conversation, même au message suivant (identifiant d’évaluation ou `latest`). Les identifiants uniques d’évaluation, évaluations complètes, identités de sources et reçus sont conservés dans l’audit serveur de la demande.

## Bornes techniques explicites

- Lots de 24 fiches maximum, divisés aussi selon un plafond de 34 Ko de données utiles.
- Vingt-quatre appels parallèles maximum ; un appel ne peut dépasser 45 secondes. La concurrence reste bornée : un refus de quota est enregistré comme un lot non évalué, sans relance automatique.
- La conversation actuelle reste bornée à 110 secondes ; 25 secondes sont réservées après les évaluations à la comparaison/réponse. Un dépassement rend la couverture partielle, jamais exhaustive. Ce protocole est un premier jalon mesurable, pas un worker durable sur plusieurs minutes.
- Jusqu’à 750 rencontres comparables par recherche ; au-delà, refus explicite sans omission silencieuse. Deux critères évalués maximum par échange ; résultats identiques mis en cache dans cet échange. Aucun crédit commercial ajouté.
- Aucune relance payante automatique. Les lots incomplets/invalides et leurs identités restent dans l’audit. Une annulation interrompt les appels actifs.
- Aucune déduction du système de points hockey sans règles de ligue publiées. Les résultats et les lectures restent lisibles pour les deux sports.

## Accès et coût

Les outils du modèle n’exposent ni SQL, ni URL arbitraire, ni identifiant d’utilisateur, ni écriture. L’application authentifiée enregistre comme auparavant la conversation et son audit. Aucun nouveau stockage SQL, secret, cron ou droit d’accès.

Les reçus d’appel associent le modèle, les tokens, le temps, l’estimation USD standard et les clés du lot. Ce coût estimé n’est pas une facture ni une promesse de coût par utilisateur. Le modèle déployé reste celui configuré ; pas de bascule silencieuse.

## Vérification

`match_evaluation_test.ts` contrôle 500 fiches, les meilleures en dernière page, les lots invalides, les cotes/données absentes, les périmètres, le cache, la pagination d’audit, les collisions football/hockey et l’annulation.

`tool/evaluate_generator_matches.ts` effectue deux demandes réelles sur 500 rencontres synthétiques, avec GPT-6.1 Sol et GPT-6 Luna. Il exige 500 évaluations validées et les six écarts les plus marqués placés en fin de corpus. Les temps, tokens, coûts estimés et motifs sont exportés en artifact GitHub. Un échec bloque le déploiement. Ce corpus vérifie le fonctionnement et la couverture ; il ne mesure pas une performance prédictive ni la pertinence de toutes les questions réelles.

## Mesure locale de préparation

Corpus synthétique de 500 fiches mixtes : 205 ms de préparation, 210 ms de CPU, RSS du processus Deno 93 MiB. Cette mesure porte uniquement sur la préparation locale des fiches, sans appel IA ni réseau. Les latences et coûts des modèles restent à mesurer avec le workflow dédié.
