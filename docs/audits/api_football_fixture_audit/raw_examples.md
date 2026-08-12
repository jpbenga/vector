# Exemples JSON tronqués

Ces extraits sont tronqués et ne contiennent aucune clé API. Les réponses complètes sont dans `raw/`.

## 01_fixture_1379344.json

```json
{
  "fixture": {
    "id": 1379344,
    "referee": "A. Madley",
    "timezone": "UTC",
    "date": "2026-05-24T15:00:00+00:00",
    "timestamp": 1779634800,
    "periods": {
      "first": 1779634800,
      "second": 1779638400
    },
    "venue": {
      "id": 555,
      "name": "Etihad Stadium",
      "city": "Manchester"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 12
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 38",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 50,
      "name": "Manchester City",
      "logo": "https://media.api-sports.io/football/teams/50.png",
      "winner": false
    },
    "away": {
      "id": 66,
      "name": "Aston Villa",
      "logo": "https://media.api-sports.io/football/teams/66.png",
      "winner": true
    }
  },
  "goals": {
    "home": 1,
    "away": 2
  },
  "score": {
    "halftime": {
      "home": 1,
      "away": 0
    },
    "fulltime": {
      "home": 1,
      "away": 2
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  },
  "events": [
    {
      "time": {
        "elapsed": 23,
        "extra": null
      },
      "team": {
        "id": 50,
        "name": "Manchester City",
        "logo": "https://media.api-sports.io/football/teams/50.png"
      },
      "player": {
        "id": 19281,
        "name": "A. Semenyo"
      },
      "assist": {
        "id": null,
        "name": null
      },
      "type": "Goal",
      "detail
  ... [tronqué]
```

## 02_fixture_statistics.json

```json
{
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "statistics": [
    {
      "type": "Shots on Goal",
      "value": 3
    },
    {
      "type": "Shots off Goal",
      "value": 7
    },
    {
      "type": "Total Shots",
      "value": 16
    },
    {
      "type": "Blocked Shots",
      "value": 6
    },
    {
      "type": "Shots insidebox",
      "value": 10
    },
    {
      "type": "Shots outsidebox",
      "value": 6
    },
    {
      "type": "Fouls",
      "value": 8
    },
    {
      "type": "Corner Kicks",
      "value": 9
    },
    {
      "type": "Offsides",
      "value": 1
    },
    {
      "type": "Ball Possession",
      "value": "53%"
    },
    {
      "type": "Yellow Cards",
      "value": 1
    },
    {
      "type": "Red Cards",
      "value": null
    },
    {
      "type": "Goalkeeper Saves",
      "value": 3
    },
    {
      "type": "Total passes",
      "value": 481
    },
    {
      "type": "Passes accurate",
      "value": 426
    },
    {
      "type": "Passes %",
      "value": "89%"
    },
    {
      "type": "expected_goals",
      "value": "1.34"
    },
    {
      "type": "goals_prevented",
      "value": "0.51"
    }
  ]
}
```

## 03_fixture_events.json

```json
{
  "time": {
    "elapsed": 23,
    "extra": null
  },
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "player": {
    "id": 19281,
    "name": "A. Semenyo"
  },
  "assist": {
    "id": null,
    "name": null
  },
  "type": "Goal",
  "detail": "Normal Goal",
  "comments": null
}
```

## 04_fixture_lineups.json

```json
{
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png",
    "colors": {
      "player": {
        "primary": "abd1f5",
        "number": "000000",
        "border": "abd1f5"
      },
      "goalkeeper": {
        "primary": "008b48",
        "number": "feb139",
        "border": "008b48"
      }
    }
  },
  "coach": {
    "id": 4,
    "name": "Pep Guardiola",
    "photo": "https://media.api-sports.io/football/coachs/4.png"
  },
  "formation": "4-2-2-2",
  "startXI": [
    {
      "player": {
        "id": 162489,
        "name": "J. Trafford",
        "number": 1,
        "pos": "G",
        "grid": "1:1"
      }
    },
    {
      "player": {
        "id": 284230,
        "name": "R. Lewis",
        "number": 82,
        "pos": "D",
        "grid": "2:4"
      }
    },
    {
      "player": {
        "id": 626,
        "name": "J. Stones",
        "number": 5,
        "pos": "D",
        "grid": "2:3"
      }
    },
    {
      "player": {
        "id": 567,
        "name": "R. Dias",
        "number": 3,
        "pos": "D",
        "grid": "2:2"
      }
    },
    {
      "player": {
        "id": 18861,
        "name": "N. Ake",
        "number": 6,
        "pos": "D",
        "grid": "2:1"
      }
    },
    {
      "player": {
        "id": 161933,
        "name": "Nico",
        "number": 14,
        "pos": "M",
        "grid": "3:2"
      }
    },
    {
      "player": {
        "id": 636,
        "name": "B. Silva",
        "number": 20,
        "pos": "M",
        "grid": "3:1"
      }
    },
    {
      "player": {
        "id": 19281,
        "name": "A. Semenyo",
        "number": 42,
        "pos": "M",
        "grid": "4:2"
      }
    },
    {
      "player": {
        "id": 266657,
    
  ... [tronqué]
```

