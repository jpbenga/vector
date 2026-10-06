# Diagnostic live de la démo — 6 octobre

Vérifications en lecture seule, avec la configuration publique Supabase. Aucun
déploiement, activation, cycle fournisseur ou changement de production.

## Hockey

Le transport actuellement compilé lit `public.sport_live_states`. La requête
publique renvoie HTTP 404 / PGRST205 : table absente du cache de schéma. Cela
confirme que le service attendu par la démo n'est pas disponible. Le rapport
`2026-10-05-detail-parity-hockey-live.md` indiquait déjà que migration et fonction
étaient préparées, mais leur installation/activation restait en attente.
Le compact intégré est une collecte ponctuelle, pas un flux live.

## Football

Les lectures publiques de `match_live_states` et la RPC
`match_live_for_fixtures` réussissent. La RPC renvoie notamment Russie–Nigeria,
Algérie–Niger et Jordanie–Venezuela en cours, avec des scores/minutes qui ont
avancé entre les deux lectures. Dernière collecte contrôlée : 17:21:00 UTC,
contre 17:21:33 UTC dans l'en-tête Date du serveur. Le collecteur football tourne.

Pour ces trois exemples, le calendrier est le problème identifié : le dernier
snapshot spécifique à la ligue 10 trouvé en base couvre le 27–30 septembre,
et ne contient aucun de leurs identifiants. Les 500 métadonnées les plus récentes
(la limite du chargeur client) ne contiennent aucun snapshot de la ligue 10.
Toutes ces lignes ont scope=league, sans publication globale de remplacement.
`LiveMatchListBuilder` observe seulement les identifiants déjà présents dans le
flux calendrier : il ne peut donc pas créer les cartes des rencontres absentes.
Ce cas n'établit pas la cause de toute absence de live dans toutes les ligues.

## Limite de vérification distante

L'ouverture de l'alias démo dans le navigateur disponible est redirigée vers
la connexion Vercel. Le rendu de la session distante de l'utilisateur n'a pas
été inspecté. La protection de l'aperçu est conservée. Aucun accès au trousseau.

## Maquette compacte

Image uniquement, sans changement des widgets : deux tableaux complets côte à
côte, une ligne par équipe, colonnes rang/logo/nom/J/Pts, sans sous-lignes de
résultats ou points par match. J représente le nombre de matchs joués.
Les cartes Position et Repère commun restent présentes.
Image : `exec-65c10687-45fa-4e8a-8c73-59df887f6506.png` dans les images générées
de cette conversation. Données illustratives.

## Intégration et installation (itération suivante)

Les deux tableaux côte à côte utilisent désormais le renderer commun
`LectorStandingDataTable`, en mode compact à toutes les largeurs : rang, fanion,
nom sur une ligne, J et Pts. Une ligne mesure au maximum 32 px dans les tests
360 et 1100 px. Les surlignages sont plats, avec un rail de couleur ; les cartes
Position et Repère commun, les scopes général/domicile/extérieur et les vues
complètes sont conservés. Une opposition dans le même groupe reste un tableau
unique. Aucun changement des paramètres par défaut du tableau football.

### Live hockey installé et vérifié

Accord explicite de l’utilisateur obtenu pour la migration
`20261005180000_hockey_live_collection.sql`, `sync-hockey-live`, authentification
par secret serveur avec JWT de passerelle désactivé, puis activation à la minute.
Migration installée par SQL Editor et fonction déployée dans le projet
`ednvvxxvlawaagjyshkj`. Cron `lector-hockey-live` actif. Passages constatés
17:48, 17:49 et 17:50 UTC le 6 octobre : succeeded, 2 appels, 20 rencontres,
sans erreur. Deux requêtes groupées par minute, donc environ 2880/jour plus
24 appels de récupération horaires, sous le plafond live 3000/jour. Le budget
global contrôlé est 7500/jour. La collecte des calendriers et analyses complètes
reste distincte ; le compact de base de la démo est daté du 5 octobre.

La vérification dans l’application a révélé un décalage de trois heures entre
l’horloge locale et le serveur. Le transport et le contrôleur utilisent désormais
l’heure HTTP Date de Supabase pour vérifier les timestamps des scores. Les
contrôles sport/identité/saison, l’ordre des versions et la non-régression d’un
résultat final restent actifs. Un test vérifie une horloge décalée et le refus
d’un score futur par rapport au serveur. Le header Date est exposé en CORS
par PostgREST. Contrôle réel mobile : Tous → Live, Cherepovets–SKA, score 4–2,
pause en cours, badge rouge, filtres Live/Terminés ; aucune erreur de transport.

### Calendrier football

Les runs de collecte de la ligue 10 ont plusieurs échecs de dépassement de
fenêtre et un run resté running. Le calendrier du 6 octobre était néanmoins
présent en cache (18 rencontres du jour, 789 sur la saison). Un premier appel
au constructeur existant a échoué HTTP 546 WORKER_RESOURCE_LIMIT.

Correction de `build-match-feed-snapshot` : lectures du cache joueurs/statistiques
par groupes de 25 identités, avec pagination PostgREST complète et cache local
à chaque requête. Les sélections exactes, erreurs fournisseur, provenance et
identités sont conservées. Aucun appel API-Football ajouté. Les données sont
les données réelles du cache ; aucun timestamp de fraîcheur forcé.
Fonction déployée dans Supabase avec son authentification existante.
Le nouvel appel a réussi HTTP 200 : snapshot
`be978646-4d33-4326-880f-e08c4680e206`, 22 rencontres sur le 6–19 octobre,
12 entrées de cotes, as_of `2026-10-06T08:13:35.901+00:00`.
Cela ne prétend pas résoudre chaque interruption antérieure du collecteur.

### Démo et validations

Build release réussi. Déploiement Vercel preview READY
`dpl_FmgHeQ67K3FAeZZXTEWGVuhWiNst`, alias stable
https://lector-sports-demo-lector1.vercel.app mis à jour. La protection Vercel
existante est conservée. Aucun push/merge multisport sur main.
Tests ciblés des standings, rôles, thèmes, live, dérive d’horloge et contrats
backend réussis ; Deno check du constructeur et tests de regroupement réussis.
Captures de vérification locales : `/tmp/lector-compact-standings-mobile.png`,
`/tmp/lector-hockey-live-mobile.png`, `/tmp/lector-hockey-live-installed.png`.

L’analyse du snapshot restauré a également réussi HTTP 200 :
`a9573853-6be8-4d63-8bea-2457e339df1d`, 22 rencontres et 70 annonces.
Vérification de la même application compilée, mode Football → Tous → Live :
39 rencontres au total, 2 en direct (Algérie–Niger 1–1 à 55′,
Jordanie–Venezuela 0–0 à 56′), 13 à venir et 24 terminées. Les minutes ont
avancé pendant le contrôle. Les snapshots du calendrier restent datés de leur
collecte initiale ; les scores affichés viennent du transport live indépendant.
Captures conservées dans `output/qa/2026-10-06-compact-live/`.

Le correctif serveur football est enregistré sur le chantier multisport local.
Il faudra le conserver lors du prochain déploiement des fonctions depuis main ;
l’installation actuelle ne constitue pas un merge du frontend multisport.
