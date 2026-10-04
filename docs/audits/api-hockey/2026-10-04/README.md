# Audit réel API hockey — 4 octobre 2026

Branche locale : `codex/multisport-hockey`. Cet audit ne branche pas encore le
collecteur hockey sur Supabase et ne modifie pas les lectures en production.

## Accès et budget

La clé existante fonctionne avec `https://v1.hockey.api-sports.io`, via
`x-apisports-key`. L'API confirme un abonnement Pro actif, 7 500 appels/jour,
et une limite de 300 appels/minute. La clé reste côté serveur/local.

**10 requêtes HTTP envoyées** : deux contrôles de statut, sept appels de données
réussis et un contrôle de point d'accès inexistant. Cela représente au maximum
0,134 % du budget journalier si les dix appels sont décomptés. Le compteur
`requests.current` renvoie zéro aux deux contrôles ; les en-têtes journaliers
ne sont pas cohérents entre les deux minutes. Le nombre exactement facturé
n'est donc pas établi. L'orchestrateur devra compter ses réservations localement
et conserver une marge, sans dépendre exclusivement de ces en-têtes.

Le journal `calls.json` précise les URL relatives, heures UTC, statuts HTTP,
erreurs et en-têtes de quota. Les fichiers de statut excluent les informations
du compte et la date de fin de l'abonnement. Aucun secret n'est enregistré ici.

## Match examiné

L'API identifie la NHL par **57**, la saison actuelle par **2026**.
La recherche du 3 octobre UTC renvoie 11 rencontres terminées.

Exemple approfondi : **Winnipeg Jets – Boston Bruins**, match **444616**,
3 octobre 2026 à 00:00 UTC, soit 02:00 à Paris.

- Score final : **3–4**, statut `AOT` (« After Over Time »).
- Périodes : `1–2`, `2–0`, `0–1` ; score à 60 minutes : **3–3**.
- Prolongation : `0–1`.
- 16 événements : **7 buts et 9 pénalités**.
- Buts avec noms des joueurs, passes décisives, période et minute.
- Un but de Winnipeg porte le commentaire `Power-play`.
- Les buts des événements correspondent aux scores par période et au score final.

Ces observations décrivent les réponses du fournisseur ; ce premier échantillon
ne constitue pas une validation indépendante de toute sa couverture NHL.

## Statistiques réellement présentes

| Source | Champs observés | Limites |
| --- | --- | --- |
| `games` | Horaire UTC, équipes/IDs/logos, score final, périodes, OT, tirs au but (`penalties`), statut, disponibilité des événements | Aucune phase explicite dans les matchs examinés ; valeurs nulles possibles |
| `games/events` | Équipe, type but/pénalité, période, minute, joueurs, assists, commentaire | Joueurs sous forme de noms sans ID ; pas de secondes, durée de pénalité, tirs, arrêts ou temps de glace dans cet exemple |
| `teams/statistics` | Matchs, victoires/défaites, buts pour/contre, moyennes et pourcentages ; total/domicile/extérieur | Agrégats de saison incluant plusieurs phases ; réponse objet, pourcentages et moyennes sous forme de chaînes |
| `standings` | Phase, groupe, rang, matchs, points, buts, victoires/défaites avec distinction OT | Plusieurs lignes par équipe selon division/conférence ; `form` nul ; certains pourcentages contredisent les compteurs |

Le contrôle ciblé de `games/statistics?game=444616` répond HTTP 200 avec
`errors.endpoint = "This endpoint do not exist."`. Un adaptateur doit donc
vérifier **aussi le champ errors**, pas seulement le statut HTTP.

Aucun tir cadré, pourcentage d'arrêts, gardien titulaire, temps de glace,
xG ou taux PP/PK complet n'est présent dans les réponses examinées. Cela
ne prouve pas leur absence chez toutes les sources ou tous les endpoints.
On ne peut pas promettre les lectures correspondantes avec ces seules données.
Un but `Power-play` ne suffit pas à calculer un taux d'efficacité : il manque
notamment les opportunités de supériorité numérique.

