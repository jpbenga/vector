# Aperçu Form Radar à trois joueurs

## Modification

Le panneau `LectorFormRadarSignalPanel`, partagé par les cartes de match
football et hockey, affiche désormais les trois premières lignes du classement
au lieu de quatre. Le compteur conserve le nombre total de joueurs éligibles.
Le bouton « Voir les N joueurs » déplie les autres joueurs ; « Réduire la liste »
rétablit l’aperçu à trois. Les règles sportives et le classement restent inchangés.

Cette modification concerne le panneau intégré aux cartes de match. Le classement
exploratoire de l’onglet Radar conserve sa pagination de dix joueurs par page.

## Vérification

- 14 tests Flutter réussis : panneau football, cartes hockey aux largeurs 360 et
  1100 px, classement hockey et composants partagés.
- Les tests vérifient les trois joueurs les mieux classés, l’accès aux autres,
  la réduction et l’absence de navigation involontaire lors du dépliage.
- Construction web release réussie ; aucun secret fournisseur ou serveur dans
  les fichiers publiés.

## Démo

- Branche : `codex/multisport-hockey`.
- Déploiement Vercel preview : `dpl_CCGgWwMRbmQN3Rgy5tpgJszjdrJi`, état Ready.
- Démo : https://lector-sports-demo-lector1.vercel.app/sports/hockey
- Aucune modification du backend nécessaire à cette correction.
