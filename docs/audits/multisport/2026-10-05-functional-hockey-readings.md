# Première version fonctionnelle des lectures hockey

Branche : `codex/multisport-hockey`. Travail local, sans publication sur main,
sans migration SQL et sans déploiement Supabase. Aucun nouvel appel fournisseur
n'est nécessaire pour calculer les lectures : elles utilisent le compact existant.

Après validation de l'utilisateur, la démo a été actualisée sur Vercel :
https://lector-sports-fbc1ucpk4-lector1.vercel.app/sports/hockey
(`dpl_29dtTeakBDnqU3z4AZz6VAyY6FhC`, `READY`). Main et la production football
restent inchangés. Voir le [rapport de publication](2026-10-05-remote-demo.md).

## Parcours à vérifier

1. Choisir Hockey dans le sélecteur de sport.
2. Sans configuration hockey, « Pour moi » reste vide. Les préférences football
   ne sont jamais copiées, même avec le même compte connecté.
3. Ouvrir « Configurer mon hockey » ou le bouton « Mes préférences hockey »
   à côté du titre Hockey. Choisir au moins une compétition et une lecture,
   puis enregistrer. Tous les choix sont désactivés au premier accès.
4. « Pour moi » affiche les rencontres de ces compétitions présentant au moins
   une lecture activée et détectée. Une donnée insuffisante n'est pas un signal.
5. « Tous » garde l'exploration par pays puis ligue. Radar garde son exploration.
   Les cartes de ces deux sections montrent les lectures activées, y compris
   dans les ligues non suivies, comme le football. Les choix de compétitions
   filtrent les propositions personnelles, pas la découverte.
6. Ouvrir une rencontre : les lectures activées précisent l'équipe concernée,
   l'état (détectée, non détectée, données insuffisantes), l'explication et la
taille de l'échantillon.
7. Désactiver toutes les lectures ou toutes les compétitions : « Pour moi »
   redevient vide. Revenir au football conserve ses choix et ses calculs.

Les badges réutilisent le composant extrait du football `LectorReadingPill`.
Les cartes, thèmes, navigation, calendrier et détail restent les composants
partagés. Les calculs hockey sont dans le module hockey, sans modèle football.

## Périmètre des règles

| Lecture | Condition initiale |
| --- | --- |
| Avantage au classement | Au moins 10 matchs par équipe, classement comparable et écart d'au moins 15 points de pourcentage des points disponibles |
| Avantage de forme | 5 matchs terminés par équipe dans cette compétition/saison, écart d'au moins 20 points de pourcentage |
| Série de victoires | Au moins 3 dernières victoires consécutives, prolongations et tirs au but inclus |

Les seuils `hockey-readings-draft-v1` sont des hypothèses de première étape,
pas des seuils calibrés ni une mesure de rentabilité. Les ID restent distincts
des lectures football non équivalentes (voir la matrice du catalogue).

NHL/AHL/KHL : 2 points pour une victoire, 1 pour une défaite après OT/TAB.
Extraliga/Magnus/Liiga/SHL : 3 pour une victoire en temps réglementaire,
2 après OT/TAB, 1 pour une défaite après OT/TAB. Aucun barème par défaut
n'est choisi pour une ligue ou une saison inconnue.

Un classement doit réellement contenir les deux équipes dans un même tableau
régulier fourni par l'API. Deux rangs de divisions différentes ne sont pas
comparés. Les vues multiples ne sont pas additionnées ; une divergence entre
leurs nombres de matchs ou points rend la lecture de classement indisponible.
Les autres lectures peuvent rester utilisables.

Les historiques sont chronologiquement ordonnés, dédupliqués et contrôlés
avant le coup d'envoi. Un résultat inconnu, futur, d'un autre sport/fournisseur
ou hors de la période régulière ne peut pas créer artificiellement une série.

## Limites explicites

- La persistance de cette première étape est **locale au navigateur**, isolée
  par compte/invité et sport. Recharger conserve les choix ; changer d'appareil
  ou de domaine ne les synchronise pas encore. Aucun stockage privé Supabase
  n'a été ajouté dans cette itération.
- La collecte ne certifie pas la phase de chaque match. On combine le marqueur
  de prudence existant `formPhaseVerified` et des bornes de calendrier pour les
  sept saisons 2026 étudiées. Ces bornes ne remplacent pas une identité de phase.
  L'historique NHL reste bloqué lorsque le collecteur le marque non vérifié.
