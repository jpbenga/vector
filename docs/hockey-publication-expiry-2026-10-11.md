# Écran hockey vide à l’expiration de la publication

Le 11 octobre à 02:14, l’écran indique « La collecte hockey doit être
actualisée ». L’incident est également reproduit dans Tous, sans préférences
de compte.

Le lecteur public renvoie 42 rencontres pour le 11 octobre, dans une
publication de 500 rencontres et sept ligues. Mais sa date réelle est le
9 octobre à 12:04 UTC : elle vient de dépasser les 36 heures autorisées par
`ValidatedSportFeedRepository`. La navigation fonctionne ; le validateur
masque les rencontres. Le Générateur n’est pas à l’origine de ce blocage.

Le cache CDN et le lecteur Supabase renvoient la même version. Changer de
source ou recharger le navigateur ne renouvelle donc pas les données.
Les collecteurs récurrents de scores et de cotes sont distincts de la
publication analytique : leur fonctionnement ne rend pas cette dernière
plus récente.

## Remise en service

Effectuer une vraie collecte des sept ligues, recalculer les lectures avec
le moteur Dart commun à l’écran, puis publier et vérifier le document
partagé. Renouveler les fichiers de livraison hockey de la démo à partir
de cette même version. Ne jamais modifier artificiellement `capturedAt`
et ne pas augmenter la limite de 36 heures pour masquer l’incident.

`build_multisport_demo.py --refresh-hockey-delivery` permet ce renouvellement
sur une application déjà compilée. Il ne change pas le programme Flutter
ni la livraison football. Le contrôle vérifie aussi `baseCapturedAt` :
une simple mise à jour d’enrichissement ne peut dissimuler un calendrier
ancien. Les fichiers immuables utilisent un nouvel identifiant de contenu.

## Limite restante

Ce contrôle empêche de livrer un hockey déjà périmé. Il n’est pas un
planificateur : le renouvellement complet doit être exécuté régulièrement
côté serveur, indépendamment de l’ouverture de l’application et du Mac
local. Le collecteur complet actuel est `tool/sports/nhl_local.ts` ; le
collecteur cloud initial `collect-sport-feed` ne couvre que la NHL et ne
remplace pas la publication enrichie des sept ligues. Ne pas présenter une
collecte ponctuelle comme la résolution de cette planification.

Les tests de santé couvrent la date exacte de l’incident, la limite de
36 heures, une base périmée avec enrichissement récent, les horodatages
invalides ou futurs et le jour civil de Paris.

## Collecte et second blocage constatés

La collecte réelle du 11 octobre est terminée : 503 rencontres, sept ligues,
du 4 au 24 octobre, 822 appels fournisseur réservés dans le quota partagé.
`capturedAt` vaut `2026-10-11T00:18:30.281Z` et la base réelle
`2026-10-11T00:18:18.093Z`. Aucun appel OpenAI n’est effectué.

Le recalcul Dart des lectures réussit. La publication échoue en revanche
avec HTTP 500, code PostgreSQL `57014`. La limite du rôle `service_role`
est de 30 secondes. La publication canonique du 9 octobre reste intacte.

La correction `20261011011500_hockey_publication_materialization.sql`
matérialise les deux documents JSON avant les accès répétés et extrait
les compétitions une seule fois avant la boucle de validation. Les règles
de validation, l’immutabilité, les tables et les droits restent identiques.
Elle est distincte de la migration de lecteurs du 10 octobre en attente.

Un test exécuté dans une transaction annulée accepte 503 identités valides,
rejette les doublons, rejette une équipe jouant contre elle-même et rejette
une publication football. Aucun document de test ni remplacement de fonction
n’est conservé après ce test.

La revue automatique refuse ensuite l’installation permanente : remplacement
d’une fonction dans le projet partagé de production sans autorisation explicite.
L’autorisation précise a été demandée. À ce stade, la collecte fraîche existe
localement ; ne pas annoncer que la démo ou le serveur la diffusent déjà.

## Reprise et traitement Radar

Après l’instruction « continue », la migration de publication du 11 octobre
est installée. Vérification : `anonymous_write=false`, `user_write=false`,
`server_write=true`, `public_read=true`.

La publication complète échoue encore avec HTTP 500. Le traitement déclenché
par l’insertion prépare les snapshots Radar avant match. Sa fonction
`form_radar_record_publication` parcourt tous les profils pour chaque rencontre.
Le test précédent sans profils joueurs ne couvrait pas cette charge réelle.

La correction `20261011012500_hockey_radar_publication_index.sql` construit
une indexation par équipe, compétition et saison pour le hockey, une seule
fois par publication. L’ordre des profils dans chaque groupe est conservé.
La suite des critères reste identique, comme le parcours football. Aucun
nouveau privilège, table ou point d’accès n’est introduit.

