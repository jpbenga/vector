# Statistiques Live et après match — 5 octobre 2026

## Validation et périmètre de publication

Cette itération a été vérifiée localement dans le checkout football (main, base
edce988) et la branche codex/multisport-hockey. L’utilisateur a validé le rendu et
autorisé sa publication en production le 5 octobre 2026. La publication sur main
concerne uniquement le football et ses composants communs ; les modules, écrans
et collectes hockey restent sur codex/multisport-hockey.

## Interface commune

LectorMatchStats est partagé à l’identique. Le sport fournit ses participants,
les lignes factuelles, les événements, les périodes disponibles et son illustration.
L’onglet Stats s’ouvre pour un match en cours ou terminé, tout en respectant les
changements manuels d’onglet. Les statistiques des anciens matchs restent dans
cette fiche, séparées de la forme et des lectures annoncées avant match.

Le panneau reprend la référence visuelle fournie : scène centrale, chiffres
latéraux, résumé factuel, comparaisons et fil du match. Les contrôles de période
ne sont proposés que lorsque les scores de période existent. Zéro est une vraie
valeur ; un champ absent reste absent. Les statistiques par période ne sont pas
déduites des totaux. Aucune vidéo, position de tir ou domination territoriale
n’est inventée. La patinoire est un fond identitaire.

Pour le hockey, la publication actuelle fournit surtout les scores par période.
Les tirs, mises en jeu et minutes de pénalité de la maquette ne sont pas fournis
par les données de match actuellement collectées ; ils ne sont pas affichés.
Les événements du match terminé sont récupérés lorsque games/h2h annonce leur
disponibilité, avec le cache games/events existant. L’historique avant match
continue d’exclure le match lui-même. La collecte hockey récurrente Live reste
un chantier distinct.

## Après match et SQL

La nouvelle migration 20261005003000_persistent_match_statistics.sql conserve
les événements optionnels via le lot de 20 IDs existant : aucun nouvel appel
API-Football. Elle remplace la lecture publique pour que le snapshot final ne
soit plus masqué par une ancienne ligne du cache Live. Elle conserve un bloc
statistique final déjà enrichi lorsqu’un passage suivant ne fournit que le score.
Une correction de score ne réutilise pas le bloc final associé à un autre score.
Si seule une ancienne collecte Live existe, le panneau l’indique explicitement
au lieu de la présenter comme des statistiques finales confirmées.

La consultation d’un ancien match lit Supabase ; elle ne sollicite pas le
fournisseur. Le cache Live peut disparaître sans supprimer les statistiques du
snapshot de résultat. Les timestamps des scores, statistiques et événements
restent séparés. Les permissions publiques existantes sont conservées.

## Tests

- Gates complets avant publication : formatage des 284 fichiers sans modification,
  analyse Flutter propre, 622 tests Flutter réussis (2 ignorés), 27 tests Deno
  partagés et 2 tests SQL réels réussis avec les permissions de CI.
- Test SQL réel : publication, lecture anonyme, cache ancien, suppression du
  cache, enrichissement conservé malgré un résultat sans détails, correction
  du score et résultat vieux de quatre jours.
- 38 tests Flutter de Stats, Live et design system côté football.
- Contrôles mobiles 390 × 844 dans les thèmes clair et sombre, valeurs absentes,
  valeurs zéro, événements triés et message final partiel.
- 12 tests de publication et navigation hockey ; 6 tests Deno d’enrichissement.
- Analyse Flutter propre dans les deux checkouts.

## Illustration

Asset : assets/backgrounds/hockey-rink-stats.png dans les deux checkouts.
Généré avec l’outil imagegen intégré à partir de la référence utilisateur
Image ChatGPT 5 oct. 2026, 00_31_30.png, puis copié sans modification.

Prompt : « Extract and faithfully recreate only the top-down horizontal hockey
rink illustration. Transparent exterior, charcoal textured ice, luminous cyan
perimeter, red center line and left goal crease, cyan right crease, symmetrical
face-off circles. No UI, text, logos, team abbreviations, player or shot markers.
Strict top-down view, tight framing. »

## Publication suivante

Après validation, appliquer uniquement cette migration additive, déployer le
collecteur football sync-live-matches et publier le frontend football. Les
adaptations hockey restent sur leur branche. Aucun cycle complet requis.

## Précisions de l’itération football

Le texte fourni avec la seconde maquette prime sur son terrain illustré : le
football utilise une empreinte de statistiques (barre partagée, point de rapport,
repère central), sans terrain ni heatmap. L’ordre est désormais empreinte,
lecture factuelle, fil du match et toutes les données brutes dans une section
repliée. Une valeur absente des deux côtés ne crée aucun composant ; aucun fil
n’est affiché sans événements. Les périodes statistiques ne sont proposées que
si elles sont reçues : les totaux football ne sont pas divisés artificiellement.

Le badge de détail est plus visible et affiche la minute reçue avec « En direct ».
Le score de mi-temps provient du fournisseur, est stocké dans le cache et les
résultats, puis lu publiquement ; il reste conservé quand un résultat ultérieur
ne fournit que le score final. Il n’est pas montré pendant la première mi-temps.
Les lectures pré-match restent sur le snapshot initial.

La chronologie utilise les minutes réelles, les limites des périodes et la
position de la dernière minute reçue, sans horloge simulée. Le temps additionnel
45+3 reste au bord de la première période. Les événements sans minute restent
lisibles dans la liste sans être placés artificiellement. Les événements
rapprochés utilisent plusieurs lignes pour éviter leur superposition sur mobile.
Les détails sont du plus récent au plus ancien. Le score progressif est affiché
seulement lorsque tous les buts reçus concordent avec le score officiel ; il est
masqué si un but manque, si une attribution est ambiguë ou si un événement est
futur. Aucun lien vidéo fictif n’est ajouté.

Une lecture du live décrit uniquement possession/tirs/tirs cadrés réellement
mesurés et le score, avec éventuellement une égalisation depuis la mi-temps.
Elle ne prétend pas constater une domination ou des transitions. La fraîcheur
est réévaluée même si le réseau cesse de répondre : une interprétation ancienne
est masquée et le badge passe à « Dernier état » sans avancer la minute.

Tests : 38 contrôles Flutter dans chaque checkout ; 5 contrôles Deno/SQL
incluant lecture anonyme, conservation après match et mi-temps persistante.
L’aperçu autonome tool/previews/football_stats_preview.dart utilise les mêmes
composants avec des données explicitement de démonstration. Il n’est pas inclus
dans main.dart, les publications ni les flux de production. Il permet de voir
l’interface Live même lorsqu’aucun match réel n’est en cours.
