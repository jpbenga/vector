# Lectures hockey : tiers, dynamique, forme et séries

Date : 6 octobre 2026. Branche : `codex/multisport-hockey`.

> Mise à jour : les séries par lieu, leur catalogue et les confrontations sont
> décrits dans [l’itération du 7 octobre](2026-10-07-venue-momentum-and-h2h.md).

## Périmètre réalisé

Le moteur hockey évalue dix lectures explicables par équipe. L'utilisateur
sélectionne ses compétitions et ses lectures dans les préférences hockey.
`Pour moi` exige ces deux choix et une lecture détectée. Les nouveaux identifiants
ne sont pas activés silencieusement, dans aucun des deux sports. Le Radar conserve
sa fonction de découverte et peut montrer les lectures choisies hors des
compétitions suivies.

Les composants existants de classement, de radar, de pastilles et de détail des
preuves sont conservés. La dynamique négative emploie la couleur et l'icône
négatives du thème. Les séries ont un indicateur compact `En série · 3 V`, ou
`En série · ≥5 V` lorsque le début exact est inconnu.

## Règles de cette itération

| Lecture | Règle hockey |
| --- | --- |
| Avantage au classement | Tiers Lector supérieur, rang et points supérieurs, rendement supérieur, dans le même classement réel ; au moins cinq matchs et au plus un match joué d'écart. Aucun écart fixe de 10/15 points et aucun classement par pourcentage. |
| Écart de niveau structurel | Les mêmes prérequis, avec une frontière forte ou plusieurs frontières confirmées par le moteur de tiers. Des tiers simplement différents ne prouvent pas automatiquement cette lecture. |
| Dynamique positive | Cinq résultats ; des points à chaque match et au moins 6/10 ou 9/15 selon le barème. Ce sont des points obtenus régulièrement, pas nécessairement cinq victoires. |
| Dynamique négative | Cinq résultats ; au plus 2/10 ou 4/15 selon le barème. |
| Forme en hausse | Moyenne des deux derniers matchs moins moyenne des trois précédents : au moins 2/3 point dans un barème à deux points, ou 1 point dans un barème à trois points. |
| Écart de forme | Cinq résultats par adversaire ; neuf points réels supplémentaires pour l'équipe concernée, dans le même barème. |
| Avantage de forme | Lecture existante conservée, distincte de l'écart marqué : au moins 2 points sur 10 ou 3 sur 15 d'écart. |
| Série de victoires | Trois victoires finales consécutives minimum, tous lieux confondus. |
| Série de victoires à domicile | Trois réceptions gagnées consécutivement ; les déplacements ne coupent pas la série. Applicable à l'équipe qui reçoit lors du match étudié. |
| Série de victoires à l'extérieur | Trois déplacements gagnés consécutivement ; les réceptions ne coupent pas la série. Applicable à l'équipe qui se déplace lors du match étudié. |

Les séries incluent les victoires après prolongation et tirs au but. Une défaite
après prolongation peut rapporter un point de classement, mais coupe la série de
victoires. Le comptage continue au-delà de cinq ; les détails distinguent la
quatrième victoire en jeu, la cinquième en jeu et le jalon atteint. Aucune
probabilité de rupture n'est déduite de cette longueur.

Les règles de points sont sélectionnées explicitement par compétition : NHL,
AHL et KHL à deux points ; Extraliga, Magnus, Liiga et SHL à trois points dans la
politique régulière 2026 vérifiée. Un sport ou une saison inconnus ne reçoivent
pas automatiquement les règles NHL.

Le [travail sur les tiers](2026-10-06-hockey-standing-tiers.md) couvre également
les classements général, domicile et extérieur et leurs badges DOM./EXT. Les
lectures de cette itération utilisent le classement général commun réel le plus
spécifique : division si les deux adversaires y appartiennent, sinon conférence
réelle lorsque disponible. Les rangs de divisions distinctes ne sont jamais
comparés directement et aucun classement inter-conférences synthétique n'est
inventé.

## Séparation et réutilisation

- `core/domain/lector_form_reading_policy.dart` : fenêtre de cinq résultats,
  dynamique positive/négative et comparaison deux contre trois. Le football
  utilise un maximum de trois points et conserve ses seuils et résultats
  antérieurs ; le hockey fournit le barème de sa ligue.
- `core/domain/lector_victory_series.dart` : compteur commun aux deux sports et
  au radar. Les adaptateurs fournissent les résultats et le lieu des matchs.