## 05_fixture_players.json

```json
{
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png",
    "update": "2026-05-26T04:32:02+00:00"
  },
  "players": [
    {
      "player": {
        "id": 162489,
        "name": "James Trafford",
        "photo": "https://media.api-sports.io/football/players/162489.png"
      },
      "statistics": [
        {
          "games": {
            "minutes": 90,
            "number": 1,
            "position": "G",
            "rating": "6.3",
            "captain": false,
            "substitute": false
          },
          "offsides": null,
          "shots": {
            "total": null,
            "on": null
          },
          "goals": {
            "total": null,
            "conceded": 2,
            "assists": 0,
            "saves": 3
          },
          "passes": {
            "total": 11,
            "key": null,
            "accuracy": "10"
          },
          "tackles": {
            "total": null,
            "blocks": null,
            "interceptions": null
          },
          "duels": {
            "total": null,
            "won": null
          },
          "dribbles": {
            "attempts": null,
            "success": null,
            "past": null
          },
          "fouls": {
            "drawn": null,
            "committed": null
          },
          "cards": {
            "yellow": 0,
            "red": 0
          },
          "penalty": {
            "won": null,
            "commited": null,
            "scored": 0,
            "missed": 0,
            "saved": 0
          }
        }
      ]
    },
    {
      "player": {
        "id": 284230,
        "name": "Rico Lewis",
        "photo": "https://media.api-sports.io/football/players/284230.png"
      },
  ... [tronqué]
```

## 06_injuries_fixture.json

```json
{
  "player": {
    "id": 464004,
    "name": "Alysson",
    "photo": "https://media.api-sports.io/football/players/464004.png",
    "type": "Missing Fixture",
    "reason": "Muscle Injury"
  },
  "team": {
    "id": 66,
    "name": "Aston Villa",
    "logo": "https://media.api-sports.io/football/teams/66.png"
  },
  "fixture": {
    "id": 1379344,
    "timezone": "UTC",
    "date": "2026-05-24T15:00:00+00:00",
    "timestamp": 1779634800
  },
  "league": {
    "id": 39,
    "season": 2025,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg"
  }
}
```

## 07_predictions.json

```json
{
  "predictions": {
    "winner": {
      "id": 50,
      "name": "Manchester City",
      "comment": "Win or draw"
    },
    "win_or_draw": true,
    "under_over": null,
    "goals": {
      "home": "-3.5",
      "away": "-2.5"
    },
    "advice": "Double chance : Manchester City or draw",
    "percent": {
      "home": "45%",
      "draw": "45%",
      "away": "10%"
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025
  },
  "teams": {
    "home": {
      "id": 50,
      "name": "Manchester City",
      "logo": "https://media.api-sports.io/football/teams/50.png",
      "last_5": {
        "played": 5,
        "form": "73%",
        "att": "92%",
        "def": "67%",
        "goals": {
          "for": {
            "total": 11,
            "average": "2.2"
          },
          "against": {
            "total": 4,
            "average": "0.8"
          }
        }
      },
      "league": {
        "form": "WLLWDWWWLWWLWWWWWWDDDLWDWWWWDDWWWDWWD",
        "fixtures": {
          "played": {
            "home": 18,
            "away": 19,
            "total": 37
          },
          "wins": {
            "home": 14,
            "away": 9,
            "total": 23
          },
          "draws": {
            "home": 3,
            "away": 6,
            "total": 9
          },
          "loses": {
            "home": 1,
            "away": 4,
            "total": 5
          }
        },
        "goals": {
          "for": {
            "total": {
              "home": 44,
              "away": 32,
              "total": 76
            },
            "average": {
              "h
  ... [tronqué]
```

