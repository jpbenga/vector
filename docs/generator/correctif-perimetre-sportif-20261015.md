# Correctif Générateur — Périmètre sportif et reprise contrôlée

## Cause reproduite

Requête `a7b26cdd-cae9-4d8c-ba67-9bebec3f81f2`, conversation `3a3dd2f7-9638-4321-be69-99a81768052b`, version `6875192428a2d6e7c8312978e61aa5e54cfd62fc`.

Le catalogue de préférences contenait football et hockey. La recherche q1, son évaluation et ses dossiers étaient hockey. Les trois plans de composition déclaraient hockey mais omettaient `sports` dans `changedFields`. `resolvePlan` conservait alors les deux sports du contexte initial. Une nouvelle recherche q2 était ouverte, puis le contrôle de dossiers exigeait des lectures q2 au lieu des lectures q1 existantes. La réponse finale sans projection calculée était correctement refusée.

La reproduction locale sur les publications conservées retrouve ces trois refus. Aucun modèle ni fournisseur n’est appelé pour cette reproduction.

## Sémantique et correction

`changedFields` est une **liste de modifications explicites**, pas la description complète des contraintes. Les autres valeurs proposées par le modèle ne remplacent pas les contraintes de travail.

- Une instruction sportive littérale et non ambiguë devient une contrainte serveur pour tout le tour. Les formulations ambiguës et les noms d’équipes ne servent pas à deviner une nouvelle discipline.
- La contrainte de sport est conservée dans `conversation.workingIntent`, y compris lorsque le modèle oublie le champ modifié. Le catalogue de préférences ne devient plus le périmètre implicite de composition.
- En l’absence d’une telle instruction, un ensemble choisi et lu peut être lié à une recherche vérifiée correspondant au sport déclaré ; on ne déduit jamais le sport d’un ticket multisport à partir de ses seules rencontres retenues.
- Les références explicites à un ancien ticket récupèrent ses contraintes propres ; une instruction sportive contradictoire n’est pas ignorée.
- Les dossiers ne sont réutilisés entre recherches que si date, contexte, rencontre, publication, horodatage et coup d’envoi sont identiques. Une version différente nécessite une lecture du dossier correspondant.
- Une incompatibilité renvoie `code`, périmètres attendu/reçu, `queryId`, clés des dossiers, recherches déjà lues et action de réparation. Ces références restent dans les diagnostics ; le message utilisateur explique la difficulté sans exposer les détails du moteur.
- Pour une même erreur déterministe : un retour de correction, puis arrêt au deuxième refus, même si le modèle change uniquement les marchés. Aucun troisième appel de réparation n’est lancé pour cette erreur.
- Le statut d’échec et l’archive privée conservent le diagnostic de contrat. Les permissions et la durée de rétention restent celles du dispositif existant.

Statut, coup d’envoi, fraîcheur analytique, fraîcheur des cotes, admissibilité des marchés, preuves et calcul serveur obligatoire restent contrôlés par les fonctions existantes.

## Fichiers

| Fichier | Rôle |
| --- | --- |
| `conversation_scope.ts` | Contraintes sportives explicites, comparaison et erreur structurée |
| `conversation_tools.ts` | Résolution commune, liaison recherche/dossiers et réutilisation compatible |
| `conversation.ts` | Même résolution pour la restitution, limite de réparation répétée |
| `handler.ts`, `turn_status.ts`, `tool_audit.ts` | Journalisation privée et explication de l’arrêt |
| `20261015090000_generator_composition_contract_audit.sql` | Conservation du diagnostic dans l’audit après expiration |
| `conversation_scope_test.ts` | Régressions de périmètre, continuité, changements volontaires et erreurs répétées |
| `check_generator_composition_continuity.ts` | Vérification locale du calcul réel sur captures de publications |
| Outils de publication et CI | Migration supplémentaire ; publication limitée à `lector-generator-workshop` pour ce correctif |

## Résultats locaux

- 271 tests du code partagé réussis, dont 167 du Générateur et 10 nouveaux scénarios.
- 7 tests des contrôles de publication et du transport de catalogue réussis.
- Migration SQL et retour arrière testés avec PostgreSQL embarqué : droits, conversations et tickets conservés ; champs privés étrangers au diagnostic exclus.
- Relecture des 56 rencontres football et 18 hockey à partir des publications conservées.
- Dix cas sur publications réelles : résultats et double chance à 60 minutes en hockey, résultat et double chance en football, quatre remplacements ciblés conservant l’autre sélection et la mise, rejet d’un marché inconnu et composition multisport. Les calculs utilisent les prix et preuves réels, sans modèle.
- Champions League et Championship du calendrier publié : neuf rencontres Champions League et une Championship retrouvées. Une composition choisissant une rencontre de chaque compétition reste impossible avec ces données ; les exclusions distinguent publication trop ancienne et prix inutilisables.

