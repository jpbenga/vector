# Calendrier football de 14 jours

Date : 2026-10-04. Travail local sur `codex/football-calendar-14-days`, issu de
`main` (`de1c0b5`). Le chantier hockey est conservé sur
`codex/multisport-hockey` (`824c8fb`). Aucun déploiement effectué pour ce chantier.

## Ce qui change

Une collecte du 4 octobre couvre **du 4 au 17 octobre inclus**. Celle du
5 octobre couvre du 5 au 18 octobre. La fenêtre est exprimée en dates locales
Europe/Paris ; les passages de mois, d’année et d’heure sont testés.

| Donnée | Traitement |
| --- | --- |
| Rencontres J à J+3 | Réponses `/fixtures` par date, cache de 15 minutes |
| Rencontres J+4 à J+13 | Calendrier de saison `/fixtures?league&season&timezone`, déjà collecté, cache de 6 heures |
| Cotes | Toutes les dates UTC ayant une rencontre dans le calendrier, toutes les pages, uniquement les cotes réellement disponibles |
| Forme récente | Historique arrêté à la veille du jour de collecte ; une même équipe réutilise le même historique pour ses différentes rencontres futures |
| Lectures et scénarios publiés | J à J+3 ; cette publication constitue la preuve conservée pour le bilan |
| Résultats passés | Collecte J-7 à J-1 existante ; circuit live distinct |

Le calendrier, le snapshot brut et le compact public utilisent les mêmes
bornes. Une réponse datée vide dans la fenêtre proche prime sur le calendrier
de saison : une rencontre retirée/reportée ne réapparaît pas via le cache de
saison. Les jours éloignés utilisent le calendrier de saison, sans recycler un
ancien cache daté. Un calendrier confirmé vide est publiable.