## 08_odds_prematch_fixture.json

```json
{
  "response": [],
  "results": 0,
  "errors": []
}
```

## 09_odds_live_fixture.json

```json
{
  "response": [],
  "results": 0,
  "errors": []
}
```

## 10_standings_pl_2025.json

```json
{
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "standings": [
      [
        {
          "rank": 1,
          "team": {
            "id": 42,
            "name": "Arsenal",
            "logo": "https://media.api-sports.io/football/teams/42.png"
          },
          "points": 85,
          "goalsDiff": 44,
          "group": "Premier League",
          "form": "WWWWW",
          "status": "same",
          "description": "Promotion - Champions League (League phase)",
          "all": {
            "played": 38,
            "win": 26,
            "draw": 7,
            "lose": 5,
            "goals": {
              "for": 71,
              "against": 27
            }
          },
          "home": {
            "played": 19,
            "win": 15,
            "draw": 2,
            "lose": 2,
            "goals": {
              "for": 41,
              "against": 11
            }
          },
          "away": {
            "played": 19,
            "win": 11,
            "draw": 5,
            "lose": 3,
            "goals": {
              "for": 30,
              "against": 16
            }
          },
          "update": "2026-05-27T00:00:00+00:00"
        },
        {
          "rank": 2,
          "team": {
            "id": 50,
            "name": "Manchester City",
            "logo": "https://media.api-sports.io/football/teams/50.png"
          },
          "points": 78,
          "goalsDiff": 42,
          "group": "Premier League",
          "form": "LDWWD",
          "status": "same",
          "description": "Promotion - Champions League (League phase)",
          "a
  ... [tronqué]
```

## 11_team_statistics_man_city.json

```json
{
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025
  },
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "form": "WLLWDWWWLWWLWWWWWWDDDLWDWWWWDDWWWDWWDL",
  "fixtures": {
    "played": {
      "home": 19,
      "away": 19,
      "total": 38
    },
    "wins": {
      "home": 14,
      "away": 9,
      "total": 23
    },
    "draws": {
      "home": 3,
      "away": 6,
      "total": 9
    },
    "loses": {
      "home": 2,
      "away": 4,
      "total": 6
    }
  },
  "goals": {
    "for": {
      "total": {
        "home": 45,
        "away": 32,
        "total": 77
      },
      "average": {
        "home": "2.4",
        "away": "1.7",
        "total": "2.0"
      },
      "minute": {
        "0-15": {
          "total": 8,
          "percentage": "10.81%"
        },
        "16-30": {
          "total": 10,
          "percentage": "13.51%"
        },
        "31-45": {
          "total": 22,
          "percentage": "29.73%"
        },
        "46-60": {
          "total": 8,
          "percentage": "10.81%"
        },
        "61-75": {
          "total": 13,
          "percentage": "17.57%"
        },
        "76-90": {
          "total": 13,
          "percentage": "17.57%"
        },
        "91-105": {
          "total": null,
          "percentage": null
        },
        "106-120": {
          "total": null,
          "percentage": null
        }
      },
      "under_over": {
        "0.5": {
          "over": 34,
          "under": 4
        },
        "1.5": {
          "over": 23,
          "under"
  ... [tronqué]
```

## 12_team_statistics_aston_villa.json

```json
{
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025
  },
  "team": {
    "id": 66,
    "name": "Aston Villa",
    "logo": "https://media.api-sports.io/football/teams/66.png"
  },
  "form": "DLLDDWWWWLWWWWWWWWLWDLWLDWDLLLWDWLLDWW",
  "fixtures": {
    "played": {
      "home": 19,
      "away": 19,
      "total": 38
    },
    "wins": {
      "home": 12,
      "away": 7,
      "total": 19
    },
    "draws": {
      "home": 2,
      "away": 6,
      "total": 8
    },
    "loses": {
      "home": 5,
      "away": 6,
      "total": 11
    }
  },
  "goals": {
    "for": {
      "total": {
        "home": 32,
        "away": 24,
        "total": 56
      },
      "average": {
        "home": "1.7",
        "away": "1.3",
        "total": "1.5"
      },
      "minute": {
        "0-15": {
          "total": 3,
          "percentage": "5.56%"
        },
        "16-30": {
          "total": 6,
          "percentage": "11.11%"
        },
        "31-45": {
          "total": 11,
          "percentage": "20.37%"
        },
        "46-60": {
          "total": 11,
          "percentage": "20.37%"
        },
        "61-75": {
          "total": 10,
          "percentage": "18.52%"
        },
        "76-90": {
          "total": 13,
          "percentage": "24.07%"
        },
        "91-105": {
          "total": null,
          "percentage": null
        },
        "106-120": {
          "total": null,
          "percentage": null
        }
      },
      "under_over": {
        "0.5": {
          "over": 28,
          "under": 10
        },
        "1.5": {
          "over": 17,
          "under": 2
  ... [tronqué]
```

