# Marchés de cotes API hockey — 4 octobre 2026

Deux appels supplémentaires : GET /odds/bets et GET /odds?league=57&season=2026.

Catalogue : 221 IDs. Réponse NHL : 38 rencontres, 85 IDs distincts proposés. Ces nombres comprennent des libellés erronés et ne constituent pas un catalogue validé.

Exemple : Winnipeg (extérieur) – Detroit (domicile), game 444632, 4 octobre 17:00 UTC / 19:00 Paris. Neuf bookmakers et 75 IDs distincts.

Cotes collectées le 4 octobre à 08:12 UTC. La réponse ne comporte pas de champ update ; cette heure est celle de notre collecte, pas une preuve de dernière mise à jour chez le bookmaker.

## Exemples réellement renvoyés

| Bookmaker | Marché exact | Sélection | Cote décimale |
| --- | --- | --- | --- |
| WilliamHill | 3Way Result | Home | 2.38 |
| WilliamHill | 3Way Result | Draw | 3.90 |
| WilliamHill | 3Way Result | Away | 2.40 |
| WilliamHill | Home/Away | Home | 1.91 |
| WilliamHill | Home/Away | Away | 1.91 |
| bet365 | Anytime Goal Scorer | Gabriel Vilardi | 3.35 |
| bet365 | Anytime Goal Scorer | Kyle Connor | 2.65 |
| bet365 | Anytime Goal Scorer | Mark Scheifele | 3.00 |
| bet365 | Anytime Goal Scorer | Viktor Arvidsson | 3.25 |
| bet365 | Anytime Goal Scorer | Alex DeBrincat | 2.25 |
| bet365 | Anytime Goal Scorer | Lucas Raymond | 3.20 |
| Betfair | Over/Under (Reg Time) | Over 5.5 | 1.83 |
| Betfair | Over/Under (Reg Time) | Under 5.5 | 2.05 |
| Betano | Will match go to overtime? | Yes | 3.80 |
| Betano | Will match go to overtime? | No | 1.23 |

## Interprétation et limites

- Home/Away ne précise pas ici l’inclusion OT/tirs au but. Vérifier le règlement bookmaker avant de normaliser ou régler automatiquement ce marché.
- Reg Time et Including OT sont deux périmètres distincts ; Including OT ne précise pas à lui seul comment traiter les tirs au but.
- Un handicap entier peut être remboursé ; les handicaps quart de but peuvent avoir des règlements partiels. Ne pas les traiter comme un simple succès/échec.
- Les noms de joueurs dans les cotes ne sont pas accompagnés d’IDs. Les rapprocher des noms abrégés des événements nécessite un travail d’identité.
- La présence d’un marché de tirs ou d’arrêts ne fournit pas les tirs/arrêts réalisés : elle ne résout pas le manque de statistiques constaté dans l’audit précédent.
- Incohérences : ID 220 Total Passing Touchdowns apparaît même dans la réponse NHL ; le catalogue inclut aussi des marchés de sacks. Certains IDs différents partagent un nom identique. Créer une sélection explicite de marchés hockey validés, avec leur périmètre et règles de règlement.
- Les cotes reçues sont une observation avant match/historique, pas une confirmation de cotes en direct ni de disponibilité permanente.

## Catalogue complet reçu

La colonne NHL indique la présence dans la réponse observée, pas une validation sportive.