## Piège confirmé : mélange des phases

Pour Winnipeg :

- `teams/statistics` : **5 matchs**, 11 buts marqués, 17 encaissés.
- `standings`, `NHL - Regular Season` : **1 match**, 3 buts marqués, 4 encaissés.
- `standings`, `NHL - Pre-season` : **4 matchs**, 8 buts marqués, 13 encaissés.
- L'historique d'équipe contient les cinq matchs terminés, sans champ de phase.

Les sommes se réconcilient : l'agrégat cumule les deux phases. Boston présente
le même problème : sept matchs dans les statistiques, trois en saison régulière
et quatre en présaison. **Ne pas utiliser ces agrégats pour une lecture limitée
à la saison régulière.** Il faudra classifier les matchs avec une source de
phase fiable ; l'ID, un seuil de date arbitraire ou le nombre de matchs ne sont
pas une règle acceptable. Tant que la phase est inconnue, ne pas les intégrer
aux fenêtres analytiques de saison régulière.

Autre exemple : Winnipeg a une défaite OT sur un match de saison régulière,
mais `lose_overtime.percentage` vaut `0.000`. Calculer les ratios à partir
des compteurs cohérents ; ne pas réutiliser aveuglément les chaînes fournies.
Comparer les rangs uniquement dans un groupe déclaré, en dédupliquant les
représentations conférence/division.

## Lectures et scénarios envisageables

| Lecture proposée | Faisabilité avec les données examinées |
| --- | --- |
| Avantage au classement | Points/matchs disponibles ; attendre un échantillon suffisant, choisir phase et groupe de comparaison |
| Avantage de forme / dynamique / série | Résultats disponibles ; reconstruire la fenêtre après classification des phases, utiliser le barème du championnat |
| Attaque productive contre défense fragile | Buts pour/contre disponibles ; recalculer sur une fenêtre comparable de matchs éligibles |
| Solidité domicile / fragilité extérieure | Position domicile/extérieur disponible ; même exigence de phase et de taille d'échantillon |
| Matchs riches/pauvres en buts | Totaux dérivables des résultats ; définir séparément total à 60 minutes et total final |
| Départs forts / fins de match fragiles | Scores par période et chronologie des buts présents ; auditer davantage de matchs avant calibration |
| Rencontres souvent prolongées | Statut et période OT disponibles ; distinguer égalité à 60 minutes et vainqueur final |
| Repos / matchs rapprochés | Horaires disponibles ; auditer la complétude du calendrier avant de conclure, aucun déplacement déduit sans lieux fiables |
| Joueurs décisifs (buts + passes) | Possible comme exploration des événements ; nécessite identité stable, couverture historique et déduplication avant un radar fiable |
| Avantage gardien / efficacité PP-PK / domination par les tirs | Données nécessaires non établies ; garder ces capacités indisponibles |

Exemples de scénarios à étudier : **forme + avantage structurel** ;
**attaque productive face à une défense perméable** ; **avantage de repos + forme**.
Ces propositions ne sont ni des lectures activées ni des probabilités calibrées.
Les seuils du socle existant restent des hypothèses à valider historiquement.

Pour le bilan et les cotes, une victoire de Boston ici valide une sélection
« vainqueur final », mais ne valide pas « Boston gagne à 60 minutes » : le score
à 60 minutes est nul. Les périmètres des marchés devront être explicites.

## Suite technique recommandée

1. Adaptateur hockey distinct, avec scores régulation/OT/tirs au but/final,
   statut et phase connus ou inconnus, qualité/couverture explicites.
2. Vérifier les sources de phase, les tirs au but et les marchés sur un second
   échantillon ciblé ; ne pas construire des filtres à partir d'un seul match.
3. Calculer les fenêtres d'équipe depuis des matchs éligibles ; conserver les
   données brutes et les preuves de chaque lecture.
