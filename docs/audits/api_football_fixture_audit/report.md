# Audit API-Football d'une rencontre Premier League

Date d'audit : 2026-08-03  
Objectif : inventorier la matiere premiere réellement disponible avant de definir de nouvelles lectures football.

## Rencontre retenue

Rencontre : Manchester City - Aston Villa  
Fixture ID : `1379344`  
Competition : Premier League, API-Football league `39`  
Saison API : `2025`, soit saison 2025/2026  
Date : 2026-05-24 15:00 UTC  
Statut : `FT`, match termine  
Score : Manchester City 1 - 2 Aston Villa  
Stade : Etihad Stadium, Manchester  
Arbitre : A. Madley

Raisons du choix :
- match termine de Premier League, derniere journee de la saison precedente terminee au moment de l'audit ;
- deux clubs tres couverts par API-Football ;
- donnees post-match completes : statistiques, evenements, lineups, joueurs ;
- donnees de contexte disponibles : classement, statistiques de saison, effectifs, coachs, stade, H2H ;
- endpoint predictions disponible ;
- endpoint odds teste explicitement, mais sans historique retourne sur cette fixture.

## Fichiers produits

- Inventaire exhaustif des chemins JSON observes : `docs/audits/api_football_fixture_audit/field_inventory.tsv`
- Reponses HTTP : `docs/audits/api_football_fixture_audit/http_responses.tsv`
- Exemples JSON tronques : `docs/audits/api_football_fixture_audit/raw_examples.md`
- Reponses JSON completes : `docs/audits/api_football_fixture_audit/raw/`

L'inventaire contient 1685 chemins JSON observes sur les 32 reponses utiles avec les colonnes demandees :
`Domaine`, `Endpoint/source`, `Chemin JSON exact`, `Type`, `Exemple reel`, disponibilites temporelles, fiabilite, presence dans le projet, utilisation moteur.

## Endpoints appeles

Tous les appels ci-dessous ont repondu HTTP `200`. Les erreurs fonctionnelles et reponses vides sont celles renvoyees dans le JSON API-Football.

| Fichier | Endpoint | Resultat |
|---|---|---:|
| `01_fixture_1379344.json` | `/fixtures?id=1379344` | 1 |
| `02_fixture_statistics.json` | `/fixtures/statistics?fixture=1379344` | 2 |
| `03_fixture_events.json` | `/fixtures/events?fixture=1379344` | 16 |
| `04_fixture_lineups.json` | `/fixtures/lineups?fixture=1379344` | 2 |
| `05_fixture_players.json` | `/fixtures/players?fixture=1379344` | 2 |
| `06_injuries_fixture.json` | `/injuries?fixture=1379344` | 6 |
| `07_predictions.json` | `/predictions?fixture=1379344` | 1 |
| `08_odds_prematch_fixture.json` | `/odds?fixture=1379344` | 0 |
| `09_odds_live_fixture.json` | `/odds/live?fixture=1379344` | 0 |
| `10_standings_pl_2025.json` | `/standings?league=39&season=2025` | 1 |
| `11_team_statistics_man_city.json` | `/teams/statistics?league=39&season=2025&team=50` | 11 |
| `12_team_statistics_aston_villa.json` | `/teams/statistics?league=39&season=2025&team=66` | 11 |
| `13_fixtures_man_city_before.json` | `/fixtures?league=39&season=2025&team=50&from=2025-08-01&to=2026-05-23` | 37 |
| `14_fixtures_aston_villa_before.json` | `/fixtures?league=39&season=2025&team=66&from=2025-08-01&to=2026-05-23` | 37 |
| `15_fixtures_man_city_season.json` | `/fixtures?league=39&season=2025&team=50` | 38 |
| `16_fixtures_aston_villa_season.json` | `/fixtures?league=39&season=2025&team=66` | 38 |
| `17_head_to_head.json` | `/fixtures/headtohead?h2h=50-66&last=10` | 10 |
| `18_squad_man_city.json` | `/players/squads?team=50` | 1 |
| `19_squad_aston_villa.json` | `/players/squads?team=66` | 1 |
| `20_players_man_city_page1.json` | `/players?league=39&season=2025&team=50&page=1` | 20 |
| `30_players_man_city_page2.json` | `/players?league=39&season=2025&team=50&page=2` | 16 |
| `21_players_aston_villa_page1.json` | `/players?league=39&season=2025&team=66&page=1` | 20 |
| `31_players_aston_villa_page2.json` | `/players?league=39&season=2025&team=66&page=2` | 20 |
| `22_coaches_man_city.json` | `/coachs?team=50` | 1 |
| `23_coaches_aston_villa.json` | `/coachs?team=66` | 2 |
| `24_team_man_city.json` | `/teams?id=50` | 1 |
| `25_team_aston_villa.json` | `/teams?id=66` | 1 |
| `26_venue_etihad.json` | `/venues?id=555` | 1 |
| `27_league_pl_2025.json` | `/leagues?id=39&season=2025` | 1 |
| `28_odds_bookmakers.json` | `/odds/bookmakers` | 33 |
| `29_odds_bets.json` | `/odds/bets` | 338 |
| `32_odds_by_date_pl_2025.json` | `/odds?league=39&season=2025&date=2026-05-24` | 0 |

