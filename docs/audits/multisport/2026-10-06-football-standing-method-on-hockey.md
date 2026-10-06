> Mise au point du 6 octobre : cette simulation concerne les **zones statistiques isolées** de la lecture football, pas les tiers T1–T5. Elle reste un historique d’audit ; la décision mise en œuvre pour le hockey est documentée dans `2026-10-06-hockey-standing-tiers.md`.

# Simulation de la méthode football sur les classements hockey

Date : 6 octobre 2026. Branche : `codex/multisport-hockey`.

## Périmètre

Cette étude répond à la demande de six cas réels avant validation d'une règle.
Les seuils fixes de 10 ou 15 points ne sont pas retenus. Aucun moteur de lecture,
préférence, flux publié ou déploiement n'est modifié.

Source : `var/sports/hockey/published.json`, capture du
**5 octobre 2026 à 17:08:08.900 UTC**, soit 19:08 à Paris. Les dates de rencontres
ci-dessous sont celles du calendrier publié. Les bilans sont tous ceux de cette
capture, pas des bilans anticipés à la date future du match.

## Méthode effectivement exécutée

Le script `tool/sports/audit_hockey_football_standing_method.dart` appelle
directement `ChampionshipContextReferenceBuilder.distributionForValues` avec
la métrique `pointsPerGame`. Ce calcul est identique à celui de `main` au moment
de l'étude, vérifié par `git diff main` sur le builder et les modèles.

1. Choisir la plus grande table régulière réelle du fournisseur contenant les
   deux équipes, dans la même compétition et la même saison.
2. Vérifier la cohérence des points et des matchs joués des deux équipes dans
   les différentes vues de classement.
3. Appliquer le minimum hockey proposé de **cinq matchs pour chaque adversaire**.
4. Construire la distribution des points par match à partir des équipes ayant
   au moins un match joué. Le calcul football exige dix équipes de référence,
   ce qui ne signifie pas dix matchs par équipe.
5. Exécuter le calcul football : trier les moyennes, mesurer les écarts entre
   voisins, identifier les ruptures supérieures à Q3 + 1,5 × IQR et les groupes
   compacts isolés aux extrémités de la distribution.
6. Détecter une supériorité lorsque les zones des adversaires diffèrent et
   qu'au moins un appartient à une zone isolée. Le sujet est l'équipe mieux
   classée, comme dans `FootballAnalyzer._hierarchyReadings`.

Cette étude ne simule pas `structural_level_gap`, qui utilise les frontières
structurelles confirmées et leur historique. Elle concerne seulement la
supériorité au classement. Elle ne transforme pas les points en pourcentage.

Le calcul en points par match tient compte des matchs en retard. Aucun blocage
automatique à deux matchs d'écart n'a été ajouté : il ne fait pas partie de
cette méthode football. Les six cas retenus ont tous au plus un match d'écart.

## Six cas réels

Les rencontres sont notées extérieur → domicile.

| Rencontre | Compétition / date | Équipe A : rang, points, matchs, points/match | Équipe B : rang, points, matchs, points/match | Résultat simulé |
| --- | --- | --- | --- | --- |
| Mountfield HK → Třinec | Extraliga, 9 octobre | Mountfield : 4e, 13 pts, 8 matchs, 1,625 | Třinec : 1er, 24 pts, 8 matchs, 3,000 | Supériorité Třinec |
| Třinec → Pardubice | Extraliga, 11 octobre | Třinec : 1er, 24 pts, 8 matchs, 3,000 | Pardubice : 2e, 21 pts, 9 matchs, 2,333 | Supériorité Třinec |
| Spartak Moscou → Sochi | KHL, 7 octobre | Spartak : 6e Ouest, 12 pts, 12 matchs, 1,000 | Sochi : 11e Ouest, 4 pts, 11 matchs, 0,364 | Supériorité Spartak |
| Vladivostok → Magnitogorsk | KHL, 7 octobre | Vladivostok : 10e Est, 9 pts, 11 matchs, 0,818 | Magnitogorsk : 1er Est, 19 pts, 12 matchs, 1,583 | Pas de supériorité détectée |
| Jukurit → KooKoo | Liiga, 9 octobre | Jukurit : 2e, 22 pts, 11 matchs, 2,000 | KooKoo : 17e, 1 pt, 10 matchs, 0,100 | Pas de supériorité détectée |
| Marseille → Amiens | Magnus, 16 octobre | Marseille : 2e, 17 pts, 7 matchs, 2,429 | Amiens : 11e, 4 pts, 7 matchs, 0,571 | Pas de supériorité détectée |

### Explications

- **Třinec / Mountfield** : Třinec est seul dans la zone haute isolée du classement
  à quatorze équipes. Mountfield n'est pas dans cette zone.
- **Třinec / Pardubice** : la même séparation s'applique malgré seulement trois
  points d'écart brut ; Pardubice a aussi joué un match de plus.
- **Spartak / Sochi** : Lada et Sochi constituent une zone basse isolée dans la
  conférence Ouest à onze équipes. Spartak est hors de ce groupe, sans être
  lui-même classé dans une zone haute.
- **Magnitogorsk / Vladivostok** : aucune zone haute ou basse isolée n'est
  détectée dans la conférence Est. Les dix points d'écart n'imposent aucun signal.
- **Jukurit / KooKoo** : aucune zone n'est retenue. Le dernier écart voisin est
  de 0,627 point/match (Jokerit 0,727 → KooKoo 0,100), inférieur au seuil de
  rupture calculé de 0,640. Les 21 points séparant les adversaires ne déclenchent
  donc pas cette méthode.
- **Marseille / Amiens** : aucune zone isolée n'est retenue parmi les douze
  équipes ; les treize points d'écart n'entraînent pas de détection.

## Résultat global et limites

Sur les 313 rencontres futures au moment de la capture : neuf détections,
123 non-détections et 181 abstentions (échantillon, référence trop petite ou
absence de table commune). Ces nombres comptent des rencontres : certains
adversaires se retrouvent plusieurs fois dans le calendrier.

Une non-détection signifie seulement que cette lecture ne se déclenche pas.
Elle ne signifie ni égalité de niveau, ni absence d'un avantage sportif réel,
ni impossibilité d'autres lectures.

La reprise exacte apparaît sélective dans cette photographie : il n'y a de
zones isolées que dans l'Extraliga et la conférence Ouest KHL. Les cas Jukurit /
KooKoo et Marseille / Amiens doivent être montrés avant de valider ce transfert.
Une calibration différente serait une décision explicite, pas un ajustement
automatique pour faire produire davantage de signaux.

Les divisions NHL de huit équipes n'atteignent pas le minimum football de dix
équipes de référence ; une conférence réelle de seize équipes peut servir de
référence lorsque les deux adversaires s'y trouvent. Les confrontations entre
conférences restent non évaluables dans cette simulation si le fournisseur ne
donne aucune table commune. Aucun rang global synthétique n'a été fabriqué.

La NHL n'a pas encore cinq matchs par adversaire dans cette capture. Aucun
exemple positif NHL ne peut être produit honnêtement à partir de ces données.

## Reproduction

```sh
dart run tool/sports/audit_hockey_football_standing_method.dart
```

Le script ne réalise aucun appel API et n'écrit pas dans la publication.
