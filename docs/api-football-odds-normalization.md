# Normalisation bookmakers et marchés API-Football

## Catalogues récupérés

- Bookmakers API-Football : `33`
- Marchés API-Football : `338`
- Bookmakers observés dans les snapshots de cotes : `13`
- Marchés observés dans les snapshots de cotes : `179`

Les catalogues bruts complets sont sauvegardés ici :

- `var/api_football_exploration/2026-07-30/odds_bookmakers.json`
- `var/api_football_exploration/2026-07-30/odds_bets.json`

## Bookmakers API-Football

| ID | Nom | Observé dans les snapshots |
|---:|---|---|
| 1 | 10Bet | oui |
| 2 | Marathonbet | oui |
| 3 | Betfair | oui |
| 4 | Pinnacle | oui |
| 5 | SBO | oui |
| 6 | Bwin | non |
| 7 | William Hill | oui |
| 8 | Bet365 | oui |
| 9 | Dafabet | oui |
| 10 | Ladbrokes | non |
| 11 | 1xBet | oui |
| 12 | BetFred | non |
| 13 | 188Bet | non |
| 15 | Interwetten | non |
| 16 | Unibet | oui |
| 17 | 5Dimes | non |
| 18 | Intertops | non |
| 19 | Bovada | non |
| 20 | Betcris | non |
| 21 | 888Sport | non |
| 22 | Tipico | non |
| 23 | Sportingbet | non |
| 24 | Betway | non |
| 25 | Expekt | non |
| 26 | Betsson | non |
| 27 | NordicBet | non |
| 28 | ComeOn | non |
| 30 | Netbet | non |
| 32 | Betano | oui |
| 33 | Fonbet | non |
| 34 | Superbet | oui |
| 36 | BetVictor | oui |
| 37 | Non renseigné | non |

## Marchés prioritaires pour le MVP

| ID API | Libellé API | Marché interne proposé | Valeurs normalisées |
|---:|---|---|---|
| 1 | Match Winner | `match_result` | `home`, `draw`, `away` |
| 2 | Home/Away | `home_away_no_draw` | `home`, `away` |
| 5 | Goals Over/Under | `goals_total` | `over:{line}`, `under:{line}` |
| 8 | Both Teams Score | `both_teams_score` | `yes`, `no` |
| 12 | Double Chance | `double_chance` | `home_or_draw`, `home_or_away`, `draw_or_away` |
| 16 | Total - Home | `team_total_home` | `home_over:{line}`, `home_under:{line}` |
| 17 | Total - Away | `team_total_away` | `away_over:{line}`, `away_under:{line}` |
| 45 | Corners Over Under | `corners_total` | `over:{line}`, `under:{line}` |
| 80 | Cards Over/Under | `cards_total` | `over:{line}`, `under:{line}` |

## Marchés observés dans les snapshots

