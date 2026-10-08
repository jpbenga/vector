# Atelier de compositions — itération du 8 octobre 2026

## Périmètre

Le service `lector-generator-workshop` est destiné à la démo multisport. Le
client principal continue d’utiliser `lector-generator`. Le nouveau déploiement
n’installe pas le hockey sur `main` et conserve la réservation et les paramètres
du service précédent.

Cette itération transforme le prototype de l’[audit](composition-workshop-audit-2026-10-08.md)
en parcours fonctionnel : intention structurée, sources relues sur le serveur,
exploration de plusieurs compositions, comparaison, choix puis confirmation.

## Construction et comparaison

- Chaque candidat conserve le marché, le bookmaker, la cote horodatée, le
  snapshot, les lectures qui soutiennent ce marché et les observations adverses.
  Le contexte et le Radar n’ajoutent pas artificiellement un soutien direct.
- Forme et domicile/extérieur sont regroupés conservativement. Le nombre de
  lectures n’est ni une probabilité ni un nombre de preuves indépendantes.
- Le moteur explore un faisceau diversifié : 48 rencontres, quatre bookmakers,
  40 000 expansions et un budget de calcul de 650 ms partagé entre les objectifs.
  Les limites atteintes sont enregistrées. Il ne prétend pas avoir trouvé la
  meilleure composition parmi toutes les possibilités.
- La comparaison utilise le soutien documenté, les vigilances, l’échantillon,
  les redondances, le nombre de conditions, la proximité du retour et la
  concentration de la cote. Ces critères sont des heuristiques ordinales.
- « Autour de » explore une marge annoncée de 10 %. « Au moins » reste un minimum
  explicite ; une fourchette explicite conserve ses deux bornes.
- Au plus trois propositions significativement différentes pour **une seule
  mise**. Il peut n’y en avoir qu’une, ou aucune dans la recherche bornée.
- L’historique inclut toutes les propositions déjà affichées. Une nouvelle cote
  sur les mêmes sélections ne suffit pas à créer un autre ticket.
- Une rencontre peut être réutilisée avec un autre marché. Une demande explicite
  de conserver les rencontres les conserve toutes. Une substitution ciblée garde
  les autres sélections ; un retrait recalcule et indique que l’objectif peut
  ne plus être atteint.
- Le comparateur Flutter affiche les éléments conservés, retirés, ajoutés et les
  changements de marché. Le choix est revérifié sur les cotes serveur.

## Essais des modèles

Les deux modèles demandés sont `gpt-6.1-sol` et `gpt-6-luna`, avec Responses,
sortie structurée stricte, `store:false` et raisonnement `low`.

Le modèle interprète la demande puis sélectionne les arguments factuels à mettre
en avant. Il ne peut ajouter ni sélection, cote, probabilité ou fait à l’analyse.
Les vigilances adverses sont affichées même si le modèle ne les sélectionne pas.
Une analyse IA indisponible laisse les faits accessibles et le signale.

Le protocole GitHub compare huit demandes et une analyse de compositions sur
les mêmes entrées synthétiques figées : 18 appels tentés, sans compte personnel,
collecte sportive ou enregistrement de ticket. Les cas comprennent clarification,
objectif approximatif/minimal, autre ticket, mêmes rencontres/autres marchés et
moins de rencontres. Le premier modèle de la paire passant toutes les portes du
contrat devient le choix initial de la démo ; ce n’est pas une conclusion de
qualité ou de coût sur l’usage réel.

La comparaison peut ensuite rester active en démo : un modèle répond et l’autre
est observé sur les mêmes entrées. Une génération avec analyse implique alors
jusqu’à quatre appels ; une clarification, deux. La recherche combinatoire ne
fait aucun appel IA. Les appels payants ne sont pas retentés automatiquement.

Chaque appel conserve modèle demandé/retourné, identifiant de réponse, état,
durée et tokens d’entrée, cache, sortie et raisonnement. Les tokens de
raisonnement font déjà partie des tokens de sortie et ne sont pas additionnés
une seconde fois. Les coûts sont une estimation USD selon le tarif standard,
avec une fourchette quand le fournisseur ne détaille pas les écritures du cache.
Un usage non retourné reste inconnu. Ce journal n’est pas la facture OpenAI.

La nouvelle réservation n’applique pas de crédits ni de plafond financier de
tests. Elle garde l’isolation des comptes, la réutilisation des demandes déjà
traitées, la protection des révisions et des appels concurrents, ainsi qu’un
intervalle technique d’une seconde. Les anciens plafonds et leur compteur restent sur l’ancien
service. Aucun abonnement ou compteur commercial n’est ajouté.

## Limites encore présentes

- L’indépendance statistique des signaux n’est pas démontrée. Les fenêtres et les
  identifiants exacts des matchs sources ne sont utilisés que s’ils sont publiés.
- Les vigilances couvrent les règles de marché actuellement reconnues ; il ne
  s’agit pas d’une matrice exhaustive de contradictions.
- Le Bilan reste descriptif. Les cohortes comparables par sport, marché,
  domicile/extérieur et robustesse ne sont pas encore construites.
- Les sources refusées dans la recherche sont comptées par motif ; le catalogue
  initial ne conserve pas encore le journal de tous ses rejets.
- Les publications hockey ne contiennent pas encore les marchés/cotes et les
  préférences correspondantes nécessaires au Générateur. Aucun ticket hockey
  fictif et aucune substitution silencieuse vers le football.

## Vérification et publication

Les tests couvrent contrats, alternatives, corrélation, vigilance, modification
ciblée, reprises idempotentes, isolation SQL et affichage à 320 px. La compilation
web utilise uniquement les paramètres publics Supabase.

Le rejeu local d’une publication publique du samedi 10 octobre (instant figé au
8 octobre à 12:00 UTC) vérifie aussi le budget de calcul sur une journée chargée :
2 412 lignes candidates, 111 rencontres admissibles. Avec 50 € de mise,
l’objectif « autour de 300 € » donne trois propositions à 300,26 / 312,50 /
303,75 € ; celui « autour de 500 € » à 497,25 / 506,25 / 511,40 €. Le traitement
complet local prend environ 0,9 seconde ; les plafonds de temps, rencontres et
bookmakers sont atteints. Ces chiffres ne sont ni des mesures réseau ni une
reconstruction du profil personnel. La proposition à 312,50 € ne contient
qu’une rencontre : son apport à la cote est donc entièrement concentré, ce qui
doit être explicité et ne la rend pas plus sûre.

Le déploiement GitHub `lector-generator-workshop` exige la CI réussie du commit
exact sur `codex/multisport-hockey`, installe la migration append-only
`20261008210000_lector_generator_workshop.sql`, exécute le protocole payant avec
le secret GitHub, déploie le service et vérifie le rejet des appels anonymes.
L’authentification Supabase est vérifiée dans le handler avant tout appel IA.
Les secrets sont utilisés dans GitHub et ne sont pas intégrés dans le client.

Le résultat des essais est livré comme artefact GitHub
`lector-generator-model-comparison` ; les tokens, coûts et durées doivent être
lus dans cet artefact avant de conclure sur le modèle.

Références : [GPT-6.1 Sol](https://developers.openai.com/api/docs/models/gpt-6.1-sol),
[GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna),
[Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs?api-mode=responses).