4. Brancher le quota hockey 7 500/jour et 300/minute dans l'orchestrateur, avec
   réservations atomiques, cache, lots et marge. Ne pas emprunter le budget foot.
5. Implémenter d'abord classement, forme, buts et calendrier ; PP/PK et gardiens
   restent conditionnés à une source de statistiques suffisante.
6. Vérifier le parcours collecte → brut → analyse → compact → front avant activation.

Un calendrier d'équipe entier a été obtenu en **un appel** (88 matchs pour
Winnipeg, dont cinq terminés). Les 16 événements ont été obtenus en un appel,
pas un appel par joueur. Le premier module peut donc partager ces données entre
lectures et scénarios. Le coût opérationnel exact dépendra du nombre de ligues,
des fenêtres historiques et du live ; ce petit audit ne le chiffre pas encore.

## Complément : H2H, catalogue et affichage

Deux appels supplémentaires ont été effectués à la demande de l'utilisateur :
`/games/h2h?h2h=704-673` et `/leagues`, soit 12 requêtes HTTP au total pour
l'ensemble de l'audit et de son complément.

Le H2H contient 47 matchs, dont 46 terminés et un à venir. Les champs
`teams.home`, `teams.away`, `scores.home` et `scores.away` préservent le lieu
de chaque confrontation : l'ordre des IDs dans `h2h` n'est pas l'ordre de
présentation domicile/extérieur. L'historique commence en 2008 ; certaines
anciennes rencontres n'ont ni périodes ni événements. Filtrer dates, statut,
compétition et phase avant de construire une lecture ; exclure le match étudié
et les résultats ultérieurs pour une évaluation avant match.

Convention demandée pour le module hockey : **extérieur à gauche, domicile à
droite**, avec libellés visibles. Les scores, logos, formes et événements doivent
suivre leur équipe. Exemple : Boston (extérieur) **4–3** Winnipeg (domicile),
alors que l'objet brut contient `scores.home=3` et `scores.away=4`.
Les propriétés métier restent nommées home/away ; seul l'ordre de présentation
est configurable par sport. Le football conserve son propre ordre. Cette
convention est consignée pour l'intégration ; elle n'est pas encore implémentée
dans une carte de match hockey connectée.

Le catalogue réel contient 262 compétitions dans 36 pays ou zones, dont 57
avec une saison marquée actuelle par l'API. Le [catalogue complet](competitions.md)
donne tous les IDs et les drapeaux actuels ; ce drapeau ne garantit pas la
couverture de toutes les statistiques, des événements ou des cotes.

L'[objet brut Winnipeg–Boston](winnipeg-boston-game.json) est extrait sans
modifier ses champs de la réponse du jour. La réponse complète des
[événements](04_games_events.json) et le [H2H](11_games_h2h.json) sont conservés.

### Sources du complément

Complément cotes : deux appels supplémentaires (`odds/bets`, `odds` filtré
NHL/saison 2026), soit 14 requêtes HTTP au total. Le [catalogue des marchés](markets.md)
conserve les 221 libellés reçus, leur présence dans l'échantillon NHL et les
cotes de Winnipeg–Detroit. Certains libellés sont incohérents avec le hockey ;
les IDs ne constituent pas automatiquement des marchés validés. Les périmètres
régulation/OT/tirs au but restent à valider avant tout règlement automatique.

- [API-Sports : offre hockey et quotas](https://api-sports.io/sports/hockey)
- [Guide officiel hockey : statistiques, classements et événements](https://www.api-football.com/news/post/ice-hockey-world-championship-2026-guide-to-using-data-with-api-sports)
- [Documentation hockey](https://api-sports.io/documentation/hockey/v1)

La documentation interactive était inaccessible au lecteur automatique pendant
l'audit. Les appels utiles ont été guidés par le guide officiel ; une seule
sonde explicite a vérifié l'absence du point d'accès de statistiques par match.