| ID API | Libellé observé | Fixtures/bookmakers | Exemples de valeurs brutes |
|---:|---|---:|---|
| 1 | Match Winner | 1159/13 | Home, Draw, Away |
| 2 | Home/Away | 645/9 | Home, Away |
| 3 | Second Half Winner | 663/8 | Home, Draw, Away |
| 4 | Asian Handicap | 896/11 | Home -1.25, Away -1.25, Home -1, Away -1, Home -0.75, Away -0.75, Home -0.5, Away -0.5, Home -0.25, Away -0.25 |
| 5 | Goals Over/Under | 960/11 | Over 1.5, Under 1.5, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5, Over 8.5, Under 8.5 |
| 6 | Goals Over/Under First Half | 959/11 | Over 1.5, Under 1.5, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5, Over 2.0, Under 2.0 |
| 7 | HT/FT Double | 734/9 | Home/Draw, Home/Away, Draw/Away, Draw/Draw, Home/Home, Draw/Home, Away/Home, Away/Draw, Away/Away |
| 8 | Both Teams Score | 835/10 | Yes, No |
| 9 | Handicap Result | 481/6 | Home -1, Away -1, Draw -1, Home -3, Draw -3, Away -3, Home -2, Draw -2, Away -2, Home +1 |
| 10 | Exact Score | 878/11 | 1:0, 2:0, 2:1, 3:0, 3:1, 3:2, 4:0, 4:1, 0:0, 1:1 |
| 11 | Highest Scoring Half | 402/5 | Draw, 1st Half, 2nd Half |
| 12 | Double Chance | 961/11 | Home/Draw, Home/Away, Draw/Away |
| 13 | First Half Winner | 1035/12 | Home, Draw, Away |
| 14 | Team To Score First | 269/3 | Home, Away, Draw |
| 15 | Team To Score Last | 268/3 | No goal, Home, Away, Draw |
| 16 | Total - Home | 841/10 | Over 1.5, Under 1.5, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5, Over 4.5, Under 4.5 |
| 17 | Total - Away | 840/10 | Over 1.5, Under 1.5, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5, Over 4.5, Under 4.5 |
| 18 | Handicap Result - First Half | 249/4 | Home -1, Away -1, Draw -1, Home -3, Draw -3, Away -3, Home -2, Draw -2, Away -2, Home +1 |
| 19 | Asian Handicap First Half | 745/9 | Home -1.25, Away -1.25, Home -1, Away -1, Home -0.75, Away -0.75, Home -0.5, Away -0.5, Home -0.25, Away -0.25 |
| 20 | Double Chance - First Half | 554/7 | Home/Draw, Home/Away, Draw/Away |
| 21 | Odd/Even | 749/9 | Odd, Even |
| 22 | Odd/Even - First Half | 420/6 | Odd, Even |
| 23 | Home Odd/Even | 224/3 | Odd, Even |
| 24 | Results/Both Teams Score | 343/4 | Home/Yes, Draw/Yes, Away/Yes, Home/No, Draw/No, Away/No |
| 25 | Result/Total Goals | 419/5 | Draw/Over 3.5, Home/Over 3.5, Away/Over 3.5, Home/Under 3.5, Draw/Under 3.5, Away/Under 3.5, Draw/Over 1.5, Home/Over 2.5, Draw/Over 2.5, Away/Over 2.5 |
| 26 | Goals Over/Under - Second Half | 628/8 | Over 1.5, Under 1.5, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5, Over 4.5, Under 4.5 |
| 27 | Clean Sheet - Home | 94/1 | Yes, No |
| 28 | Clean Sheet - Away | 94/1 | Yes, No |
| 29 | Win to Nil - Home | 90/1 | Yes, No |
| 30 | Win to Nil - Away | 80/1 | Yes, No |
| 31 | Correct Score - First Half | 693/10 | 1:0, 2:0, 2:1, 3:0, 3:1, 3:2, 4:0, 4:1, 0:0, 1:1 |
| 32 | Win Both Halves | 236/3 | Home, Away |
| 33 | Double Chance - Second Half | 427/6 | Home/Draw, Home/Away, Draw/Away |
| 34 | Both Teams Score - First Half | 566/7 | Yes, No |
| 35 | Both Teams To Score - Second Half | 535/7 | Yes, No |
| 36 | Win To Nil | 152/3 | Home, Away |
| 37 | Home win both halves | 153/2 | Yes, No |
| 38 | Exact Goals Number | 278/4 | 0, 1, 2, 3, 4, 5, 6, more 7, more 6 |
| 39 | To Win Either Half | 293/4 | Home, Away |
| 40 | Home Team Exact Goals Number | 281/5 | 0, 1, 2, more 3, more 2, 3, more 4 |
| 41 | Away Team Exact Goals Number | 280/5 | 0, 1, 2, more 3, more 2, 3, more 4 |
| 42 | Second Half Exact Goals Number | 141/2 | 0, 1, 2, 3, 4, more 5, more 4 |
| 43 | Home Team Score a Goal | 138/2 | Yes, No |
| 44 | Away Team Score a Goal | 141/2 | Yes, No |
| 45 | Corners Over Under | 505/8 | Over 8.5, Under 8.5, Over 9.5, Under 9.5, Over 10.5, Under 10.5, Over 11.5, Under 11.5, Over 12.5, Under 12.5 |
| 46 | Exact Goals Number - First Half | 220/3 | 0, 1, 2, 3, 4, more 5, more 4 |
| 47 | Winning Margin | 95/1 | 1 by 1, 2 by 1, 1 by 4+, 1 by 2, 2 by 2, 1 by 3, 2 by 3, 2 by 4+, Score Draw, Draw |
| 48 | To Score In Both Halves By Teams | 61/1 | Home, Away |
| 49 | Total Goals/Both Teams To Score | 139/2 | o/yes 2.5, o/no 2.5, u/yes 2.5, u/no 2.5 |
| 50 | Goal Line | 96/1 | Over 1.75, Under 1.75, Over 2.25, Under 2.25, Over 2.5, Under 2.5, Over 2.75, Under 2.75, Over 3.5, Under 3.5 |
| 53 | Away win both halves | 114/2 | Yes, No |
| 54 | First 10 min Winner | 121/3 | Home, Draw, Away |
| 55 | Corners 1x2 | 364/7 | Home, Draw, Away |
| 56 | Corners Asian Handicap | 348/6 | Home -1, Away -1, Home +0, Away +0, Home +1, Away +1, Home -1.5, Away -1.5, Home +1.5, Away +1.5 |
| 57 | Home Corners Over/Under | 407/7 | Over 5.5, Under 5.5, Over 6.0, Under 6.0, Over 3.5, Under 3.5, Over 8.5, Under 8.5, Over 4.5, Under 4.5 |
| 58 | Away Corners Over/Under | 407/7 | Over 4.5, Under 4.5, Over 5.0, Under 5.0, Over 2.5, Under 2.5, Over 3.5, Under 3.5, Over 3.0, Under 3.0 |
| 59 | Own Goal | 52/2 | Yes, No |
| 60 | Away Odd/Even | 221/3 | Odd, Even |
| 61 | To Qualify | 127/5 | Home, Away |
| 62 | Correct Score - Second Half | 230/4 | 1:0, 2:0, 2:1, 3:0, 3:1, 3:2, 4:0, 4:1, 0:0, 1:1 |
| 63 | Odd/Even - Second Half | 412/5 | Odd, Even |
| 72 | Goal Line (1st Half) | 96/1 | Over 1.5, Under 1.5, Over 1.75, Under 1.75, Over 2.25, Under 2.25, Over 2.5, Under 2.5, Over 2.75, Under 2.75 |
| 77 | Total Corners (1st Half) | 432/7 | Exactly 5, Over 5, Under 5, Over 5.5, Under 5.5, Over 4.5, Under 4.5, Over 2.5, Under 2.5, Over 2.75 |
| 78 | RTG_H1 | 114/2 | Draw/Over 1.5, Away/Over 1.5, Home/Over 1.5, Home/Under 1.5, Draw/Under 1.5, Away/Under 1.5, Home/Over 2.5, Draw/Over 2.5, Away/Over 2.5, Home/Under 2.5 |
| 80 | Cards Over/Under | 44/2 | Over 5.5, Under 5.5, Over 4.5, Under 4.5, Over 6.5, Under 6.5, Over 3.5, Under 3.5, Over 2.5, Under 2.5 |
| 81 | Cards Asian Handicap | 17/1 | Home -0.5, Away -0.5, Home +0.5, Away +0.5, Home +1.5, Away +1.5 |
| 82 | Home Team Total Cards | 44/2 | Over 3.5, Under 3.5, Over 2.5, Under 2.5, Over 1.5, Under 1.5 |
| 83 | Away Team Total Cards | 44/2 | Over 2.5, Under 2.5, Over 1.5, Under 1.5, Over 3.5, Under 3.5, Over 0.5, Under 0.5 |
| 85 | Total Corners (3 way) | 211/3 | Exactly 10, Over 10, Under 10, Exactly 11, Over 11, Under 11, Exactly 2, Over 2, Under 2, Exactly 3 |
| 86 | RCARD | 1/1 | Yes |
| 87 | Total ShotOnGoal | 19/3 | Over 8.5, Under 8.5, Over 9.5, Under 9.5, Over 10.5, Under 10.5, Over 7.5, Under 7.5, Over 11.5, Under 11.5 |
| 92 | Anytime Goal Scorer | 42/1 | Lowe Astvald, Hugo Andersson, Viktor Claesson, Giuseppe Bovalina, Souleymane Coulibaly, John Stenberg, Mamadou Diallo, Sigge Jansson, Axel Bjornstrom, Jacob Ortmark |
| 93 | First Goal Scorer | 42/1 | Lowe Astvald, No Goalscorer, Hugo Andersson, Viktor Claesson, Giuseppe Bovalina, Souleymane Coulibaly, John Stenberg, Mamadou Diallo, Sigge Jansson, Axel Bjornstrom |
| 94 | Last Goal Scorer | 42/1 | Lowe Astvald, No Goalscorer, Hugo Andersson, Viktor Claesson, Giuseppe Bovalina, Souleymane Coulibaly, John Stenberg, Mamadou Diallo, Sigge Jansson, Axel Bjornstrom |
| 99 | To Score A Penalty | 50/1 | Home, Away |
| 100 | To Miss A Penalty | 50/1 | Home, Away |
| 104 | Asian Handicap (2nd Half) | 246/3 | Home -1, Away -1, Home -0.75, Away -0.75, Home -0.25, Away -0.25, Home +0, Away +0, Home +0.25, Away +0.25 |
| 105 | Home Team Total Goals(1st Half) | 574/7 | Over 1.5, Under 1.5, Over 1, Under 1, Over 2, Under 2, Over 0.5, Under 0.5, Over 2.5, Under 2.5 |
| 106 | Away Team Total Goals(1st Half) | 568/7 | Over 1.5, Under 1.5, Over 1, Under 1, Over 0.5, Under 0.5, Over 2.5, Under 2.5, Over 2, Under 2 |
| 107 | Home Team Total Goals(2nd Half) | 403/5 | Over 1.5, Under 1.5, Over 1, Under 1, Over 2, Under 2, Over 2.5, Under 2.5, Over 0.5, Under 0.5 |

## Décisions techniques

- Le bookmaker doit être une dimension de la cote, pas une source de vérité métier.
- Le moteur doit consommer `InternalMarketId` + `InternalSelectionId`, jamais le libellé brut.
- Les IDs API-Football des marchés sont stables pour une première normalisation, mais les `values` doivent être mappées par marché.
- Une même intention produit peut venir de plusieurs marchés API : par exemple `match_result`, `home_away`, `double_chance`, `result_total_goals`.
- Les marchés corners et cartons entrent dans le MVP via `corners_total` et
  `cards_total`.
- Le marché API `55` / `Corners 1x2` est observé mais exclu du MVP : son
  intention produit n'est pas assez claire pour l'écran utilisateur.
- Les marchés handicap/asiatiques et les marchés combinés doivent rester hors MVP tant que la convention de ligne, de signe et de composition n’est pas verrouillée.
