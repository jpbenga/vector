# Audit des snapshots publiés — 1er octobre 2026

## Périmètre

Lecture seule de `match_feed_analysis_snapshots`, filtrée sur les publications
qui couvrent le 2 octobre 2026. Cette table est celle consommée par
l’application, après analyse des données source par compétition.

## Résultat

Les données existent déjà : l’absence affichée dans l’application ne venait
pas d’un cycle non lancé ni d’une absence de match.

| Mesure | Valeur |
| --- | ---: |
| Snapshots analysés couvrant le 2 octobre | 104 |
| Compétitions distinctes | 73 |
| Fenêtre du 1er au 4 octobre | 84 |
| Fenêtre du 30 septembre au 3 octobre | 12 |
| Fenêtre du 29 septembre au 2 octobre | 8 |
| Rencontres dans ces publications | 483 |
| Lectures calculées | 387 |
| Scénarios calculés | 49 |
| Profils joueurs du radar | 4 188 |

La publication la plus récente a été capturée le 1er octobre à 07:44:53 UTC.
Les publications analysées couvrent donc correctement la fenêtre J à J+3.

## Lectures associées aux snapshots retenus

Le client ne conserve que le snapshot le plus récent de chaque compétition.
Pour ce jeu de 73 snapshots retenus, tous sur la fenêtre du 1er au 4 octobre :

| Mesure | Valeur |
| --- | ---: |
| Rencontres dans les snapshots retenus | 169 |
| Snapshots avec des rencontres | 12 |
| Snapshots avec des lectures | 7 |
| Lectures associées aux rencontres | 142 |
| Snapshots avec des scénarios | 3 |
| Scénarios associés aux rencontres | 19 |
| Snapshots sans rencontre | 61 |
| Snapshots avec rencontres mais sans lecture | 5 |

Les 61 snapshots sans rencontre sont attendus pendant la trêve : ils
conservent la couverture de la compétition et les données de radar quand elles
existent, mais aucune rencontre ne peut recevoir de lecture.

Les cinq snapshots ayant des rencontres sans lecture concernent la CONCACAF
Nations League, les FA Cups anglaise et écossaise, la Copa del Rey et l’UEFA
Nations League. Leur publication a bien été exécutée : les compteurs
`candidateFixtures` correspondent aux rencontres reçues et
`detectedAnnouncements` vaut zéro. Les lectures n’ont donc pas disparu entre
la publication et le snapshot ; aucune règle durcie n’a été satisfaite pour
ces rencontres.

Le chaînage est vérifié par le contrat de publication : les annonces sont
recherchées par `fixture_id`, puis matérialisées dans
`computed.fixtures[].readings` du snapshot analysé. Le compteur
`reading_count` est calculé sur ces annonces associées.

## Cause du rejet dans l’application

Le lecteur contrôlait correctement que la fenêtre du snapshot contenait la
date choisie. Il comparait toutefois aussi sa date de capture à cette date
choisie. Lorsqu’un utilisateur sélectionnait J+1, J+2 ou J+3, un snapshot
capturé aujourd’hui était donc considéré, à tort, comme ancien.

Le contrôle a été corrigé :

- la couverture reste comparée au jour choisi ;
- la fraîcheur est comparée au jour réel où l’application est utilisée ;
- une absence réelle de publication produit une journée vide, sans écran
  d’erreur et sans réutiliser de données historiques.

## Décision sur un nouveau cycle

Un cycle complet n’est pas nécessaire pour réparer ce cas précis : les
snapshots couvrant le 2 octobre sont déjà publiés. Il faut reconstruire et
relancer l’application avec le correctif de lecture.