| Mesure | Incident réel initial | Après correction locale |
| --- | --- | --- |
| Recherches pour les plans hockey enregistrés | hockey puis football + hockey | hockey uniquement |
| Refus de liaison des trois plans | 3 | 0 |
| Sortie de la même demande sans mise | échec | projection serveur demandant la mise |
| Appels modèle | 23 | Pas de nouvelle mesure réelle autorisée |
| Durée globale | 98,749 s | Pas de nouvelle mesure réelle autorisée |

Les durées locales de calcul ne sont pas des mesures de latence en production. Les réponses du modèle, leur qualité sportive et leurs coûts après correction restent à vérifier après autorisation d’appels IA réels.

## UEFA : reprise séparée

Les trois tâches sont suspendues, non supprimées. Le contrôle prématch et son nouveau cron sont désactivés. Aucune erreur fournisseur ou collector n’est enregistrée pour ces tâches : leur suspension était imposée par l’arrêt global après le défaut du Générateur.

| Compétition | Offset conservé | Tâches à cette étape |
| --- | --- | --- |
| Champions League | 7 | 109 |
| Europa League | 17 | 218 |
| Conference League | 17 | 236 |

Les listes peuvent s’enrichir pendant la collecte. Dernier budget observé : 8 881 réservations sur 75 000 pour le 14 octobre UTC ; base de 1 577 626 771 octets. Ces valeurs doivent être relues lors de l’exécution.

La reprise préparée verrouille les trois lignes, exige leurs payloads exacts et leurs identifiants de runs existants, refuse un travail UEFA concurrent et un budget insuffisant, puis remet **les mêmes tâches** en file sans toucher aux curseurs. Une suspension dépassant une heure impose de renouveler leur heartbeat technique avant le prochain passage du worker. Cette opération ne change aucun timestamp analytique ou fournisseur.

La procédure a été exercée localement sur des checkpoints représentatifs : mêmes identifiants et payloads, pas de doublon, deuxième reprise refusée. Les hashes de production restent verrouillés aux payloads exacts exportés.

Après autorisation, suivre les étapes collect → résultats → snapshot → analyse. Vérifier la nouvelle source publiée, la complétude, les limites des données et les dates propres des analyses et des cotes. Réactiver le cron prématch seulement après le contrôle de reprise. Les crons préexistants ne sont pas modifiés par ce correctif ; un travail concurrent déclenché entre-temps doit faire refuser la reprise préparée.

## Publication nécessaire, non exécutée

1. **GitHub** : pousser le SHA local livré après confirmation, puis attendre la CI sur ce SHA exact. Les déploiements Git automatiques Vercel restent désactivés.
2. **Supabase / Générateur** : sauvegarder la fonction workshop actuellement servie et ses flags ; installer la migration d’audit, publier seulement `lector-generator-workshop`, vérifier source distante et droits. Conserver l’activation au seul compte autorisé ; aucun remplacement du Générateur legacy.
3. **Vercel** : produire et servir un build de la même révision. Le contrôle client/serveur impose cette cohérence : publier seulement le serveur avec une nouvelle révision recréerait les erreurs 409 des anciens clients.
4. **UEFA, autorisation distinctement identifiée** : exécuter la reprise gardée des trois checkpoints, suivre chaque étape, puis vérifier la fraîcheur et la conservation du calendrier avant activation du cron.
5. **Validation IA payante, à autoriser** : refaire les demandes libres football/hockey, leurs ajustements et la continuité. Mesurer les identifiants, la latence, les appels et coûts réels sous les budgets existants ; ne jamais assimiler les replays locaux à ce test.

## Retour arrière

Restaurer uniquement la fonction workshop sauvegardée, les anciens flags et le build Vercel correspondant à `6875192`. Le Générateur legacy reste intact. La migration d’audit est additive et compatible avec l’ancien code ; elle peut rester installée. Un retour du corps de fonction d’audit a aussi été testé localement sans modifier son ACL. Ne supprimer ni conversations, ni tickets, ni évaluations, ni sources.

Pour UEFA : désactiver le contrôle et son cron, suspendre les tâches concernées avec leurs checkpoints conservés. Ne pas restaurer un ancien collecteur incompatible avec un curseur actif.

Aucune publication, collecte fournisseur ou requête IA payante n’est exécutée dans cette livraison.
