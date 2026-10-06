# Radar des équipes : fenêtre récente et historique

## Cause

Le hockey publiait uniquement cinq résultats par équipe et départageait les
égalités par le nom. Le football possédait un départage au sixième puis au
septième résultat, mais son adaptateur de snapshot tronquait l'activité à cinq.
Le composant de résultats affichait également les cinq premiers éléments au
lieu des cinq derniers lorsque l'activité contenait davantage de matchs.

## Contrat commun

`LectorTeamFormPolicy` classe sur les cinq derniers résultats terminés, puis
compare le sixième, le septième, le huitième, etc. uniquement en cas d'égalité.
Les matchs antérieurs manquants ne sont pas remplacés par des défaites.
Le football conserve son barème 3/1/0 et sa série sans défaite ; le hockey conserve
le nombre de victoires (OT et tirs au but inclus) et sa série de victoires.

Le même `LectorRadarTeamRow` et `LectorFormResultStrip` affiche les deux sports.
À gauche : jusqu'à cinq résultats précédents visibles, défilement horizontal si
l'historique est plus long. À droite : les cinq derniers, séparés par la couleur
d'accent du thème. Les clics conservent l'indice du match dans l'historique complet.
Sur les petits écrans, la matrice passe sous l'identité pour conserver les noms.

## Hockey : collecte et compatibilité

La publication ajoute `formHistory` aux lignes de classement ; `form` et les
formes avant-match restent limitées à cinq, sans modifier les entrées des lectures.
Le lecteur accepte les anciennes publications et vérifie que la fin de l'historique
correspond exactement à `form`. Chronologie, identités uniques et résultats
cohérents avec les scores sont vérifiés.

`rebuild_hockey_team_history.ts` reconstruit depuis les réponses saison déjà
conservées, sans appel fournisseur ni changement d'horodatage. Publication du
5 octobre : KHL jusqu'à 13 matchs, Extraliga 9, Magnus 8, Liiga 11, SHL 6.
NHL reste exclue du radar classé faute de phase vérifiable ; AHL a moins de cinq
résultats. Les groupes de classement ne dupliquent pas les équipes.

## Livraison

Branche `codex/multisport-hockey`. Aucune modification de main ni migration SQL.
Les résultats déjà conservés sont utilisés ; aucun appel API supplémentaire.

## Vérification et démo

- 33 tests Flutter réussis : départage 6/7/8, fenêtre principale, adaptation
  football, absence de phase, groupes sans doublons, compatibilité publication,
  indices de clic et défilement, pagination, profils et largeurs 320/390/1100.
- 8 tests Deno réussis sur la collecte/publication hockey ; aucun appel fournisseur
  pendant la reconstruction et la vérification.
- Analyse Flutter : aucune anomalie sur les fichiers concernés.
- Contrôle réel mobile 390×844 : football et hockey ont la même ligne d'équipe,
  légende et séparation. Hockey : clic sur le sixième match de CSKA Moscow
  affiche Vladivostok, 21 septembre, extérieur, score 4–3. Captures dans
  `output/qa/2026-10-06-team-history/`.
- Compilation release réussie. Déploiement preview READY
  `dpl_3NhGsSgeK3nfXeRtxKZkLKntizez` ; alias habituel
  `https://lector-sports-demo-lector1.vercel.app`.