## 13_fixtures_man_city_before.json

```json
{
  "fixture": {
    "id": 1378975,
    "referee": "J. Gillett",
    "timezone": "UTC",
    "date": "2025-08-16T16:30:00+00:00",
    "timestamp": 1755361800,
    "periods": {
      "first": 1755361800,
      "second": 1755365400
    },
    "venue": {
      "id": 600,
      "name": "Molineux Stadium",
      "city": "Wolverhampton"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 8
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 1",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 39,
      "name": "Wolves",
      "logo": "https://media.api-sports.io/football/teams/39.png",
      "winner": false
    },
    "away": {
      "id": 50,
      "name": "Manchester City",
      "logo": "https://media.api-sports.io/football/teams/50.png",
      "winner": true
    }
  },
  "goals": {
    "home": 0,
    "away": 4
  },
  "score": {
    "halftime": {
      "home": 0,
      "away": 2
    },
    "fulltime": {
      "home": 0,
      "away": 4
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
```

## 14_fixtures_aston_villa_before.json

```json
{
  "fixture": {
    "id": 1378970,
    "referee": "C. Pawson",
    "timezone": "UTC",
    "date": "2025-08-16T11:30:00+00:00",
    "timestamp": 1755343800,
    "periods": {
      "first": 1755343800,
      "second": 1755347400
    },
    "venue": {
      "id": 495,
      "name": "Villa Park",
      "city": "Birmingham"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 7
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 1",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 66,
      "name": "Aston Villa",
      "logo": "https://media.api-sports.io/football/teams/66.png",
      "winner": null
    },
    "away": {
      "id": 34,
      "name": "Newcastle",
      "logo": "https://media.api-sports.io/football/teams/34.png",
      "winner": null
    }
  },
  "goals": {
    "home": 0,
    "away": 0
  },
  "score": {
    "halftime": {
      "home": 0,
      "away": 0
    },
    "fulltime": {
      "home": 0,
      "away": 0
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
```

## 15_fixtures_man_city_season.json

```json
{
  "fixture": {
    "id": 1378975,
    "referee": "J. Gillett",
    "timezone": "UTC",
    "date": "2025-08-16T16:30:00+00:00",
    "timestamp": 1755361800,
    "periods": {
      "first": 1755361800,
      "second": 1755365400
    },
    "venue": {
      "id": 600,
      "name": "Molineux Stadium",
      "city": "Wolverhampton"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 8
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 1",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 39,
      "name": "Wolves",
      "logo": "https://media.api-sports.io/football/teams/39.png",
      "winner": false
    },
    "away": {
      "id": 50,
      "name": "Manchester City",
      "logo": "https://media.api-sports.io/football/teams/50.png",
      "winner": true
    }
  },
  "goals": {
    "home": 0,
    "away": 4
  },
  "score": {
    "halftime": {
      "home": 0,
      "away": 2
    },
    "fulltime": {
      "home": 0,
      "away": 4
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
```

## 16_fixtures_aston_villa_season.json

```json
{
  "fixture": {
    "id": 1378970,
    "referee": "C. Pawson",
    "timezone": "UTC",
    "date": "2025-08-16T11:30:00+00:00",
    "timestamp": 1755343800,
    "periods": {
      "first": 1755343800,
      "second": 1755347400
    },
    "venue": {
      "id": 495,
      "name": "Villa Park",
      "city": "Birmingham"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 7
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 1",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 66,
      "name": "Aston Villa",
      "logo": "https://media.api-sports.io/football/teams/66.png",
      "winner": null
    },
    "away": {
      "id": 34,
      "name": "Newcastle",
      "logo": "https://media.api-sports.io/football/teams/34.png",
      "winner": null
    }
  },
  "goals": {
    "home": 0,
    "away": 0
  },
  "score": {
    "halftime": {
      "home": 0,
      "away": 0
    },
    "fulltime": {
      "home": 0,
      "away": 0
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
```

