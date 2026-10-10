# Démo — journée du dimanche 11 octobre 2026

## Football : absence reproduite

Le fichier public de dimanche contenait 116 fixtures, toutes datées du 11 octobre.
Sa date de capture était le 9 octobre à 05:47 UTC. Le 11 octobre après minuit à
Paris, ce fichier dépassait déjà le délai de fraîcheur de 36 heures. Le lecteur
CDN le retournait pourtant au chargeur, qui le rejetait ensuite et créait un
calendrier vide sans consulter les snapshots serveur plus récents (10 octobre).

Le lecteur contrôle désormais la couverture et la fraîcheur avant d'accepter
une livraison. Une publication périmée ou une livraison inaccessible laisse le
lecteur public Supabase prendre le relais. Les détails d'une livraison rejetée
ne restent pas associés à la nouvelle liste. Les jours passés restent évalués
à la fin de leur propre journée, sans utiliser des lectures créées après celle-ci.

## Hockey : vérification distincte

Le serveur fournissait bien les 42 états des matchs du dimanche, dont 12 en
cours à l'heure du contrôle. Le lecteur et son overlay affichent ces 12 états
dans un test utilisant les réponses publiques réelles. Après réouverture de
l'espace hockey, l'onglet Tous de la démo affiche les 12 rencontres live et leurs
scores. L'absence initialement signalée n'est donc pas reproduite durablement ;
aucune modification du collecteur ou du règlement des scores n'a été faite.

Le moteur calcule des lectures détectées en KHL et en Extraliga sur cette même
publication. Plusieurs lectures NHL/AHL sont suspendues faute de résultats
comparables suffisants en ce début de saison. Les préférences hockey sont
stockées par compte dans le navigateur ; les traces du Générateur montrent une
session avec des préférences hockey, et une autre avec un périmètre hockey vide.
Ces traces ne permettent pas de déduire les préférences actuellement présentes
sur l'appareil de l'utilisateur.

## Erreur du Générateur

L'échec serveur du 10 octobre à 19:37 Paris est documenté séparément dans
`generator-incident-2026-10-10.md`. L'utilisateur indique que l'erreur qu'il a vue
n'était pas un timeout. Il ne faut donc pas assimiler ce constat serveur à son
message d'erreur sans retrouver le texte ou la capture affichée.

## Vérifications

Les tests du lecteur, de la fraîcheur, de la navigation historique et de la
livraison ont été exécutés sans appel OpenAI payant. La démo est reconstruite
avec un export public football actualisé. Les données et les préférences
football/hockey restent séparées.
