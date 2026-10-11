# Transitions de navigation Lector

## Composants partagés

`LectorHorizontalTransition` anime une position ordonnée pendant 440 ms avec
`easeInOutCubic` : environ 160 ms de sortie, puis 280 ms d'entrée. Le contenu
change lorsque le fondu atteint zéro, avec un déplacement horizontal discret.
Une position supérieure arrive de la droite ; une position inférieure de la gauche.
Le sens est inversé pour une interface RTL.

Un seul contenu reste monté. Une actualisation de données à position identique
ne relance pas l'animation. Les changements rapides conservent uniquement le
dernier contenu, sans lecteur de données ou abonnement live supplémentaire.

Les espaces football et hockey utilisent ce composant pour la navigation,
les journées, le Radar joueurs/équipes, les onglets du détail de rencontre,
les classements, les confrontations et les sous-menus du Générateur/Explorateur.
Le calendrier révèle aussi progressivement une date sélectionnée hors de son
viewport ; la sélection reste identique pendant ce défilement.

`lectorSheetAnimationStyle(context)` unifie les 38 ouvertures de bottom sheets :
420 ms à l'ouverture, 320 ms à la fermeture. La route Flutter conserve la montée
depuis le bas, la descente à la fermeture et les gestes de fermeture existants.

Les deux composants respectent `MediaQuery.disableAnimations`. L'animation
ne retarde aucune lecture réseau et ne remplace pas les skeletons de chargement.

## Vérification

La nouvelle itération vérifie aussi l'envoi vocal automatique, la transcription
vide, la fermeture du Générateur pendant la transcription, la sortie avant le
montage du nouvel écran, les changements rapides et les changements de version
des publications. Les tests de livraison contrôlent la conservation des cotes et
l'absence de modification des fichiers football lors d'une reconstruction hockey.

- 61 tests Flutter réussis : sens du mouvement, changements rapides,
  conservation d'un seul contenu, actualisation sans animation supplémentaire,
  réduction des animations, ouverture/fermeture des sheets, calendrier,
  largeurs mobiles, classements, Radar, défilement et restauration du chat.
- Analyse Flutter : aucune anomalie.
- 6 tests Python réussis pour la vérification des publications hockey.

Une reconstruction avec `tool/build_multisport_demo.py --reuse-delivery` conserve
les données et observations de cotes de la démo existante. Elle exige une
publication analytique identique côté serveur et côté fichiers de livraison.
La vérification complète des nouvelles cotes reste active lors d'une publication
de données. Ce mode permet une évolution visuelle sans solliciter à nouveau la
projection des cotes, qui a renvoyé un timeout PostgreSQL pendant cette livraison.

## Navigation hockey et cache

La démo lit d'abord la journée préparée sur le CDN. Après ce premier affichage,
une seule publication complète vérifiée préchauffe le Radar, les journées de la
fenêtre et les détails. Les fixtures et classements décodés sont partagés par
référence ; il n'y a plus vingt téléchargements et décodages de ces classements.
Une journée passée sans fichier dédié peut aussi utiliser cette publication.

Les caches restent bornés (24 vues de navigation, 12 détails). Les revalidations
serveur sont exécutées une à une, avec au plus quatre demandes en attente et
priorité à la dernière vue consultée. Les échecs ne remplacent pas les dernières
données disponibles. La fraîcheur maximale de 36 heures reste contrôlée et une
nouvelle version serveur ne peut être remplacée par une ancienne version CDN.
Les scores live conservent leur circuit séparé.

La reconstruction hockey utilise maintenant le payload vérifié avec ses cotes,
et crée de nouvelles références de fichiers lorsque ces observations changent.
Les horodatages d'origine sont conservés. Les fichiers football sont réutilisés.

Le 10 octobre, les lectures publiques Supabase `day` et `radar` ont expiré après
5,54 et 6,98 secondes (`57014`). Une optimisation de la matérialisation JSON est
préparée dans `20261010183000_hockey_reader_materialization.sql`. Son application
a été refusée par la revue automatique car le projet Supabase est de production ;
elle attend une autorisation précise et n'est pas incluse dans la livraison UI.

## Livraison démo — 10 octobre 2026

Compilation release réussie. Aperçu Vercel `dpl_DuSbTaEfvdZLFGgCnfecEBihmGCW`,
état `READY`, disponible derrière l'alias habituel
`https://lector-sports-demo-lector1.vercel.app`.

Empreinte SHA-256 du bundle `main.dart.js` :
`60b8f76e858280a1f8ec5c89f25c34b56e8a1cabffeb1f73816679c954b4b71f`.

Contrôle sur la démo publique à 390 × 844 : navigation vers Tous en football
et en hockey, ouverture du bottom sheet hockey, passage Lectures → Scénarios,
fermeture par glissement, puis passage du 10 au 11 octobre (34 → 42 rencontres).
Aucune erreur console observée. Capture :
`output/qa/ui-motion/hockey-bottom-sheet.png`.

## Itération finale — dictée et cache, 10 octobre 2026

La nouvelle livraison démo est `dpl_9ipWvnpiXytsR587JXN3qxMvpNd6`, état
`READY`, à l'adresse `https://lector-sports-6xc8q81fu-lector1.vercel.app`.
L'alias public `https://lector-sports-demo-lector1.vercel.app` pointe vers cette
livraison. La compilation release et l'analyse Flutter ont réussi.

Empreinte SHA-256 de `main.dart.js` :
`00d5dad6f4c0e294d03531398e7176575a65c60c2cadc21dd92780060a2760d8`.

Les 17 tests du Générateur valident l'envoi automatique après transcription,
l'absence de double envoi, la transcription vide, la sortie de l'écran et
l'interruption pendant la transcription. Une interruption invalide localement
le résultat audio avant l'envoi conversationnel, sans attendre une annulation
serveur. Ces tests n'effectuent aucun appel IA payant.

Les 10 tests ciblés cache/calendrier passent, ainsi que les 2 tests Deno de
livraison et les 6 tests Python de vérification des publications. Le passage
du 10 au 5 octobre sur la démo affiche les 13 rencontres archivées ; un détail
KHL s'ouvre avec ses périodes finales. La publication conserve 42 rencontres
avec observations de cotes. La migration SQL décrite plus haut reste en attente
d'autorisation et n'a pas été appliquée.
