# Ticket Generator

## Source

The Ticket Generator consumes only:

- `List<Opportunity>` from `MatchFeedRepository.opportunitiesFor(...)`;
- persisted, active `TicketStrategy` objects;
- the compiled profile state to block generation when the profile is incomplete.

It does not read onboarding answers, all matches, API payloads, or transient
strategy suggestions.

Generation is scoped to one fixture day. A generated ticket must never mix picks
from different calendar days.

## Contracts

Domain files:

- `lib/features/tickets/domain/generated_ticket_pick.dart`
- `lib/features/tickets/domain/generated_ticket.dart`
- `lib/features/tickets/domain/ticket_generation_result.dart`
- `lib/features/tickets/domain/ticket_generator.dart`

`GeneratedTicketPick` keeps the traceability to the source `Opportunity` through
`opportunityId` and `matchId`.

`TicketGenerationResult` distinguishes:

- generated tickets;
- incomplete profile;
- no active strategy;
- no usable opportunity;
- not enough compatible picks;
- no combination matching total-odds constraints;
- invalid strategy configuration.

## Pick Eligibility

An `Opportunity` can become a generated pick only when:

- it is already part of the personalized opportunity list;
- it has a recommended market;
- the recommended selection has odds `>= 1.20`;
- the odds can be classified as a `PickType`;
- the strategy allows that `PickType`.

Pick type bands:

- `prudent`: `1.20 <= odds <= 1.49`;
- `normal`: `1.50 <= odds <= 2.19`;
- `audacious`: `odds >= 2.20`.

## Algorithm

For each active strategy, the generator:

1. Converts eligible opportunities into `GeneratedTicketPick`.
2. Filters picks by the strategy `pickTypes`.
3. Sorts candidates deterministically:
   - opportunity score descending;
   - number of opportunity profiles descending;
   - `matchId` ascending as stable fallback.
4. Keeps at most `maxCandidatesPerStrategy`.
5. Groups picks by fixture day, or keeps only the requested target day.
6. Enumerates combinations between `minimumSelections` and
   `maximumSelections`.
7. Rejects combinations with duplicate `matchId`.
8. Rejects combinations that contain multiple fixture days.
9. Computes total odds through integer cents and `BigInt`, then rounds to two
   decimals for comparison and display.
10. Keeps only combinations inside the strategy total-odds bounds.
11. Ranks valid combinations by:
   - distance to the target total odds;
   - total opportunity score descending;
   - total opportunity-profile count descending;
   - stable match-id key ascending.
12. Keeps at most `maxVariantsPerStrategy`, with no duplicate combination.

Closed total-odds strategies target the midpoint between min and max. Open-ended
strategies target the minimum bound.

No random value is used.

## Performance Bounds

MVP defaults:

- `maxVariantsPerStrategy = 3`;
- `maxCandidatesPerStrategy = 18`;
- `maxCombinationsEvaluatedPerStrategy = 600`.

These limits live in `TicketGenerator` constructor parameters and are not
scattered through the UI.

## Local MVP Capabilities

- Persisting a user-retained generated ticket locally.
- Saving Copilot, modified and manual tickets.
- Reopening saved tickets from history.
- Tracking played, won, lost, voided and unplayed local statuses.

## Deferred To Backend Or Later Product Iterations

- Advanced ticket filters.
- Ticket probability or payout language.
- Using non-recommended compatible markets.
- Remote persistence and automatic settlement from official results.
