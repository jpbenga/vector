# Cards and Generator quotes — 13 October 2026

## Verified incident

The owner conversation at 00:42–00:47 Paris time requested six football selections,
30 EUR, mixing Championship and Champions League. The response retained only
Championship fixtures, explaining that Champions League had no recent admissible
prices. The visible Lens–Sporting quote was dated 10 October at 05:57 Paris time.
The catalog rejected quote observations over 48 hours old. Price presence was
therefore confused with access/admissibility.

The European dossier reconstruction started from older sporting snapshots and
updated contexts but omitted newer `/odds` cache rows. The cache contains newer
CL/EL/Conference collections. Reconstruction now merges cached prices by fixture,
league and season, preserves provider observation times, and carries cache source
records. It performs no provider or model call.

## Changes

- Agent `read_matches` exposes published quotes independently of recommendation
  candidates. `read_match_data` also exposes all published football markets for the
  pinned fixture. Each quote identifies selection, bookmaker and observation date.
- A `stale` availability and `quotes_stale` reason distinguish old quotes from
  absent quotes. Freshness and direct-evidence checks for ticket candidates remain.
- The planner must explain the actual exclusion and respect requested competitions.
- Original web Roboto is bundled with regular, medium, bold and black weights.
  Inter was declared earlier but first bundled by commit 38271d9 on 12 October.
- Shared cards place odds below the time in the right column. Scope labels have a
  compact rendering and their full description is available in the tooltip.
- Competition logos retain their original colors. The generic watermark uses the
  real logo; the monochrome source-in mask has been removed.
- Profile personalization records exact retained reading IDs, checked again by
  card rendering. The label `Avantage classement` was an alias for the selectable
  `structural_level_gap` reading. It now uses `Écart de niveau structurel`.
- European briefing carousel height follows intrinsic content, preserving swipe
  priority CL, EL, Conference. No synthetic summary badges were added.

## Local validation

126 Generator tests pass, including price availability, source identity, stale
prices and absent recommendation support. 25 deployment guard tests pass.
23 targeted Flutter tests pass for scope filtering, badges, chronological form,
responsive cards and the briefing carousel. Full CI and real browser verification
are recorded in the delivery receipt after deployment.

No betting formulas, prices, personal preferences, historical cutoffs or saved
conversations have been modified by this change.
