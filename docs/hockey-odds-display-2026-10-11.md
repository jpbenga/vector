# Cotes hockey visibles et actualisées

## Incident vérifié

Le 11 octobre, les cartes hockey de la démo ne contenaient aucun composant de
cotes. Le détail de Calgary–Bakersfield indiquait également leur indisponibilité.
Pourtant, le lecteur public `read_sport_feed(day)` renvoyait 2 827 observations
sur les 42 rencontres de la journée, dont 81 pour Calgary–Bakersfield et 72 pour
Hartford–Laval. La collecte de 12:17 UTC avait réussi.

Le manifeste public avait été publié à 04:11 UTC, depuis la publication
analytique de 03:34 UTC et les cotes de 00:17 UTC : ces deux matchs n'y
avaient pas encore de prix. Les fichiers locaux plus anciens présentaient la
même absence. La revalidation publique actualisait le cache mais
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
- Les fichiers de démo sont reconstruits depuis la publication canonique de
  03:34 UTC et ses 6 169 observations de prix vérifiées côté serveur. Le
  manifeste serveur utilisé par les écrans est également republié depuis cette
  source, sans relancer la collecte.

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
collecte fournisseur.

## Livraison vérifiée

- Code applicatif : `1fdd0c2b7ba6222c935023d4d0b03b9fcac7ab47` sur
  `codex/multisport-hockey`.
- CI complète réussie : https://github.com/jpbenga/vector/actions/runs/38158597976
  (Flutter et fonctions serveur).
- Fonction `lector-generator-workshop` mise à jour :
  https://github.com/jpbenga/vector/actions/runs/38158968976
- Livraison publique hockey republiée sans collecte :
  https://github.com/jpbenga/vector/actions/runs/38159272220
  Le manifeste indique `2026-10-11T17:21:42.643Z`. La journée du 11 octobre
  comporte 42 rencontres et 2 827 observations de prix.
- Déploiement Vercel : `dpl_BfSNtnvVqWguubRHQgXEzwWRHLR4`, accessible sur
  https://lector-sports-demo-lector1.vercel.app/sports/hockey
- Vérification dans le navigateur, onglet Tous, filtre À venir, AHL :
  Bakersfield / nul / Calgary = `2,65 / 4,15 / 2,13` ;
  Laval / nul / Hartford = `2,53 / 4,00 / 2,21`.
  Le détail Calgary–Bakersfield affiche les mêmes valeurs, le marché à
  60 minutes, le bookmaker 1xBet et l'observation du 11 octobre à 14:17 Paris.
  Une capture est conservée dans `output/hockey-cotes-demo-2026-10-11.png`.
- Un premier paquet incrémental incomplet a été détecté dans le navigateur et
  remplacé par un paquet complet. Le script bloque désormais la publication
  si les manifestes, le script vocal ou les polices sont absents.

Les rencontres sans cote fournie ne reçoivent aucun prix inventé. Les prix
prématch ne sont pas présentés comme des cotes live après le coup d'envoi.
Cette livraison n'a consommé aucun appel OpenAI ni API-Hockey supplémentaire.