## 17_head_to_head.json

```json
{
  "fixture": {
    "id": 1379344,
    "referee": "A. Madley",
    "timezone": "UTC",
    "date": "2026-05-24T15:00:00+00:00",
    "timestamp": 1779634800,
    "periods": {
      "first": 1779634800,
      "second": 1779638400
    },
    "venue": {
      "id": 555,
      "name": "Etihad Stadium",
      "city": "Manchester"
    },
    "status": {
      "long": "Match Finished",
      "short": "FT",
      "elapsed": 90,
      "extra": 12
    }
  },
  "league": {
    "id": 39,
    "name": "Premier League",
    "country": "England",
    "logo": "https://media.api-sports.io/football/leagues/39.png",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg",
    "season": 2025,
    "round": "Regular Season - 38",
    "standings": true
  },
  "teams": {
    "home": {
      "id": 50,
      "name": "Manchester City",
      "logo": "https://media.api-sports.io/football/teams/50.png",
      "winner": false
    },
    "away": {
      "id": 66,
      "name": "Aston Villa",
      "logo": "https://media.api-sports.io/football/teams/66.png",
      "winner": true
    }
  },
  "goals": {
    "home": 1,
    "away": 2
  },
  "score": {
    "halftime": {
      "home": 1,
      "away": 0
    },
    "fulltime": {
      "home": 1,
      "away": 2
    },
    "extratime": {
      "home": null,
      "away": null
    },
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
```

## 18_squad_man_city.json

```json
{
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "players": [
    {
      "id": 19012,
      "name": "M. Bettinelli",
      "age": 33,
      "number": 13,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/19012.png"
    },
    {
      "id": 1622,
      "name": "G. Donnarumma",
      "age": 26,
      "number": 25,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/1622.png"
    },
    {
      "id": 162489,
      "name": "J. Trafford",
      "age": 23,
      "number": 1,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/162489.png"
    },
    {
      "id": 21138,
      "name": "R. Aït-Nouri",
      "age": 24,
      "number": 21,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/21138.png"
    },
    {
      "id": 293168,
      "name": "Max Alleyne",
      "age": 20,
      "number": 68,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/293168.png"
    },
    {
      "id": 567,
      "name": "Rúben Dias",
      "age": 28,
      "number": 3,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/567.png"
    },
    {
      "id": 67971,
      "name": "M. Guéhi",
      "age": 25,
      "number": 15,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/67971.png"
    },
    {
      "id": 129033,
      "name": "J. Gvardiol",
      "age": 23,
      "number": 24,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/129033.png"
    },
    {
      "id": 360114,
      "name": "A. Khusanov
  ... [tronqué]
```

## 19_squad_aston_villa.json

```json
{
  "team": {
    "id": 66,
    "name": "Aston Villa",
    "logo": "https://media.api-sports.io/football/teams/66.png"
  },
  "players": [
    {
      "id": 36878,
      "name": "M. Bizot",
      "age": 34,
      "number": 40,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/36878.png"
    },
    {
      "id": 7029,
      "name": "J. Gauci",
      "age": 25,
      "number": 46,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/7029.png"
    },
    {
      "id": 19599,
      "name": "E. Martínez",
      "age": 33,
      "number": 23,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/19599.png"
    },
    {
      "id": 284390,
      "name": "J. Wright",
      "age": 21,
      "number": 64,
      "position": "Goalkeeper",
      "photo": "https://media.api-sports.io/football/players/284390.png"
    },
    {
      "id": 284457,
      "name": "L. Bogarde",
      "age": 21,
      "number": 26,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/284457.png"
    },
    {
      "id": 19298,
      "name": "M. Cash",
      "age": 28,
      "number": 2,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/19298.png"
    },
    {
      "id": 478441,
      "name": "M. Cissé",
      "age": 20,
      "number": 48,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/478441.png"
    },
    {
      "id": 2724,
      "name": "L. Digne",
      "age": 32,
      "number": 12,
      "position": "Defender",
      "photo": "https://media.api-sports.io/football/players/2724.png"
    },
    {
      "id": 19354,
      "name": "E. Konsa",
      "age": 28,
   
  ... [tronqué]
```

## 20_players_man_city_page1.json