- NHL, AHL, Liiga : borne conservatrice au 1er mars 2027. KHL : 20 mars,
  Extraliga : 5 mars, Magnus : 2 mars, SHL : 16 mars inclus. En dehors de cette
  première fenêtre régulière, aucune lecture n'est produite. Les nouvelles
  saisons et les playoffs devront recevoir leur propre politique vérifiée.
- Les lectures sont évaluées à la date de capture du compact, pour les matchs
  alors à venir. Cette étape ne conserve pas encore une archive d'évaluation
  d'avant-match par rencontre. Un compact recueilli après le coup d'envoi ne
  sert jamais à fabriquer une ancienne prédiction ; live et terminé affichent
  l'absence d'une évaluation conservée. Il faudra une persistance des évaluations
  pour le suivi live des lectures et le bilan hockey.
- Les scénarios, marchés/cotes hockey et autres candidats du catalogue ne sont
  pas activés par cette étape.

## Audit du compact réel

Source : `var/sports/hockey/published.json`, capture du 4 octobre 2026 à
19:58:28.037 UTC, 475 rencontres sur sept ligues. Évaluation hors ligne de tous
les détecteurs, indépendamment des choix d'un utilisateur, au moment de capture.

| Ligue | Rencontres du compact | Rencontres avec au moins une lecture |
| --- | ---: | ---: |
| NHL | 132 | 0 |
| AHL | 78 | 0 |
| KHL | 81 | 45 |
| Liiga | 54 | 20 |
| Ligue Magnus | 38 | 10 |
| Extraliga | 47 | 11 |
| SHL | 45 | 20 |
| Total | 475 | 106 |

Les 106 sont des rencontres futures à la capture, sur l'ensemble de la fenêtre,
pas 106 rencontres du jour. Les nombres ne préjugent pas du prochain compact.
NHL/AHL : moins de 10 matchs pour le classement, historiques trop courts et,
pour la NHL, séparation de présaison non vérifiée. Zéro lecture est attendu
avec ces données et ces seuils.

Exemples du **5 octobre** (heures UTC, extérieur → domicile) :

- 14:00, KHL : Vladivostok → Magnitogorsk. Magnitogorsk : classement
  +38,3 points de pourcentage, forme +40 sur cinq matchs.
- 15:00, KHL : Shanghai → Lada. Shanghai : forme +90 points de pourcentage.
- 16:30, KHL : Salavat Ufa → CSKA Moscow. CSKA : forme +60 et série de victoires.

Pour reproduire sans consommation API :

```bash
dart run tool/sports/audit_hockey_readings.dart var/sports/hockey/published.json
```

## Vérifications

- `flutter analyze --no-pub` : aucune anomalie.
- `dart format --output=none --set-exit-if-changed .` : 354 fichiers,
  aucun changement nécessaire.
- Suite complète : 702 tests réussis, 2 diagnostics optionnels ignorés et
  2 tests NHL dont les sélecteurs étaient devenus ambigus/inadaptés au nouveau
  choix initial de Stats. Ces deux tests sont corrigés : sélecteurs limités au
  hero pour l'ordre extérieur/domicile et sélection explicite de Contexte.
  Relance du fichier NHL : 4 tests réussis, aucun échec.
- Relance finale des calculs, préférences et parcours hockey : les 26 autres
  tests de cette sélection réussissent également. Aucun échec restant connu.
- `git diff --check` : aucune erreur d'espacement.

Tests ajoutés : aucune activation implicite, persistance/rechargement,
isolation utilisateur/sport, refus des préférences corrompues ou étrangères,
sélection selon les choix, lecture hors compétition suivie dans la découverte,
barèmes 2/3 points, classement inter-groupes, vues incohérentes, chronologie,
phase non vérifiée, absence de recalcul après coup d'envoi. Parcours de sélection
et détail vérifiés à 360 et 1100 pixels, avec changement de compte pendant une
lecture asynchrone.

Comparaison avec `lector-football-production-audit` : tous les fichiers Dart
de `lib/features/matches/domain` et `lib/features/onboarding/domain` restent
identiques octet pour octet. L'extraction du badge football garde son style et
ne change aucune règle de lecture, profil, opportunité ou scénario football.

## Lancement local

```bash
cd /Users/chloe/Documents/Codex/2026-09-16/c-2/lector-api-football-orchestration
SPORT_PREVIEW_PORT=8110 bash tool/run_multisport_local.sh 8191 release
```

Adresse : `http://localhost:8191/sports/hockey`. Le script inclut la configuration
Supabase du football. Si 8191 est déjà occupé par le précédent lancement, le
quitter avec `q` dans son terminal avant de relancer. Lorsque 8110 sert déjà
le compact de ce projet, il est réutilisé sans collecte supplémentaire.
