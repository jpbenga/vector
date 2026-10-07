# Générateur Lector — première version conversationnelle

## Périmètre et architecture

Le Générateur utilise une page Flutter commune aux deux sports. Il ouvre les
fiches de match existantes via la composition de l’application. Le modèle reçoit
la demande, le contexte actif et une mémoire courte. Il renvoie une intention
JSON ; le serveur construit les compositions et leurs explications factuelles.
Les cotes, rencontres et justifications ne viennent jamais du modèle.

La préparation à l’ouverture lit les snapshots sans appeler OpenAI. Les
générations nécessitent un compte connecté. Une nouvelle génération utilise la
configuration effective ; une révision utilise la configuration figée du ticket.
Le retour au profil enregistré exige une confirmation. Les préférences
permanentes ne sont pas modifiées par la conversation.

## Audit de couverture

| Donnée | Football | Hockey | Utilisation dans cette version |
|---|---|---|---|
| Configuration | Profil compilé ou Explorateur effectif | Préférences locales propres au hockey | Copie figée dans chaque ticket ; contextes séparés |
| Scénarios | Préférences et scénarios calculés dans les analyses serveur | Pas de catalogue de scénarios équivalent publié | Scénarios football retenus avec leurs lectures sources, sans preuve supplémentaire |
| Rencontres | Snapshots d’analyse, IDs API, statut et horaire | Publications sportives, IDs propres au sport | Date dans le fuseau du contexte, calendrier de 14 jours ; pré-match uniquement |
| Lectures | Calculées et publiées côté serveur, échantillons et preuves | Calculées par le module hockey ; pas encore toutes exposées comme preuves serveur | Seules les preuves serveur vérifiables autorisent une composition |
| Radar joueurs | Activité publiée, buts, passes et historique | Activité publiée, buts et passes ; temps de glace absent | Trois matchs documentés, au plus trois joueurs par opposition ; complément descriptif |
| Radar équipes | Lectures de trajectoire publiées | Historique récent des oppositions | Source de contexte ; les mêmes résultats ne comptent pas deux fois |
| Bilan | RPC existante, confirmations et effectifs | Pas de Bilan équivalent | Observation sur 90 jours par lecture et championnat ; pas de précision prédictive |
| Marchés et cotes | Cotes bookmaker horodatées dans les snapshots | Non collectées dans les publications actuelles ; pas de préférence marchés permanente | Football : résultat, double chance, total 2,5 buts, BTTS ; aucune cote hockey inventée |
| Historisation | Références des snapshots d’analyse | Référence de publication | Source, cote et date conservées avec le ticket |
| Brouillons | Ancien parcours manuel conservé | Nouvelle page commune | Conversations privées côté serveur, versions et confirmation des modifications |

Une donnée inconnue reste inconnue. Un joueur sans trois contributions connues
n’entre pas dans les suggestions décisives. Une cote absente n’est jamais zéro.
La découverte autorise les compétitions hors des habitudes, tout en respectant
les lectures et marchés autorisés. Le mode strict filtre les compétitions.

### Limites réelles de cette première version

- Les tickets hockey et multisports nécessitent encore une collecte des marchés
  et cotes hockey, des préférences correspondantes et un adaptateur de preuves
  hockey côté serveur. Un ticket explicitement multisport n’est pas remplacé
  silencieusement par un ticket football.
- Les marchés joueurs, corners, cartons, totaux d’équipe et live ne sont pas
  composés automatiquement par ce nouvel adaptateur. Le parcours manuel existant
  reste accessible.
- Le modèle interprète le texte. Les explications utilisent directement les
  preuves publiées ; l’enrichissement rédactionnel par IA n’est pas activé.
- Voix, programmation quotidienne et découverte de patterns statistiques sont
  les étapes suivantes du document utilisateur, hors de cette V1.

## Contrat du service

`POST /functions/v1/lector-generator`, avec une session Supabase valide.

| Action | Effet | Appel IA |
|---|---|---|
| `prepare` | Compte les rencontres/signaux pertinents et indique les manques | Non |
| `chat` | Interprète, vérifie et propose des compositions ou une clarification | Un |
| `apply` | Revérifie les sélections en attente puis applique une version | Non |
| `save` | Enregistre le brouillon privé | Non |
| `read` | Recharge une conversation appartenant au compte | Non |
| `history` | Liste les 20 brouillons enregistrés les plus récents | Non |

