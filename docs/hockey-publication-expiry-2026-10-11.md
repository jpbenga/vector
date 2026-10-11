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