| ID | Libellé exact fournisseur | Observé dans la réponse NHL |
| --- | --- | --- |
| 1 | 3Way Result | Oui |
| 2 | Home/Away | Oui |
| 3 | Asian Handicap | Oui |
| 4 | Over/Under | Oui |
| 5 | Both Teams To Score | Oui |
| 6 | Handicap Result | Oui |
| 7 | Correct Score | Oui |
| 8 | Highest Scoring Half | Oui |
| 9 | Double Chance | Oui |
| 10 | Total - Home | Oui |
| 11 | Total - Away | Oui |
| 12 | Odd/Even (Including OT) | Oui |
| 13 | Odd/Even | Oui |
| 14 | Over/Under (1st Period) | Oui |
| 15 | Both Teams To Score (2nd Period) | Oui |
| 16 | 3Way Result (2st Period) | Oui |
| 17 | 3Way Result 3rdPeriod) | Oui |
| 18 | Asian Handicap (3rd Period) | Oui |
| 19 | Over/Under (2nd Period) | Oui |
| 20 | Over/Under (3rd Period) | Oui |
| 21 | 1x2 (1st Period) | Oui |
| 22 | Double Chance (3rd Period) | Oui |
| 23 | Both Teams To Score (1st Period) | Oui |
| 24 | Both Teams To Score (3rd Period) | Oui |
| 25 | Asian Handicap (1st Period) | Oui |
| 26 | Asian Handicap (2nd Period) | Oui |
| 27 | Double Chance (1st Period) | Oui |
| 28 | Double Chance (2nd Period) | Oui |
| 29 | Home Team Total Goals (1st Period) | Oui |
| 30 | Home Team Total Goals (2nd Period) | Oui |
| 31 | Home Team Total Goals (3rd Period) | Oui |
| 32 | Away Team Total Goals (1st Period) | Oui |
| 33 | Away Team Total Goals (2nd Period) | Oui |
| 34 | Away Team Total Goals (3rd Period) | Oui |
| 35 | Correct Score (1st Period) | Non |
| 36 | Draw No Bet (1st Period) | Non |
| 37 | Draw No Bet (2nd Period) | Non |
| 38 | Draw No Bet (3rd Period) | Non |
| 39 | Correct Score (2nd Period) | Oui |
| 40 | Correct Score (3rd Period) | Oui |
| 41 | Will match go to overtime? | Oui |
| 42 | Home/Away (1st Period) | Oui |
| 43 | Odd/Even (1st Period) | Non |
| 44 | Odd/Even (2nd Period) | Oui |
| 45 | Odd/Even (3rd Period) | Oui |
| 46 | Home/Away (2nd Period) | Non |
| 47 | Home/Away (3rd Period) | Non |
| 48 | European Handicap (1st Q | Oui |
| 49 | European Handicap (2nd Q | Non |
| 50 | European Handicap (3rd Q | Non |
| 51 | Home/Away (Reg Time) | Non |
| 52 | Over/Under (Reg Time) | Oui |
| 53 | Asian Handicap (Reg Time) | Oui |
| 54 | Home Team Total Goals (Including OT) | Oui |
| 55 | Away Team Total Goals (Including OT) | Oui |
| 56 | Team To Score Last | Oui |
| 57 | Team To Score First | Oui |
| 58 | Result/Total Goals | Oui |
| 59 | Home team will score a goal | Oui |
| 60 | Away team will score a goal | Oui |
| 61 | Home team will score a goal (1st Period) | Oui |
| 62 | Home team will score a goal (2nd Period) | Oui |
| 63 | Home team will score a goal (3rd Period) | Oui |
| 64 | Away team will score a goal (1st Period) | Oui |
| 65 | Away team will score a goal (2nd Period) | Oui |
| 66 | Away team will score a goal (3rd Period) | Oui |
| 67 | Match ends in Regular Time | Oui |
| 68 | Match ends in Over Time | Oui |
| 69 | Match ends in Penalty Shoot-out | Non |
| 70 | Either Team Win To Nill | Oui |
| 71 | Either Team Win By 1 Goal | Oui |
| 72 | Either Team Win By 2 Goal | Oui |
| 73 | Either Team Win By 3 Goal | Oui |
| 74 | Correct Score | Non |
| 75 | 1x2(face offs) | Non |
| 76 | Asian Handicap(face offs 1st Period) | Non |
| 77 | Over/Under(face offs 1st Period) | Non |
| 78 | Double Chance(face offs 1st Period) | Non |
| 79 | Asian Handicap(Penalty time) | Non |
| 80 | Over/Under(Penalty time) | Non |
| 81 | Over/Under(Penalty time 1st Period) | Non |
| 82 | 1x2(Blocked shots) | Non |
| 83 | Over/Under(Blocked shots) | Non |
| 84 | 1x2(Shots on goal) | Non |
| 85 | Asian Handicap(Shots on goal) | Non |
| 86 | Over/Under(Shots on goal) | Non |
| 87 | Home Team Total Goals(Shots on goal) | Non |
| 88 | Away Team Total Goals(Shots on goal) | Non |
| 89 | 1x2(Shots on goal P1) | Non |
| 90 | Asian Handicap(Shots on goal P1) | Non |
| 91 | Over/Under(Shots on goal P1) | Non |
| 92 | Home Total (Shots on goal P1) | Non |
| 93 | Double Chance(Shots on goal) | Non |
| 94 | Double Chance(Shots on goal P1) | Non |
| 95 | Away Total (Shots on goal P1) | Non |
| 96 | To win more periods | Oui |
| 97 | Win From behind (Player 2) | Non |
| 98 | Win From Behind (Player 1) | Non |
| 99 | Win From Behind | Non |
| 100 | Away To score first and win in a regular time | Non |
| 101 | Home To score first and win in a regular time | Non |
| 102 | Away Team Total Goals(Penalty time) | Non |
| 103 | Home Team Total Goals(Penalty time) | Non |
| 104 | 1x2(Penalty time) | Non |
| 105 | 1x2(Penalty time 1st Period) | Non |
| 106 | Asian Handicap(Penalty time 1st Period) | Non |
| 107 | Double Chance(Penalty time 1st Period) | Non |
| 108 | Home Team Total Goals(Penalty time 1st Period) | Non |
| 109 | Away Team Total Goals(Penalty time 1st Period) | Non |
| 110 | Double Chance(Penalty time) | Non |
| 111 | Asian Handicap(Blocked shots) | Non |
| 112 | Double Chance(Blocked shots) | Non |
| 113 | To Qualify | Non |
| 114 | Number of powerplay goals | Non |
| 115 | Win to Nil - Home | Oui |
| 116 | Win to Nil - Away | Oui |
| 117 | Away Total(Powerplay) | Non |
| 118 | Home Total(Powerplay) | Non |
| 119 | 1x2(Powerplay) | Non |
| 120 | Asian Handicap(Powerplay) | Non |
| 121 | Over/Under(Powerplay) | Non |
| 122 | Double Chance(Powerplay) | Non |
| 123 | 1x2 (10 min.) | Oui |
| 124 | Double Chance (10 min.) | Oui |
| 125 | Asian Handicap (10 min.) | Oui |
| 126 | Over/Under (10 min.) | Oui |
| 127 | Asian Handicap(Powerplay 1st Period) | Non |
| 128 | Over/Under(Powerplay 1st Period) | Non |
| 129 | Double Chance(Powerplay 1st Period) | Non |
| 130 | Home Total (Powerplay 1st Period) | Non |
| 131 | Away Total (Powerplay 1st Period) | Non |
| 132 | Will be a empty net goal | Non |
| 133 | HT/FT Double | Non |
| 134 | 1x2(Powerplay 1st Period) | Non |
| 135 | Away To win in overtime | Non |
| 136 | Home To win in overtime | Non |
| 137 | 1x2 (Checking) | Non |
| 138 | Asian Handicap (Checking) | Non |
| 139 | Home Win All Three Periods | Non |
| 140 | Away Win All Three Periods | Non |
| 141 | Exact Goals Number | Oui |
| 142 | Home Team Exact Goals Number | Oui |
| 143 | Away Team Exact Goals Number | Oui |
| 144 | Home Winning Margin | Non |
| 145 | Away Winning Margin | Non |
| 146 | Total Goals Number By Ranges | Non |
| 147 | Goal In Each Period | Non |
| 148 | Player Singles | Non |
| 149 | Player Assists | Non |
| 150 | Home Odd/Even | Oui |
| 151 | Away Odd/Even | Oui |
| 152 | Race To | Non |
| 153 | Total (3W) | Non |
| 154 | Time Of 1st Score | Non |
| 155 | Tied after Regulation | Non |
| 156 | Team Time Of 1st Score | Non |
| 157 | Team Scoring 1st Wins Game | Non |
| 158 | When will Match End | Non |
| 159 | Player Shots on Goal | Non |
| 160 | Home Player Shots | Non |
| 161 | Away Player Shots | Non |
| 162 | Both Teams To Score 10m | Non |
| 163 | European Handicap 10m | Non |
| 164 | Away Team Total Goals | Non |
| 165 | Home Team Total Goals | Non |
| 166 | Both Teams To Score (Goals) | Non |
| 167 | Team To Score (Goals) | Non |
| 168 | Team To Score 10 min | Non |
| 169 | Home/Away 10m | Non |
| 170 | Correct Score 10m | Non |
| 171 | Over/Under (3W) 1st Period | Non |
| 172 | Player Points Milestones | Non |
| 173 | Home Player Points Milestones | Non |
| 174 | Away Player Points Milestones | Non |
| 175 | Player Power Play Points Milestones | Non |
| 176 | Home Player Power Play Points Milestones | Non |
| 177 | Player Shots on Goal Milestones | Non |
| 178 | Away Player Shots on Goal Milestones | Non |
| 179 | Over/Under (Checking) | Non |
| 180 | Over/Under (3W) 10m | Non |
| 181 | Home Player Shots on Goal | Non |
| 182 | Away Player Shots on Goal | Non |
| 183 | Player Assists Milestones | Non |
| 184 | Home Player Assists Milestones | Non |
| 185 | Away Player Assists Milestones | Non |
| 186 | Away Player Power Play Points Milestones | Non |
| 187 | Home Player Shots on Goal Milestones | Non |
| 188 | Player to record a Sack | Non |
| 189 | Home Player to Record a Sack | Non |
| 190 | Player Saves Milestones | Non |
| 191 | Over/Under(face offs) | Non |
| 192 | Player Blocked Shots | Non |
| 193 | Home Player Blocked Shots | Non |
| 194 | Away Player Blocked Shots | Non |
| 195 | Asian Handicap(face offs) | Non |
| 196 | 1x2(face offs) | Non |
| 197 | Double Chance(face offs) | Non |
| 198 | Away Player to Record a Sack | Non |
| 199 | Player Saves | Non |
| 200 | Away Player Saves | Non |
| 201 | Double Chance (Checking) | Non |
| 202 | To Score Two or More Goals | Non |
| 203 | To Score 3 or More Goals | Non |
| 204 | Anytime Goal Scorer | Oui |
| 205 | First Goal Scorer | Oui |
| 206 | Last Goal Scorer | Non |
| 207 | Player Points | Non |
| 208 | Home/Away (2nd Period) | Oui |
| 209 | Home/Away (3rd Period) | Oui |
| 210 | Away Anytime Goal Scorer | Non |
| 211 | Away First Goal Scorer | Oui |
| 212 | Away Last Goal Scorer | Non |
| 213 | Home Anytime Goal Scorer | Oui |
| 214 | Home First Goal Scorer | Oui |
| 215 | Home Last Goal Scorer | Non |
| 216 | Away Player Assists | Non |
| 217 | Player Points Milestones | Oui |
| 218 | Player Shots On Goal | Oui |
| 219 | Away Anytime Goal Scorer | Oui |
| 220 | Total Passing Touchdowns | Oui |
| 221 | Player Powerplay Points | Non |

## Fichiers bruts

- [Catalogue](13_odds_bets.json)
- [Cotes NHL](14_odds.json)
- [Cotes Winnipeg–Detroit](winnipeg-detroit-odds.json)

Source primaire : réponses API authentifiées conservées ci-dessus. [Guide officiel](https://www.api-football.com/news/post/ice-hockey-world-championship-2026-guide-to-using-data-with-api-sports), section Odds.