```json
{
  "player": {
    "id": 19281,
    "name": "A. Semenyo",
    "firstname": "Antoine Serlom",
    "lastname": "Semenyo",
    "age": 25,
    "birth": {
      "date": "2000-01-07",
      "place": "London",
      "country": "England"
    },
    "nationality": "Ghana",
    "height": "185",
    "weight": "79",
    "injured": false,
    "photo": "https://media.api-sports.io/football/players/19281.png"
  },
  "statistics": [
    {
      "team": {
        "id": 50,
        "name": "Manchester City",
        "logo": "https://media.api-sports.io/football/teams/50.png"
      },
      "league": {
        "id": 39,
        "name": "Premier League",
        "country": "England",
        "logo": "https://media.api-sports.io/football/leagues/39.png",
        "flag": "https://media.api-sports.io/flags/gb-eng.svg",
        "season": 2025
      },
      "games": {
        "appearences": 17,
        "lineups": 17,
        "minutes": 1402,
        "number": 42,
        "position": "Midfielder",
        "rating": "6.94",
        "captain": false
      },
      "substitutes": {
        "in": 0,
        "out": 8,
        "bench": 0
      },
      "shots": {
        "total": 27,
        "on": 14
      },
      "goals": {
        "total": 7,
        "conceded": 0,
        "assists": 1,
        "saves": null
      },
      "passes": {
        "total": 420,
        "key": 14,
        "accuracy": 85
      },
      "tackles": {
        "total": 17,
        "blocks": 4,
        "interceptions": 7
      },
      "duels": {
        "total": 153,
        "won": 58
      },
      "dribbles": {
        "attempts": 56,
        "success": 21,
        "past": null
      },
      "fouls": {
        "drawn": 7,
        "committed": 18
      },
      "cards": {
        "yellow": 1,
        "yellowred": 0,
     
  ... [tronqué]
```

## 21_players_aston_villa_page1.json

```json
{
  "player": {
    "id": 19035,
    "name": "H. Elliott",
    "firstname": "Harvey Daniel James",
    "lastname": "Elliott",
    "age": 22,
    "birth": {
      "date": "2003-04-04",
      "place": "Chertsey",
      "country": "England"
    },
    "nationality": "England",
    "height": "170",
    "weight": "64",
    "injured": false,
    "photo": "https://media.api-sports.io/football/players/19035.png"
  },
  "statistics": [
    {
      "team": {
        "id": 66,
        "name": "Aston Villa",
        "logo": "https://media.api-sports.io/football/teams/66.png"
      },
      "league": {
        "id": 39,
        "name": "Premier League",
        "country": "England",
        "logo": "https://media.api-sports.io/football/leagues/39.png",
        "flag": "https://media.api-sports.io/flags/gb-eng.svg",
        "season": 2025
      },
      "games": {
        "appearences": 4,
        "lineups": 1,
        "minutes": 109,
        "number": 9,
        "position": "Midfielder",
        "rating": "6.55",
        "captain": false
      },
      "substitutes": {
        "in": 3,
        "out": 1,
        "bench": 7
      },
      "shots": {
        "total": 1,
        "on": null
      },
      "goals": {
        "total": 0,
        "conceded": 0,
        "assists": 0,
        "saves": null
      },
      "passes": {
        "total": 74,
        "key": 1,
        "accuracy": 87
      },
      "tackles": {
        "total": null,
        "blocks": 1,
        "interceptions": null
      },
      "duels": {
        "total": 4,
        "won": 3
      },
      "dribbles": {
        "attempts": null,
        "success": null,
        "past": null
      },
      "fouls": {
        "drawn": 2,
        "committed": null
      },
      "cards": {
        "yellow": 0,
        "yellowred": 
  ... [tronqué]
```

## 22_coaches_man_city.json

```json
{
  "id": 4,
  "name": "Guardiola",
  "firstname": null,
  "lastname": null,
  "age": null,
  "birth": {
    "date": null,
    "place": null,
    "country": null
  },
  "nationality": null,
  "height": null,
  "weight": null,
  "photo": "https://media.api-sports.io/football/coachs/4.png",
  "team": {
    "id": 50,
    "name": "Manchester City",
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "career": [
    {
      "team": {
        "id": 50,
        "name": "Manchester City",
        "logo": "https://media.api-sports.io/football/teams/50.png"
      },
      "start": "2016-07-01",
      "end": null
    }
  ]
}
```

