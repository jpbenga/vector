# Profile Schema V1

## Objectif

Le profil compilé est le contrat stable entre l'onboarding et le moteur.

Le moteur ne lit pas les numéros de questions, les libellés UI ou les réponses
brutes. Il reçoit uniquement un `CompiledDecisionProfile` versionné.

## Version

```text
profile_schema_version = 1
```

## Champs V1

- `competitions` : compétitions activées, priorité et poids.
- `markets` : marchés internes activés, priorité, poids et seuil de cote.
- `analysisCriteria` : informations à prioriser dans les explications.
- `decisionInfluences` : dimensions qui pèsent dans la décision.
- `matchTypes` : types de rencontres recherchés.
- `ticketSelectionCounts` : préférences futures du ticket builder.
- `ticketOddsRanges` : plages de cote futures du ticket builder.
- `bettingApproaches` : orientation stratégique déclarée.
- `feedDepth` : nombre maximum de recommandations à mettre en avant.
- `oddsImportance` : poids normalisé de la cote dans le processus utilisateur.
- `analysisTimeId` et `bettingFrequencyId` : métadonnées comportementales.

## Mapping marchés V1

| Onboarding | Marché interne |
|---|---|
| `match_result` | `matchResult` |
| `both_teams_score` | `bothTeamsScore` |
| `team_scores` | `teamTotalHome`, `teamTotalAway` |
| `goals_over_under` | `goalsTotal` |
| `corners` | `cornersTotal` |
| `cards` | `cardsTotal` |
| `double_chance` | `doubleChance` |

## Règles

- Une option non sélectionnée reste présente mais désactivée.
- Les priorités sont transformées en poids par le compilateur.
- Le seuil de cote est une règle d'éligibilité, pas un jugement de qualité.
- Les valeurs manquantes utilisent les valeurs par défaut du questionnaire.
- Le moteur ne doit jamais dépendre d'un identifiant de question.