La récupération des cotes n’est pas limitée aux quatre jours proches. API-Football
annonce une disponibilité généralement comprise entre 1 et 14 jours avant le
match, variable suivant la couverture. Les cotes sont paginées à dix rencontres
par page : la collecte et le constructeur lisent maintenant toutes les pages.
Une première page récemment devenue vide remplace les anciennes pages ; celles
qui dépassent son nouveau nombre de pages ne sont pas republiées.
Source : [guide officiel API-Football](https://www.api-football.com/news/post/how-to-get-started-with-api-football-the-complete-beginners-guide).

Chaque appel, y compris une page supplémentaire, utilise la réservation
commune : 75 000 appels/jour et garde de 280 appels/minute. Les invocations
réutilisent les réponses encore valides ; les appels faits pour tous les
utilisateurs sont centralisés au serveur. Chaque page vide interrogée coûte
quand même un appel fournisseur.

## Ce que verra l’utilisateur

Dans le calendrier/Tous, les rencontres connues du fournisseur apparaissent
même sans cote. Lorsqu’une cote devient disponible, la collecte quotidienne
suivante la publie. Les amicaux internationaux ne sont plus supprimés pour la
seule raison qu’ils n’ont pas de cote.

Un jour sans rencontre reste un état vide de l’application. La barre de dates
du front utilise déjà 31 jours : elle ne nécessitait pas d’agrandissement.

Une rencontre éloignée peut ne pas avoir encore de lectures publiées. Elles
entrent dans le circuit actuel lorsque le match rejoint J à J+3. Cela évite de
figer une preuve de forme deux semaines avant le coup d’envoi, puis de la
comparer à un résultat dans le bilan alors que plusieurs matchs intermédiaires
ont changé la situation. Le contexte factuel du snapshot est rafraîchi chaque
jour ; la preuve d’une lecture déjà publiée garde l’immutabilité existante.

## Coût API : supplément, pas multiplication par 3,5 du pipeline

Le calendrier complet de saison était déjà récupéré pour les classements et
les analyses. L’extension de calendrier n’ajoute donc **aucun appel daté** pour
les dix jours éloignés. Les quatre appels datés proches sont conservés.

Pour les cotes, soient :

- `L` : nombre de compétitions effectivement activées ;
- `D_l` : dates supplémentaires ayant des rencontres pour la compétition `l` ;
- `P_l,d` : nombre de pages de cotes renvoyées pour cette date (une première
  page même lorsqu’aucune cote n’existe).

Le supplément de cotes est la somme des `P_l,d` sur les dates nouvellement
consultées. Les dates sans rencontre ne provoquent pas d’appel de cotes.
Le nombre exact est donné par `paging.total`, et non estimé à partir du nombre
de bookmakers.

**Illustration : 76 compétitions**, une collecte quotidienne, au plus dix dates
supplémentaires par compétition et une seule page par date : **jusqu’à 760
premières pages supplémentaires/jour**, soit environ **1,01 %** du forfait de
75 000 appels. Avec des matchs concentrés sur deux nouvelles dates, ce poste
serait d’environ 152 appels. Ces chiffres sont des hypothèses de dimensionnement,
ils ne représentent pas un relevé du planning actif en production.

À ajouter :

- les pages supplémentaires au-delà de dix rencontres avec cotes ;
- les nouveaux face-à-face et les événements de leur historique, surtout lors
  du premier élargissement (cache de face-à-face de 30 jours) ;
- la forme et les données joueurs des équipes qui n’étaient pas encore dans la
  fenêtre proche. Les requêtes d’historique d’une même équipe réutilisent
  désormais les mêmes bornes, et l’enrichissement conserve ses lots reprenables ;
- les appels déjà consommés par le live et les autres collectes.

Les statistiques de saison des équipes étaient déjà collectées à l’échelle du
championnat. Leur coût ne se multiplie pas automatiquement avec les dates.
Un budget journalier confortable ne supprime pas la limite par minute.

Le coût marginal fournisseur dépend de la marge restante du forfait : ce
changement consomme des appels de l’abonnement existant. La lecture des
compteurs serveur n’a pas pu être faite avec le fichier `.env` local, qui ne
contient pas la clé de lecture serveur. Aucun total de production n’est inventé.

## Supabase

Cette extension ne nécessite ni autre infrastructure ni nouvelle base. Les
snapshots restent organisés par compétition ; une fenêtre plus longue ne
multiplie pas par quatorze le nombre de lignes de snapshot ou de requêtes du
front. Elle augmente les données contenues dans chaque payload.

À densité de calendrier constante, la partie **rencontres** peut être environ
3,5 fois plus grande qu’avec quatre jours. Ce coefficient ne s’applique pas au
payload entier : le calendrier de saison et les statistiques existaient déjà.
Les nouvelles cotes et histoires de face-à-face augmentent aussi sa taille.

Le dépôt conserve les snapshots immuables et n’a pas de politique automatique
de rétention de ces snapshots. La croissance du stockage et les octets
transférés au front sont donc les deux mesures à relever avant de chiffrer une
facture mensuelle. Le palier gratuit annonce 500 Mo de base et 5 Go de trafic
sortant ; Pro commence à 25 USD/mois avec notamment 8 Go de disque inclus.
Source : [tarifs Supabase](https://supabase.com/pricing).

Le tarif exact dépend du plan, du volume actuellement conservé, du nombre de
consultations et des éventuels autres projets. L’extension seule ne justifie
pas de migration. Une politique de rétention devra préserver les preuves du
bilan et être décidée avec ces mesures, sans supprimer arbitrairement l’audit.

## Tests de non-régression

`football_calendar_pipeline_test.ts` exécute les **vraies fonctions** de
collecte, construction brute, publication des lectures et compactage. Les
appels réseau sont simulés et toute destination inattendue est refusée.
Il vérifie :

1. quatorze dates et exclusion du quinzième jour ;
2. reprise du calendrier de saison, seulement quatre appels de fixtures datés ;
3. récupération et publication de la seconde page de cotes ;
4. réservation de quota pour chaque appel fournisseur ;
5. payload compact exact partagé avec le test Flutter ;
6. nouveau jour entrant, ancien jour sortant, apparition de nouvelles cotes ;
7. collecte confirmée sans rencontre : publication compacte vide réussie.

`football_calendar_contract_test.dart` charge ce même payload via le chargeur
public Flutter, avec l’horloge de collecte. Il vérifie la couverture du dernier
jour, la cote issue de la seconde page et le rendu de la vraie carte mobile
pour une rencontre sans cote.

Les tests de politique couvrent également les dates locales autour de minuit,
les changements de mois/année/heure, une réponse proche vide prioritaire,
l’absence normale de cotes et la fenêtre des lectures immuables.

## Mise en production après validation locale

Pas de migration SQL nécessaire. Il faudra déployer les fonctions qui ont
changé et le worker qui importe la politique d’orchestration :

- `api-football-sync` ;
- `build-match-feed-snapshot` ;
- `publish-reading-announcements` ;
- `ops-worker` ;
- `daily-football-sync` pour les appels de compatibilité.

Le compacteur inchangé `analyze-match-feed-snapshot` transmet les nouvelles
bornes et les nouvelles rencontres ; son comportement est exercé par le test.
Le frontend doit aussi être publié pour conserver les amicaux sans cote.

Les cycles déjà créés ne sont pas mutés par le code local. Après déploiement,
un nouveau cycle publiera les premiers snapshots de 14 jours. Les anciens
snapshots de quatre jours ne s’agrandissent pas rétroactivement. Les outils de
lancement compatibilité passent maintenant `future_days: 13` ; ce paramètre
est un décalage inclusif, pas un nombre de jours.