## 23_coaches_aston_villa.json

```json
{
  "id": 18,
  "name": "Unai Emery",
  "firstname": "Unai",
  "lastname": "Emery Etxegoien",
  "age": 54,
  "birth": {
    "date": "1971-11-03",
    "place": "Hondarribia",
    "country": "Spain"
  },
  "nationality": "Spain",
  "height": null,
  "weight": null,
  "photo": "https://media.api-sports.io/football/coachs/18.png",
  "team": {
    "id": 66,
    "name": "Aston Villa",
    "logo": "https://media.api-sports.io/football/teams/66.png"
  },
  "career": [
    {
      "team": {
        "id": 66,
        "name": "Aston Villa",
        "logo": "https://media.api-sports.io/football/teams/66.png"
      },
      "start": "2022-11-01",
      "end": null
    },
    {
      "team": {
        "id": 533,
        "name": "Villarreal",
        "logo": "https://media.api-sports.io/football/teams/533.png"
      },
      "start": "2020-07-01",
      "end": "2022-10-01"
    },
    {
      "team": {
        "id": 42,
        "name": "Arsenal",
        "logo": "https://media.api-sports.io/football/teams/42.png"
      },
      "start": "2018-05-01",
      "end": "2019-11-01"
    },
    {
      "team": {
        "id": 85,
        "name": "PSG",
        "logo": "https://media.api-sports.io/football/teams/85.png"
      },
      "start": "2016-06-01",
      "end": "2018-05-01"
    },
    {
      "team": {
        "id": 536,
        "name": "Sevilla",
        "logo": "https://media.api-sports.io/football/teams/536.png"
      },
      "start": "2013-01-01",
      "end": "2016-06-01"
    },
    {
      "team": {
        "id": 558,
        "name": "Spartak Moscow",
        "logo": "https://media.api-sports.io/football/teams/558.png"
      },
      "start": "2012-06-01",
      "end": "2012-11-01"
    },
    {
      "team": {
        "id": 532,
        "name": "Valencia",
        "logo": "https
  ... [tronqué]
```

## 24_team_man_city.json

```json
{
  "team": {
    "id": 50,
    "name": "Manchester City",
    "code": "MCI",
    "country": "England",
    "founded": 1880,
    "national": false,
    "logo": "https://media.api-sports.io/football/teams/50.png"
  },
  "venue": {
    "id": 555,
    "name": "Etihad Stadium",
    "address": "Rowsley Street",
    "city": "Manchester",
    "capacity": 55097,
    "surface": "grass",
    "image": "https://media.api-sports.io/football/venues/555.png"
  }
}
```

## 25_team_aston_villa.json

```json
{
  "team": {
    "id": 66,
    "name": "Aston Villa",
    "code": "AST",
    "country": "England",
    "founded": 1874,
    "national": false,
    "logo": "https://media.api-sports.io/football/teams/66.png"
  },
  "venue": {
    "id": 495,
    "name": "Villa Park",
    "address": "Trinity Road",
    "city": "Birmingham",
    "capacity": 42824,
    "surface": "grass",
    "image": "https://media.api-sports.io/football/venues/495.png"
  }
}
```

## 26_venue_etihad.json

```json
{
  "id": 555,
  "name": "Etihad Stadium",
  "address": "Rowsley Street",
  "city": "Manchester",
  "country": "England",
  "capacity": 55097,
  "surface": "grass",
  "image": "https://media.api-sports.io/football/venues/555.png"
}
```

## 27_league_pl_2025.json

```json
{
  "league": {
    "id": 39,
    "name": "Premier League",
    "type": "League",
    "logo": "https://media.api-sports.io/football/leagues/39.png"
  },
  "country": {
    "name": "England",
    "code": "GB-ENG",
    "flag": "https://media.api-sports.io/flags/gb-eng.svg"
  },
  "seasons": [
    {
      "year": 2025,
      "start": "2025-08-15",
      "end": "2026-05-24",
      "current": false,
      "coverage": {
        "fixtures": {
          "events": true,
          "lineups": true,
          "statistics_fixtures": true,
          "statistics_players": true
        },
        "standings": true,
        "players": true,
        "top_scorers": true,
        "top_assists": true,
        "top_cards": true,
        "injuries": true,
        "predictions": true,
        "odds": false
      }
    }
  ]
}
```

