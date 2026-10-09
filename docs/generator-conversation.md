# Conversation du Générateur démo

## Contrat

Le dialogue conserve un état de travail : contraintes actives, rencontres retenues,
analyses, compositions et versions. Un message peut corriger une contrainte, consulter
une autre journée ou comparer un objet antérieur. Il n'existe pas de détection de
phrases particulières pour l'enchaînement analyse → composition.

La branche multisport utilise `converse` dans `lector-generator-workshop`.
`lector-generator` publié pour le football conserve son parcours existant jusqu'à
validation de la démo. Ne pas fusionner la branche multisport pour publier ce backend.

## État et références

`State.conversation` contient les contraintes résolues par le serveur, un registre
compact des échanges, les marchés effectivement retenus et les références des
publications consultées. Le modèle reçoit les vingt derniers messages avec leurs
rôles, les contraintes actives et les références des objets. `read_session` permet
de consulter le registre et les anciens tickets de la même session.

`ConversationPlan.changedFields` exprime une modification partielle. La mise, les
bornes de retour et leur nature sont patchées séparément. `newTask` réinitialise un
travail indépendant. Les identités de rencontre incluent le sport : `football:123`
et `hockey:123` ne désignent jamais le même objet.

Une correction de mise peut conserver une composition en produisant un nouveau
brouillon ; une demande d'alternative doit changer la composition. Les anciens
objets et les cotes initiales restent distincts des nouvelles propositions.

## Capacités du modèle

| Outil | Accès |
| --- | --- |
| `read_profile` | Configuration active transmise par l'application |
| `search_matches` | Rencontres publiées : date, sports, Pour moi / Radar / Tous, recherche textuelle et pagination |
| `read_matches` | Lectures, Radar, marchés admissibles, contradictions, échantillons et références |
| `read_match_data` | Détail de la publication identifiée et état live séparé, selon disponibilité |
| `read_session` | Échanges, contraintes et tickets du compte authentifié dans cette session |
| `read_bilan` | Lectures et suivis descriptifs, sans déclencher de vérification |
| `read_composition_options` | Projections et comparaisons calculées en mémoire, avec contrôles métier |

Il n'existe aucune capacité SQL, HTTP arbitraire, RPC arbitraire, modification du
profil, sauvegarde durable, paiement, pari ou commande système. Aucun outil n'accepte
un identifiant d'utilisateur fourni par le modèle. Les paramètres sont stricts et
vérifiés à nouveau par le serveur ; les références de rencontres doivent provenir
d'une recherche, et les détails doivent avoir été consultés avant une sélection.

Les appels aux données sont définis dans le port serveur. Les anciens tickets sont
filtrés par l'utilisateur authentifié **et** l'identifiant de conversation. Le modèle
n'a pas accès au client Supabase ni aux secrets. Les textes des publications sont des
données, jamais des instructions qui peuvent ajouter des droits.

La persistance des messages, des brouillons proposés et des étapes d'avancement est
réalisée par l'application après validation, avec son contrôle d'identité et de
révision. Elle est distincte des capacités de lecture de l'agent. Les actions explicites
de sauvegarde et de suivi de l'interface restent hors de ses outils.

## Responses et affichage de l'avancement

Une boucle Responses commune traite le dialogue et les outils. `store:false` utilise
l'historique manuel. Tous les éléments de réponse, notamment le raisonnement chiffré,
sont rejoués dans la boucle avec les résultats d'outils. Ce contenu privé opaque n'est
ni affiché ni sauvegardé. Seuls les résumés API et les étapes de consultation réellement
effectuées alimentent l'avancement existant de l'interface.

La réponse finale suit un schéma strict. Une composition ne peut être affichée qu'avec
l'identifiant d'une projection réellement calculée et un plan identique. Les prix et
sélections restent des faits serveur ; le modèle ne les fournit pas au calcul.

## Périmètres et limites

- Pour moi et Radar conservent leur périmètre ; un Radar vide ne bascule jamais vers Tous.
- La lecture de Tous n'active aucune préférence ou marché supplémentaire.
- Des matchs en cours ou terminés restent consultables. Une publication ancienne,
  un match déjà commencé ou un marché interdit ne devient jamais admissible à un nouveau ticket.
- Le détail est lié à la publication recherchée. Une autre version disponible est
  signalée comme indisponible pour cette analyse, sans substitution ; le live est horodaté séparément.
- Les sources existantes déterminent la disponibilité. Une demande peut explorer les
  14 derniers jours et les 13 prochains jours ; cela ne garantit pas une publication pour chacun.
- Par échange : huit contextes de recherche, 3 000 rencontres, 32 consultations,
  dix tours de modèle et un délai de 110 secondes. Les limites sont signalées, pas
  remplacées par des données inventées.
- Le registre est limité à 50 Ko et l'état à 210 Ko. Les échanges les plus anciens
  peuvent être compactés ou supprimés ; les contraintes actives sont conservées.
- Une erreur ou une annulation conserve la session précédente ; les reçus d'appels IA
  sont enregistrés pour les appels effectivement facturables, y compris les réponses incomplètes.

## Vérification et publication

Les tests couvrent les changements successifs de contraintes, une précision de mise,
la continuité dans les deux sports, les collisions d'identifiants, les périmètres vides,
les données historiques/live et les appels de mutation refusés. Le test distant utilise
les deux modèles demandés, des publications synthétiques et aucun compte utilisateur.
Il n'a d'accès réseau qu'à `api.openai.com`.

La publication GitHub vérifie la CI de la révision exacte, puis les conversations
réelles de test avant de déployer uniquement `lector-generator-workshop`. Aucun accès
au trousseau local, aucune migration, aucun collecteur et aucun changement de secret
ne sont requis pour cette mise à jour. Un appel anonyme doit être refusé avec HTTP 401.

## Références OpenAI

- [Function calling](https://developers.openai.com/api/docs/guides/function-calling)
- [Conversation state](https://developers.openai.com/api/docs/guides/conversation-state)