Le test dans une transaction annulée utilise la publication réelle du serveur.
Il compare les profils avant et après optimisation sur une rencontre à venir
par compétition. Les snapshots sont identiques. Le traitement optimisé de
l’ensemble de 500 rencontres et 882 profils prend 1,156 seconde.
La lecture publique des cotes pour ces 500 rencontres réussit en 4,83 secondes.

La revue automatique refuse l’installation de cette seconde migration, estimant
qu’elle n’est pas couverte par l’autorisation de la première. Une autorisation
explicite et distincte a été demandée. Elle n’est pas encore installée ; la
publication du 9 octobre reste la version publique au moment de ce compte rendu.

## Autorisation et reprise du 11 octobre

L’autorisation explicite de la seconde correction est reçue. La migration
Radar est installée : écriture anonyme et utilisateur refusée, écriture
serveur autorisée. Les publications volumineuses rencontrent encore deux
limites distinctes : préparation SQL avec de gros arguments JSON et expansion
RPC de deux documents nommés.

`20261011013500_hockey_publication_generic_plan.sql` limite la préparation
aux plans génériques, uniquement pendant la publication. Un test sur le
document réel du serveur, insertion et trigger Radar inclus, prend 2,015 s.
Toutes les écritures et le réglage temporaire du test sont annulés.

`20261011014500_hockey_publication_document_rpc.sql` ajoute un relais à
argument JSONB non nommé, selon le protocole de corps brut de PostgREST.
Il délègue toutes les validations et écritures à la fonction existante.
Il n’est accessible qu’à `service_role`. Les appels anonymes au relais et
au collecteur sont vérifiés et refusés avec HTTP 401. Le pont Edge est déployé
avec uniquement le chemin de ce relais modifié.

La publication du 11 octobre est maintenant enregistrée dans Supabase :
503 rencontres, sept ligues, collection
`b087efc0-31af-449a-94de-0233900d5081`. La vérification de son document complet
contre les données préparées réussit. La lecture des cotes via la projection
Radar dépasse encore son délai : la préparation de la livraison démo n’est
pas annoncée comme terminée à ce stade.

## Lecture des cotes rétablie

La migration `20261011015500_hockey_public_read_materialization.sql` remplace
la correction de lecteur préparée mais non installée du 10 octobre. Elle
matérialise les valeurs JSON une seule fois, utilise des plans génériques et
préserve les mêmes identités, l’ordre des rencontres, la jointure des cotes
et les droits. Le lecteur public reste autorisé ; l’accès anonyme à la table
de cotes et à son helper brut reste refusé.

Un contrôle en transaction annulée vérifie Radar, journée et détail. Il
vérifie aussi chaque cote contre les cinq identifiants de la rencontre et
l’heure du coup d’envoi. La journée du 11 octobre contient 42 rencontres et
2 059 cotes. La vérification HTTP publique du document complet et de sa
projection cotée réussit ensuite en 9,57 s au total : 503 rencontres et
5 156 cotes, identité de collection et contenu analytique identiques.
La copie locale vérifiée conserve `capturedAt=2026-10-11T00:18:30.281Z` ;
aucun horodatage artificiel ni allongement des 36 heures.

## Délai public et nouvelle livraison

La lecture publique cotée réussissait parfois, mais restait interrompue par
le délai anonyme de trois secondes. La migration
`20261011020500_hockey_public_reader_deadline.sql` réserve huit secondes
à la seule RPC `read_sport_feed`. PostgREST applique ce réglage au début
de la transaction. Les limites des rôles restent identiques : anon 3 s,
authenticated 8 s, service_role 30 s. Les permissions restent identiques.
Référence : https://supabase.com/docs/guides/database/postgres/timeouts

Après installation et rechargement du schéma, les contrôles HTTP anonymes
réussissent : journée du 11 octobre, 42 rencontres en 1,43 s ; Radar complet,
503 rencontres en 2,56 s. Ces mesures ponctuelles ne sont pas une garantie
de latence. La reconstruction hockey réussit ensuite avec vérification
du document canonique et des cotes sur le serveur. Elle contient
5 156 cotes, dont 2 059 pour le 11 octobre, et 28 lectures pour cette journée.
Les empreintes des 1 651 fichiers de l’interface compilée et du football
restent identiques. Dix tests Python ciblés passent (six sur les contrôles
de publication, quatre sur la fraîcheur).

La collecte complète récurrente reste un chantier distinct. Les collecteurs
de live et de cotes existants ne remplacent pas ce renouvellement. Cette
réparation ponctuelle et les contrôles de publication ne suffisent donc pas
à garantir automatiquement une nouvelle collecte avant la prochaine
expiration des 36 heures.