Le client transmet un identifiant de conversation, sa révision, un identifiant
de demande unique, une date et un contexte. Les prix et preuves sont relus par
le serveur. Une demande dupliquée réutilise le résultat ; deux fenêtres ne
peuvent pas modifier silencieusement la même révision.

L’intention précise l’action, la date, les sports, les mises et objectifs par
ticket, la distinction retour total/bénéfice net, les index ciblés, les marchés
explicitement demandés et les contraintes de diversification. Les montants
absents restent absents. Un objectif ambigu déclenche une clarification.

## Règles de composition

- Au plus quatre tickets et six sélections par ticket.
- Une sélection par rencontre, un bookmaker commun dans chaque ticket, aucune
  même équipe dans deux sélections du même ticket.
- Diversification entre tickets quand elle est demandée.
- Plafond de mise affiché et vérifié ; aucune hausse de mise proposée pour
  atteindre un retour. Les montants sont calculés en centimes.
- Publications de moins de 36 h et cotes datées de moins de 48 h ; seules les
  rencontres non commencées sont utilisées.
- Les contradictions connues bloquent le candidat ; Radar et scénarios ne
  multiplient pas les preuves issues de la même série.
- Recherche bornée à 24 oppositions, 12 possibilités par opposition et 16 000
  essais. Un résultat absent peut aussi signaler cette limite de recherche ;
  ce n’est pas une preuve qu’aucune combinaison mathématique n’existe.
- Une révision conserve les autres sélections et les mises ; elle attend une
  confirmation. Les compositions ne sont jamais envoyées à un bookmaker.

## Clé et enveloppe de tests

La clé `OPENAI_API_KEY` est un secret GitHub puis un secret de la fonction
Supabase. Elle n’entre pas dans Flutter, Vercel ou les fichiers publics.
`store:false` est envoyé à Responses ; il ne constitue pas une affirmation de
conservation zéro de toutes les données chez le fournisseur.

Les modèles d’essai sont GPT-4.1 mini et nano dans leurs versions datées. Les
sorties sont structurées et revérifiées. Une requête est bornée à 32 000 octets
et 1 800 tokens de sortie. Le service réserve **0,025 $ par appel**, y compris
les échecs, dans une **enveloppe cumulative de 3 $ sans remise à zéro**. Ce
montant est une réservation conservatrice, pas le montant facturé. Les tests
réels des modèles utilisent la même enveloppe. Le choix final dépend du test.

Pour la démo : **5 appels IA par compte et par jour**, **20 pour l’ensemble de
la démo par jour**, au moins 10 secondes entre demandes. Cette enveloppe couvre
uniquement ces appels Lector, pas d’autres usages de la clé ou du compte OpenAI.
L’utilisateur a indiqué disposer de 6 € ; la marge reste disponible pour les
essais et les usages extérieurs. Aucun budget mensuel récurrent n’est fixé.

Références officielles, vérifiées le 8 octobre 2026 :
[modèle et prix mini](https://developers.openai.com/api/docs/models/gpt-4.1-mini),
[sorties structurées](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses).

## Installation distante

Le workflow existant `deploy-supabase.yml` reçoit l’option
`lector-generator-demo`, uniquement sur `codex/multisport-hockey`. Il vérifie la
CI du commit exact, installe **uniquement** `20261008120000_lector_generator.sql`,
teste les modèles, configure les secrets, déploie `lector-generator`, vérifie le
refus d’un appel anonyme et active les demandes IA.

La migration crée des tables privées et trois RPC réservées au serveur. Aucun
cron ni collecte sportive n’est ajouté. Le projet Supabase est partagé avec la
production ; cette installation ajoute le service de brouillons, sans remplacer
les fonctions football ou hockey. La vérification JWT de passerelle est
désactivée pour ce endpoint : le handler vérifie obligatoirement la session via
Supabase Auth avant toute lecture privée ou réservation d’appel.

Le frontend est activé par `LECTOR_GENERATOR_UI=true` dans le build démo. Le
build de production garde le parcours précédent. Il n’y a pas de merge de la
branche multisport vers main dans cette livraison.

Arrêt immédiat : passer le secret serveur `LECTOR_GENERATOR_ENABLED` à `false`.
Une nouvelle enveloppe de tests doit être autorisée explicitement puis inscrite
dans la ligne `lector_generator_budget` ; elle n’est pas augmentée par le chat.
