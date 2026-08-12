# Opportunity Architecture

## Contract

`Opportunity` is the new business unit produced by the decision engine.

It represents one analyzed match for which Copilot retained at least one
sporting thesis that matches the user's opportunity profile.

It is not a pick and it is not a ticket.

## Pipeline

```text
Match
  -> analysis
  -> Opportunity
  -> recommended market
  -> Pick
  -> Ticket
```

The engine layer stops at `Opportunity`.

Pick and ticket generation must consume opportunities. They must not rescan raw
matches independently.

## Opportunity Fields

The current domain object is defined in
`lib/features/opportunities/domain/opportunity.dart`.

It contains:

- `sourceMatch`: normalized match and raw analysis context.
- `matchId`, `competition`, `homeTeam`, `awayTeam`, `kickoff`: match identity.
- `engineScore`: internal engine score used for ordering.
- `detectedSignals`: condensed signals shown by Copilot.
- `retainedTheses`: one or more sporting theses retained for the same match.
- `opportunityProfileIds`: user opportunity profiles matched by the theses.
- `compatibleMarkets`: markets and selections compatible with the opportunity
  and the user's enabled markets.
- `recommendedMarket`: the single market selected for the default pick
  translation, when one exists.
- `copilotArguments` and `statisticalEvidence`: supporting arguments and proof.

## Invariants

- One match produces at most one opportunity in a generated list.
- One opportunity may contain several retained theses.
- Markets do not select matches; they only translate an opportunity into a pick.
- A missing recommended market does not erase the sporting opportunity.
- The Ticket Generator must only consume persisted `TicketStrategy` objects and
  the opportunity list already produced for the user.
- A generated ticket must never contain a match that is absent from the
  opportunity list used by "Pour moi".

## UI Boundary

`MatchInsightEngine.opportunities(...)` is the canonical engine output.
`MatchFeedRepository.opportunitiesFor(...)` exposes this output to the UI.

"Pour moi", match detail and the Ticket Generator consume `Opportunity`
directly where they need the decision trace. `MatchBoardItem` remains useful as
a normalized match projection for "Toutes les rencontres" and for shared display
components.

## DecisionProfile Boundary

The compiled profile describes only:

- enabled competitions;
- enabled markets;
- enabled opportunity profiles;
- configuration state.

It does not contain a global pick type, ticket odds range, selection count, or
ticket construction preference.

The compiled profile still has an `opportunityProfiles` semantic alias over the
existing persisted `matchTypes` field.

The persisted field is kept temporarily for compatibility with the validated V2
onboarding. Future migrations can rename it once the opportunity architecture is
fully deployed.

Ticket-related onboarding answers remain outside `CompiledDecisionProfile`; only
persisted `TicketStrategy` objects may drive future ticket generation.

## Supported Opportunity Profiles

Supported today in the MVP front:

- `solid_favorite`: theses `solid_favorite`, `cautious_double_chance`.
- `offensive_match`: thesis `open_match`.
- `defensive_match`: thesis `closed_match`.
- `ranking_gap`: thesis `level_gap`.
- `credible_outsider`: thesis `credible_outsider`.
- `struggling_team`.
- `fragile_defense`.
- `prolific_attack`.
- `positive_series`.
- `negative_series`.

## Markets

The V3 onboarding includes `player_scorer`, compiled as
`playerAnytimeScorer`.

This is a stable player-market identifier reserved for scorer markets. It is
present in the user profile but no scorer thesis is generated yet because the
engine does not currently have validated player-level data.

## Deferred

- Rename persisted `matchTypes` to `opportunityProfiles` in a future schema
  version.
- Replace local snapshots and stores with backend-backed immutable data.