- `HockeyStandingTiers` : même noyau de partition que le football, avec les
  repères de groupe du hockey ; expose les séparations confirmées du noyau pour
  la lecture structurelle.
- `HockeyFeedReadings` : vérification des identités, de la saison, de la phase,
  de la chronologie et des preuves. Il ne consulte pas le profil football.
- `FootballAnalyzer`, catalogue, guides et filtres football : ajout des trois
  séries, sans changer les anciennes dynamiques ni les règles des scénarios.
- Publication football Supabase : ajout des mêmes trois séries dans
  `publish-reading-announcements`, avec leur preuve et leur issue `team_win`.
  Le contrat du compteur serveur TypeScript est vérifié avec les mêmes cas
  fonctionnels que le compteur Dart. Les autres lectures serveur sont inchangées.

Un historique de saison hockey n'est ajouté aux cinq résultats de la rencontre
que si ses identités uniques recouvrent le nombre officiel de matchs joués.
Sinon, on conserve le préfixe récent connu : des trous dans un historique
partiel ne peuvent pas créer artificiellement une longue série. Les doublons
contradictoires ou les matchs futurs ne constituent pas des preuves. Quand le
résultat qui précède la série n'est pas connu, le nombre est une borne minimale.

Les futures lectures gardien, situations numériques et repos restent à définir.

## Vérification sans appel fournisseur

Publication locale lue : `var/sports/hockey/published.json`, capture du
**5 octobre 2026 à 17:08:08.900 UTC**. Ces chiffres décrivent cette capture,
pas les résultats en direct du 6 octobre. Les détections sont comptées par
rencontre et équipe, donc une même équipe peut apparaître plusieurs fois.

| Ligue | Avantage classement | Écart structurel | Dynamique + | Dynamique − | Forme hausse | Écart forme | Série générale | Série domicile | Série extérieur |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| KHL | 20 | 2 | 12 | 12 | 25 | 0 | 9 | 4 | 4 |
| Extraliga | 13 | 0 | 7 | 16 | 11 | 6 | 15 | 4 | 4 |
| Liiga | 16 | 0 | 5 | 8 | 15 | 5 | 5 | 7 | 6 |
| SHL | 0 | 0 | 8 | 12 | 12 | 2 | 16 | 5 | 0 |
| Magnus | 10 | 0 | 9 | 8 | 6 | 2 | 7 | 3 | 2 |
| NHL / AHL | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

L'absence de lecture NHL/AHL dans cette publication est une abstention lorsque
la phase régulière ou l'échantillon requis ne sont pas encore exploitables.

Exemples issus du fichier, sans nouvelle collecte :

- Khabarovsk–Tractor, 6 octobre à 14:00 UTC : une série générale de trois
  victoires est détectée, quatrième victoire en jeu.
- Cherepovets–SKA, 6 octobre à 16:30 UTC : série à domicile de cinq victoires.
- Ilves–Vaasan Sport, 7 octobre à 15:30 UTC : 15/15 contre 5/15 sur cinq matchs,
  donc dix points d'écart et dépassement du seuil de neuf.
- Lokomotiv–Sochi, 17 octobre à 14:00 UTC : frontière confirmée entre T1 et T5
  dans le classement commun de la conférence Ouest KHL.

Contrôles effectués :

- 233 tests Flutter ciblés passés : tiers, règles hockey, moteur football,
  opportunités, préférences et guides, composants de classement, thèmes.
- Tests complémentaires des indicateurs radar et du compteur commun.
- Cinq tests serveur passés, dont le vrai gestionnaire de publication exécuté
  avec une base simulée et le parcours de calendrier quatorze jours.
- `flutter analyze --no-pub` : aucun problème.
- `git diff --check` : aucune erreur d'espacement.

## Consultation et publication

Le code et les tests restent sur la branche multisport, sans push ni déploiement.
Les lectures hockey sont recalculées à partir du compact local dès le prochain
lancement de cette version. Il faut sélectionner les lectures souhaitées dans
`Hockey → Paramètres → Mes lectures` et suivre les compétitions correspondantes.

Le radar football dispose localement du nouvel indicateur. Les nouvelles
lectures de séries des cartes football alimentées par Supabase apparaîtront
après déploiement de la fonction de publication et un nouveau cycle de snapshots.
Le client conserve son contrat de lecture du calcul serveur ; il ne réécrit pas
les anciennes annonces ni n'ajoute un calcul concurrent aux snapshots distants.
Aucune migration SQL et aucun nouvel endpoint fournisseur ne sont nécessaires.
La démo et la production ne sont pas actualisées dans cette itération.