## 28_odds_bookmakers.json

```json
{
  "id": 1,
  "name": "10Bet"
}
```

## 29_odds_bets.json

```json
{
  "id": 1,
  "name": "Match Winner"
}
```

## 30_players_man_city_page2.json

```json
{
  "player": {
    "id": 633,
    "name": "İ. Gündoğan",
    "firstname": "İlkay",
    "lastname": "Gündoğan",
    "age": 35,
    "birth": {
      "date": "1990-10-24",
      "place": "Gelsenkirchen",
      "country": "Germany"
    },
    "nationality": "Germany",
    "height": "180",
    "weight": "80",
    "injured": false,
    "photo": "https://media.api-sports.io/football/players/633.png"
  },
  "statistics": [
    {
      "team": {
        "id": 50,
        "name": "Manchester City",
        "logo": "https://media.api-sports.io/football/teams/50.png"
      },
      "league": {
        "id": 39,
        "name": "Premier League",
        "country": "England",
        "logo": "https://media.api-sports.io/football/leagues/39.png",
        "flag": "https://media.api-sports.io/flags/gb-eng.svg",
        "season": 2025
      },
      "games": {
        "appearences": 0,
        "lineups": 0,
        "minutes": null,
        "number": 19,
        "position": "Midfielder",
        "rating": null,
        "captain": false
      },
      "substitutes": {
        "in": 0,
        "out": 0,
        "bench": 2
      },
      "shots": {
        "total": null,
        "on": null
      },
      "goals": {
        "total": 0,
        "conceded": 0,
        "assists": 0,
        "saves": null
      },
      "passes": {
        "total": null,
        "key": null,
        "accuracy": null
      },
      "tackles": {
        "total": null,
        "blocks": null,
        "interceptions": null
      },
      "duels": {
        "total": null,
        "won": null
      },
      "dribbles": {
        "attempts": null,
        "success": null,
        "past": null
      },
      "fouls": {
        "drawn": null,
        "committed": null
      },
      "cards": {
        "yellow": 0,
      
  ... [tronqué]
```

## 31_players_aston_villa_page2.json

```json
{
  "player": {
    "id": 162173,
    "name": "S. Iling-Junior",
    "firstname": "Samuel",
    "lastname": "Iling-Junior",
    "age": 22,
    "birth": {
      "date": "2003-10-04",
      "place": "London",
      "country": "England"
    },
    "nationality": "England",
    "height": "182",
    "weight": "74",
    "injured": false,
    "photo": "https://media.api-sports.io/football/players/162173.png"
  },
  "statistics": [
    {
      "team": {
        "id": 66,
        "name": "Aston Villa",
        "logo": "https://media.api-sports.io/football/teams/66.png"
      },
      "league": {
        "id": 39,
        "name": "Premier League",
        "country": "England",
        "logo": "https://media.api-sports.io/football/leagues/39.png",
        "flag": "https://media.api-sports.io/flags/gb-eng.svg",
        "season": 2025
      },
      "games": {
        "appearences": 0,
        "lineups": 0,
        "minutes": null,
        "number": 19,
        "position": "Attacker",
        "rating": null,
        "captain": false
      },
      "substitutes": {
        "in": 0,
        "out": 0,
        "bench": 1
      },
      "shots": {
        "total": null,
        "on": null
      },
      "goals": {
        "total": 0,
        "conceded": 0,
        "assists": 0,
        "saves": null
      },
      "passes": {
        "total": null,
        "key": null,
        "accuracy": null
      },
      "tackles": {
        "total": null,
        "blocks": null,
        "interceptions": null
      },
      "duels": {
        "total": null,
        "won": null
      },
      "dribbles": {
        "attempts": null,
        "success": null,
        "past": null
      },
      "fouls": {
        "drawn": null,
        "committed": null
      },
      "cards": {
        "yellow": 0,
    
  ... [tronqué]
```

## 32_odds_by_date_pl_2025.json

```json
{
  "response": [],
  "results": 0,
  "errors": []
}
```

## 33_invalid_fixtures_man_city_to_last.json

```json
{
  "response": [],
  "results": 0,
  "errors": {
    "to": "The To field cannot be used with Last field."
  }
}
```

## 34_invalid_fixtures_aston_villa_to_last.json

```json
{
  "response": [],
  "results": 0,
  "errors": {
    "to": "The To field cannot be used with Last field."
  }
}
```
