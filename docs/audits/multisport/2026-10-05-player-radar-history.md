# Radar joueurs : historique et fenêtre récente

Date : 5 octobre 2026. Branche : `codex/multisport-hockey`.
Changements locaux, sans publication de la démo ou de la production.

## Problème constaté

Le hockey conservait uniquement les trois derniers matchs dans les profils
joueurs. Le lecteur public et le classement attendaient eux aussi trois matchs.
La matrice affichait donc uniquement trois cases : aucun historique « Avant »,
et aucune série ne pouvait dépasser trois matchs.

Ajouter des cases ne suffisait pas : étendre les profils sans changer les
compteurs aurait additionné les buts et passes de toute la saison pour déterminer
les joueurs actuellement chauds.

## Règles communes et données propres au sport

La politique temporelle est centralisée dans
`lib/core/domain/lector_player_form_policy.dart` et utilisée par les deux sports.

| Mesure | Règle |
| --- | --- |
| Fenêtre récente | Les trois derniers matchs de l'équipe, dans leur ordre chronologique. |
| Qualification | Au moins deux contributions cumulées dans ces trois matchs. Deux contributions dans un seul match peuvent suffire. |
| Compteurs récents | Buts, passes et nombre de matchs décisifs sur ces trois matchs seulement. |
| Série en cours | Nombre de matchs consécutifs avec contribution, en remontant depuis le dernier match dans tout l'historique disponible. |
| Ordre du Radar | Matchs récents décisifs, puis série en cours, puis volume récent de contributions, puis nom. |

Le football conserve ses données et ses règles de présence. Pour le hockey,
les contributions sont les buts et passes décisives des événements validés.
Les événements ne permettent pas de déduire la titularisation, l'absence ou le
temps de glace individuel. Un zéro signifie zéro contribution vérifiée,
pas une absence du joueur.

Les minutes affichées dans le Radar football sont complémentaires ; le code
n'impose pas 270 minutes comme seuil d'admission. On ne transpose donc pas
270 minutes, ni trois fois 60 minutes, au hockey.

## Collecte et validation

- Réutilisation des rencontres de saison déjà collectées, sans limiter
  l'historique joueur aux cinq résultats de la forme équipe.
- Collecte des événements une fois par rencontre, partagée entre adversaires
  et joueurs, avec le cache existant : une heure pour les rencontres récentes,
  trente jours pour les anciennes.
- Le décompte des buts des événements doit correspondre au score final.
  Le point décisif des tirs au but n'est pas traité comme un but de joueur.
- Les trois derniers matchs doivent correspondre aux données de forme de
  l'équipe : identifiant, date, adversaire, lieu, score et statut.
- Le lecteur public valide également le reste de l'historique contre la
  référence de l'équipe incluse dans la couverture du snapshot.
- Les snapshots précédents à trois matchs restent lisibles.

Si les contributions d'un des trois derniers matchs sont inconnues, l'équipe
ne peut pas fournir un classement joueurs fiable. On ne remplace pas ce match
par un match plus ancien.

Une donnée ancienne manquante reste inconnue (`null`, case `?`), sans devenir
zéro. Elle interrompt la preuve d'une série : une série qui atteint cette
frontière est présentée comme « série ≥ N ».

L'historique est celui de la saison collectée et de la phase vérifiée. Il ne
représente ni toutes les saisons passées ni une garantie que le fournisseur
dispose des événements de chaque rencontre.

## Présentation commune

La matrice partagée conserve les trois matchs récents à droite, avec la même
séparation et les mêmes libellés pour les deux sports. L'historique plus ancien
est consultable par défilement horizontal dans la zone « Avant » ; il n'est
pas supprimé lorsque la largeur de l'écran diminue.

Les cartes de rencontre et la page Radar utilisent cette même matrice.
L'aperçu de carte reste limité aux trois joueurs les plus chauds, avec accès
au reste de la liste.

## Vérification sur la collecte locale réelle

Le complément des événements historiques a consommé **198 appels API** lors
de cette exécution, avec réservation de quota, attente et reprise en cas de
limite par minute. Ce coût est celui du complément initial, pas une estimation
de coût journalier : les appels suivants réutilisent le cache.

La publication locale contient ensuite :

- 900 profils de joueurs ;
- 433 joueurs qualifiés, exactement les mêmes identités avant et après
  l'extension de l'historique ;
- jusqu'à 13 matchs par profil ;
- 17 joueurs qualifiés avec une série vérifiée supérieure à trois matchs ;
- 118 lignes anciennes joueur/match dont les contributions restent inconnues.

Exemple : A. Lunsjo (Chamonix Mont-Blanc) possède huit matchs d'historique,
trois matchs récents décisifs, une série de sept matchs et quatre contributions
sur les trois derniers matchs. L. Elvenes (Vaxjo) possède six matchs d'historique,
une série de six matchs et huit contributions récentes.

Le calendrier, les scores, les confrontations et les classements de cette
publication ont été conservés ; le mode `--players-only` complète uniquement
les profils et leur couverture. Il n'ouvre pas de serveur supplémentaire.

## Tests

- Huit tests Deno couvrent la collecte, les événements incomplets, les tirs au
  but, les erreurs fournisseur, la déduplication des appels et la conservation
  de l'historique avant les trois matchs récents.
- Trente-deux tests Flutter couvrent les profils hockey, le classement football,
  les cartes communes et les pages Radar football et hockey.
- Des tests du lecteur public rejettent les historiques décalés, les valeurs
  impossibles et les contributions récentes inconnues.
- Les tests de calcul vérifient qu'un joueur anciennement performant ne peut
  pas se qualifier avec ses anciens buts, qu'une série peut dépasser trois
  matchs et qu'une donnée inconnue ne prolonge pas artificiellement une série.
- Les tests de widgets utilisent notamment un historique de trente matchs et
  une extraction réelle de la collecte, à 360 et 1100 pixels, pour vérifier
  l'historique, la séparation et l'absence de débordement.

Extraction publique réelle, sans secrets :
`test/fixtures/sports/hockey_player_history_compact.json`.

`flutter analyze --no-pub` : aucun diagnostic. `git diff --check` : réussi.
