# Cotes hockey visibles et actualisées

## Incident vérifié

Le 11 octobre, les cartes hockey de la démo ne contenaient aucun composant de
cotes. Le détail de Calgary–Bakersfield indiquait également leur indisponibilité.
Pourtant, le lecteur public `read_sport_feed(day)` renvoyait 2 827 observations
sur les 42 rencontres de la journée, dont 81 pour Calgary–Bakersfield et 72 pour
Hartford–Laval. La collecte de 12:17 UTC avait réussi.

La démo conservait une livraison observée à 00:18 UTC : ces deux matchs n'y
avaient pas encore de prix. La revalidation publique actualisait le cache mais
ne prévenait pas les écrans déjà affichés. Le détail restait donc sur son objet
initial. Ce défaut s'ajoutait à l'absence de cotes dans les cartes.

## Correction

- Le composant partagé des cartes accepte un emplacement de cotes.
- Hockey affiche un résultat réglementaire complet d'un même bookmaker, avec
  `60 min` et l'ordre `2 / N / 1`, conforme à ses équipes extérieur/domicile.
- Le choix du bookmaker privilégie un 1N2 complet, puis la couverture des
  autres marchés ; aucun mélange de bookmakers n'est utilisé.
- La revalidation des journées et des détails émet une mise à jour publique.
  L'écran ne reçoit que sa journée ou son match. Les détails conservent leurs
  faits analytiques et ne remplacent que les observations de prix de la même
  version et des mêmes équipes.
- Les dates et versions anciennes ne remplacent pas la vue courante.
- La livraison de démo est reconstruite depuis la publication canonique de
  03:34 UTC et ses 6 169 observations de prix vérifiées côté serveur.

## Générateur

La demande de 18:35 Paris consultait quatre rencontres. Deux rencontres tchèques
étaient déjà passées à leur horaire prévu (17:00 et 18:30). Elles avaient des
prix mais ne pouvaient plus entrer dans un combiné prématch. Le contrat des
outils distingue désormais présence des cotes et éligibilité du marché :
horaire dépassé, statut, publication, collecte et absence de candidat admissible
sont des causes séparées. L'IA ne doit pas déclarer les cotes absentes sur la
seule base de candidats exclus.

## Vérification

Tests de cartes à 320 px, mise à jour d'un détail déjà ouvert, réponse tardive
d'une autre journée, prix actualisés sans changement de version, conservation
du cache en cas d'échec et continuité des scores live. Tests Deno des outils et
évaluations avec la reconstitution des quatre rencontres, sans appel IA payé.
La lecture publique et la préparation de cette livraison n'ont lancé aucune
collecte fournisseur. Les preuves de déploiement sont ajoutées après publication.