Note API verifiee : l'appel initial `fixtures?...&to=2026-05-23&last=5` a renvoye l'erreur fonctionnelle `The To field cannot be used with Last field.`. La collecte a donc ete refaite avec `from/to`, puis les 5 derniers matchs sont derivables localement.
Les deux reponses d'erreur sont conservees dans `raw/33_invalid_fixtures_man_city_to_last.json` et `raw/34_invalid_fixtures_aston_villa_to_last.json`.

## Inventaire representatif des champs

Le detail exhaustif est dans `field_inventory.tsv`. Extraits importants :

| Domaine | Endpoint | Chemin JSON exact | Exemple reel | Temporalite |
|---|---|---|---|---|
| Identite match | `/fixtures` | `response[].fixture.id` | `1379344` | avant / live / apres |
| Identite match | `/fixtures` | `response[].fixture.date` | `2026-05-24T15:00:00+00:00` | avant / live / apres |
| Identite match | `/fixtures` | `response[].fixture.timezone` | `UTC` | avant |
| Identite match | `/fixtures` | `response[].fixture.referee` | `A. Madley` | avant ou jour du match |
| Statut | `/fixtures` | `response[].fixture.status.short` | `FT` | live / apres |
| Statut | `/fixtures` | `response[].fixture.status.elapsed` | `90` | live / apres |
| Statut | `/fixtures` | `response[].fixture.status.extra` | `12` | live / apres |
| Score | `/fixtures` | `response[].goals.home` | `1` | live / apres |
| Score detaille | `/fixtures` | `response[].score.halftime.home` | `1` | live / apres |
| Score detaille | `/fixtures` | `response[].score.extratime.home` | `null` | apres |
| Score detaille | `/fixtures` | `response[].score.penalty.home` | `null` | apres |
| Competition | `/fixtures` | `response[].league.id` | `39` | avant |
| Competition | `/fixtures` | `response[].league.round` | `Regular Season - 38` | avant |
| Equipes | `/fixtures` | `response[].teams.home.id` | `50` | avant |
| Equipes | `/fixtures` | `response[].teams.home.winner` | `false` | apres |
| Stade | `/venues` | `response[].name` | `Etihad Stadium` | stable |
| Classement | `/standings` | `response[].league.standings[][].rank` | `2` | avant si snapshot avant match ; ici final |
| Classement | `/standings` | `response[].league.standings[][].all.goals.for` | `77` | avant si snapshot avant match ; ici final |
| Classement domicile | `/standings` | `response[].league.standings[][].home.win` | observe | avant si snapshot avant match ; ici final |
| Classement exterieur | `/standings` | `response[].league.standings[][].away.lose` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.fixtures.played.home` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.goals.for.average.total` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.biggest.wins.home` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.clean_sheet.total` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.failed_to_score.total` | observe | avant si snapshot avant match ; ici final |
| Stats saison | `/teams/statistics` | `response.lineups[].formation` | observe | avant si snapshot avant match ; ici final |
| Stats match | `/fixtures/statistics` | `response[].statistics[].type` | `Shots on Goal` | apres |
| Stats match | `/fixtures/statistics` | `response[].statistics[].value` | `3` | apres |
| Stats match | `/fixtures/statistics` | `statistics[].type = expected_goals` | `1.34` | apres |
| Events | `/fixtures/events` | `response[].time.elapsed` | `23` | live / apres |
| Events | `/fixtures/events` | `response[].type` | `Goal` | live / apres |
| Events | `/fixtures/events` | `response[].detail` | `Normal Goal` | live / apres |
| Lineups | `/fixtures/lineups` | `response[].formation` | `4-2-2-2` | apres publication compositions |
| Lineups | `/fixtures/lineups` | `response[].startXI[].player.id` | observe | apres publication compositions |
| Players match | `/fixtures/players` | `response[].players[].statistics[].games.minutes` | observe | live / apres |
| Players match | `/fixtures/players` | `response[].players[].statistics[].shots.on` | observe | live / apres |
| Injuries | `/injuries` | `response[].player.reason` | observe | avant / jour du match |
| Injuries | `/injuries` | `response[].fixture.id` | `1379344` | avant / jour du match |
| Predictions | `/predictions` | `response[].predictions.winner.name` | observe | avant, non factuel |
| Predictions | `/predictions` | `response[].comparison.form.home` | observe | avant, non factuel |
| Odds | `/odds` | `response` | `[]` | vide sur ce test |
| Odds live | `/odds/live` | `response` | `[]` | vide sur ce test |
| Referentiel odds | `/odds/bets` | `response[].id` | observe | stable |
| Referentiel odds | `/odds/bookmakers` | `response[].id` | observe | stable |

## Donnees factuelles importantes observees

Statistiques post-match disponibles :
- tirs cadres, tirs non cadres, tirs totaux, tirs bloques ;
- tirs dans/hors surface ;
- fautes, corners, hors-jeu ;
- possession ;
- cartons jaunes/rouges ;
- arrets gardien ;
- passes totales, passes reussies, precision ;
- `expected_goals` et `goals_prevented`.

Compositions disponibles :
- formations des deux equipes : Manchester City `4-2-2-2`, Aston Villa `4-2-3-1` ;
- titulaires, remplacants, couleurs, coachs ;
- donnees disponibles seulement apres publication des compositions, donc interdites pour une lecture pre-match plusieurs jours avant.

Evenements disponibles :
- 16 evenements : buts, substitutions, cartons ;
- chemins utiles : `time.elapsed`, `time.extra`, `team.id`, `player.id`, `assist.id`, `type`, `detail`, `comments`.

Joueurs disponibles :
- statistiques individuelles du match via `/fixtures/players` ;
- statistiques saison joueur via `/players`, paginees ;
- Manchester City : 36 joueurs recuperes sur 2 pages ;
- Aston Villa : 40 joueurs recuperes sur 2 pages.

Blessures :
- 6 entrees sur la fixture ;
- utilisable factuellement comme absence/raison/statut si l'information existe ;
- impact sportif a calculer uniquement si on le relie objectivement au temps de jeu, titularisations ou contributions.

Predictions API :
- endpoint disponible, mais isole du socle factuel ;
- peut servir de signal externe optionnel ou benchmark, pas de preuve statistique ;
- ne doit pas devenir une verite moteur ni une justification affichee sans contexte.

Cotes :
- `/odds?fixture=1379344` : `response=[]`, HTTP 200 ;
- `/odds?league=39&season=2025&date=2026-05-24` : `response=[]`, HTTP 200 ;
- `/odds/live?fixture=1379344` : `response=[]`, HTTP 200 ;
- conclusion verifiee : sur notre abonnement/integration actuelle, les cotes historiques de cette rencontre terminee ne sont pas retournees. Il faut les capturer avant match dans notre propre stockage si elles sont necessaires plus tard.

## Matrice de disponibilite temporelle

| Famille | Plusieurs jours avant | Jour du match | Apres lineups | Live | Apres match |
|---|---|---|---|---|---|
| Fixture planifiee | oui | oui | oui | oui | oui |
| Stade / ville / competition / equipes | oui | oui | oui | oui | oui |
| Arbitre | variable | oui si publie | oui | oui | oui |
| Classement | oui, mais doit etre snapshot avant match | oui | oui | oui | oui final |
| Team statistics saison | oui, mais doit etre snapshot avant match | oui | oui | oui | oui final |
| Fixtures precedentes | oui | oui | oui | oui | oui |
| H2H | oui | oui | oui | oui | oui |
| Squads / players saison | oui | oui | oui | oui | oui |
| Injuries | variable | oui si publie | oui | oui | oui |
| Lineups | non | proche coup d'envoi | oui | oui | oui |
| Events | non | non | non | oui | oui |
| Fixture statistics | non | non | non | partiel live possible selon endpoint | oui |
| Fixture players | non | non | non | partiel live possible selon endpoint | oui |
| Odds pre-match | oui en theorie | oui avant coup d'envoi | oui avant coup d'envoi | non | non retourne historiquement sur test |
| Odds live | non | non | non | oui en theorie | non retourne historiquement sur test |
| Predictions API | oui si disponible | oui | non pertinent | non pertinent | non pertinent |

Regle produit recommandee : toute lecture pre-match doit etre calculee depuis un snapshot timestampé pris avant le coup d'envoi. Les endpoints de saison appeles apres match donnent l'etat final et ne doivent pas etre utilises retroactivement pour expliquer une decision pre-match.

## Metriques derivables

| Metrique derivee | Sources requises | Formule / regle | Pre-match possible ? | Robustesse | Limites |
|---|---|---|---|---|---|
| Ecart de classement | `/standings` | `rankAway - rankHome` ou inverse selon sujet | oui si snapshot avant match | forte | classement final interdit pour analyse historique |
| Ecart de points | `/standings` | `pointsHome - pointsAway` | oui | forte | depend du moment du snapshot |
| Points par match | `/standings` | `points / all.played` | oui | forte | instable si debut saison |
| Ecart points/match | `/standings` | PPM home - PPM away | oui | forte | idem |
| Forme 5 matchs | `/fixtures?team&to` | compter W/D/L sur les 5 derniers avant date | oui | forte | necessite filtrage local strict avant kickoff |
| Buts marques recents | fixtures precedentes | somme buts equipe / N | oui | forte | qualite adversaires non incluse |
| Buts encaisses recents | fixtures precedentes | somme buts adverses / N | oui | forte | idem |
| Clean sheet rate | `/teams/statistics` ou fixtures | clean_sheet.total / played.total | oui | bonne | split home/away preferable |
| Failed to score rate | `/teams/statistics` | failed_to_score.total / played.total | oui | bonne | split home/away preferable |
| BTTS recent | fixtures precedentes | matchs ou les deux equipes marquent / N | oui | bonne | petit echantillon |
| Over 2.5 recent | fixtures precedentes | matchs total buts > 2.5 / N | oui | bonne | petit echantillon |
| Victoire domicile rate | fixtures ou team stats | home wins / home played | oui | forte | sample home uniquement |
| Defaite exterieur rate | fixtures ou team stats | away losses / away played | oui | forte | sample away uniquement |
| Force offensive relative | team stats + standings | buts pour/match vs moyenne ligue | oui | moyenne | moyenne ligue a calculer/cacher |
| Fragilite defensive relative | team stats + standings | buts contre/match vs moyenne ligue | oui | moyenne | contexte adversaires absent |
| Serie positive/negative | fixtures precedentes | sequence non-defaites/defaites avant date | oui | forte | dates strictes indispensables |
| Qualite adversaires recents | fixtures + standings adversaires | moyenne rang/PPM adversaires | oui | moyenne | requetes/caches supplementaires |
| Divergence cote/lecture | odds + metriques sportives | comparer favori bookmaker vs these | oui si odds capturees | moyenne | odds historiques non disponibles apres coup |
| Impact absence objectif | injuries + players stats | joueur absent avec minutes/titularisations/contributions elevees | oui si injury publiee | moyenne | pas d'impact invente |
| Evaluation post-match lecture | fixture stats + score + events | comparer lecture pre-match au deroule reel | non | forte | seulement feedback qualite, pas prediction |

## Audit du projet existant

Donnees deja recuperees dans les snapshots actuels :
- fixtures ;
- odds ;
- standings ;
- team_statistics.

Donnees deja normalisees dans le domaine :
- identite fixture : id API, date, kickoff label, statut simplifie ;
- competition : id, nom, pays, saison, logo, flag ;
- equipes : id API, nom, logo ;
- score final simple ;
- stade : nom et ville ;
- marches MVP supportes : 1N2, double chance, over/under buts, BTTS, team total home/away, corners, cards ;
- bookmakers cibles : Betfair, Pinnacle, Bwin, Bet365, 1xBet, Unibet ;
- classement simplifie ;
- statistiques equipe simplifiees : forme, joues home/away/total, W/D/L totals, buts for/against totals, moyennes total, clean sheets total, failed to score total.

Donnees deja utilisees par le moteur :
- competition active du profil ;
- marche active du profil ;
- pickType via plage de cote ;
- standings : rang, points, W/D/L, buts, forme ;
- team_statistics : attaque/defense, clean sheets, failed to score, forme ;
- odds normalisees pour selectionner un marche recommande ;
- kickoff pour tri et affichage.

Donnees perdues par l'adapter actuel :
- arbitre, timezone, statut long, elapsed, extra ;
- venue id ;
- league round, league standings flag ;
- `teams.*.winner` ;
- scores mi-temps, prolongation, penalties ;
- standings home/away, update, description, status ;
- details complets de `teams/statistics` : plus larges victoires/defaites, minutes des buts, penalties, cards, lineups, clean_sheet home/away, failed_to_score home/away ;
- tous les events ;
- toutes les lineups ;
- toutes les statistiques joueurs ;
- injuries ;
- predictions API ;
- H2H ;
- squads, players saison, coaches ;
- cotes historiques non stockees au moment pre-match, donc perdues si API ne les renvoie plus.

Incoherences ou points d'attention :
- `MatchThesis.confidence` existe encore comme score visible/transportable, alors que la direction produit prefere "Lecture Copilot", arguments et contradictions ;
- `MatchFeedRepositoryFactory` refuse le mode API direct et exige un backend securise, ce qui est sain pour la cle API ;
- les snapshots permettent une UI stable, mais peuvent figer une date obsolète si aucune strategie de rafraichissement/snapshot journalier n'est en place ;
- le moteur actuel raisonne sur des donnees de saison finalisees si le snapshot est pris apres match : il faut timestamp et contexte "asOf" pour tout futur backtest.

## Estimation du cout en requetes

Pour une rencontre isolee avec le niveau d'audit ci-dessus : 32 appels, dont 2 pages joueurs par equipe et 2 referentiels odds.

Pour une journee optimisee :
- 1 appel fixtures par league/date ;
- 1 appel odds par league/date/bookmaker si disponible avant match ;
- 1 standings par league/season, cacheable ;
- 1 team_statistics par equipe unique, cacheable a la journee ;
- 1 a 2 appels fixtures precedentes par equipe si non pre-calcules ;
- lineups/injuries a rafraichir seulement proche coup d'envoi ;
- events/statistics/fixture players seulement live/post-match ;
- squads/players/coachs/venues fortement cacheables.

Risque quota : eleve si on enrichit chaque match naivement. Pour 100 matchs, `team_statistics` + forme recente par equipe peut depasser 400 appels sans cache. Le stockage doit etre pense par journee, competition, equipe et timestamp, pas par ecran.

## Recommandations d'architecture sans modifier le moteur

1. Creer un stockage brut immutable par endpoint avec `provider`, `endpoint`, `params`, `fetchedAt`, `fixtureId`, `leagueId`, `season`, `teamId`, `httpStatus`, `apiErrors`, `response`.
2. Ajouter une couche `MatchDataSnapshot` timestampée avec `asOf`, pour distinguer pre-match, lineups, live et post-match.
3. Capturer les cotes avant match dans notre stockage ; ne pas dependre d'un historique API qui n'a pas ete retourne sur ce test.
4. Separer les donnees factuelles des `predictions` API dans deux namespaces differents.
5. Normaliser progressivement vers des read-models : `FixtureContext`, `TeamSeasonContext`, `RecentFormContext`, `MarketSnapshot`, `LineupSnapshot`, `PostMatchReview`.
6. Ajouter une table de provenance par argument Copilot : chaque argument doit pointer vers les chemins JSON sources ou metriques derivees.
7. Garder le Football Analyzer, l'Opportunity Engine et le Pick Engine inchanges tant que ces schemas de donnees ne sont pas valides.

## Donnees manquantes ou non fiables

- Cotes pre-match historiques : non retournees pour la fixture et la date testees.
- Cotes live historiques : non retournees.
- `predictions` : disponible mais non factuel.
- Classements et statistiques de saison : fiables seulement si snapshot pris avant match ; appeles apres coup, ils representent l'etat final.
- Blessures : disponibles, mais leur impact sportif n'est pas directement fourni.
- Joueurs cles : non fourni tel quel ; doit etre derive depuis minutes, titularisations, buts, assists ou autres stats objectives.
- Qualite des adversaires recents : derivable mais necessite de joindre fixtures precedentes et standings adversaires au bon `asOf`.

## Checklist de verification

- Fixture principale verifiee : oui.
- Fixture statistics verifiees : oui.
- Fixture events verifies : oui.
- Fixture lineups verifiees : oui.
- Fixture players verifies : oui.
- Injuries verifiees : oui.
- Predictions verifiees et isolees : oui.
- Odds pre-match fixture verifiees : oui, vide.
- Odds live verifiees : oui, vide.
- Odds par date/league verifiees : oui, vide.
- Standings verifies : oui.
- Team statistics domicile/exterieur verifiees : oui.
- Fixtures precedentes verifiees : oui.
- Resultats saison domicile/exterieur derivables : oui.
- Head-to-head verifie : oui.
- Squads verifies : oui.
- Players saison verifies avec pagination : oui.
- Coaches verifies : oui.
- Venue verifie : oui.
- Referentiels bookmakers et bets verifies : oui.
- Code existant inspecte : oui.
- Aucune regle football modifiee : oui.
- Aucune cle API exposee dans les livrables : oui.
