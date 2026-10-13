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

No betting formulas, personal preferences, historical cutoffs or saved
conversations have been modified by this change.

## Theme and fixture follow-up

The unwanted European Markets tab and the full quote browser in fixture Context
have been removed. Sporting readings in Context, card 1N2 quotes and Generator
quote data remain available.

`CompetitionCardTheme` now derives surfaces and borders from the selected app
palette. Competition color only tints that surface. `CompetitionCardBackground`
is reused by match cards, briefing cards and the European fixture hero. Artwork
has a themed scrim; its opacity is limited against both white and black pixels.
Text and status colors retain at least 4.5:1 contrast. Secondary text may become
slightly stronger on artwork while keeping the selected theme's text hue. Odds
use an opaque surface. The match page no longer puts a black top gradient in
light themes, and the top navigation selected fill follows the selected palette.

Coverage includes all ten selectable themes, all four competition identities,
320 px card/briefing composition, existing 320/375/390/430/tablet card checks and
European detail navigation/actions. The render tool captures real shared Flutter
components using archived public sporting snapshots. It performs no account,
provider or model call.

The final live backend update used price-only SQL snapshot revisions. Context
reconstruction was too large to transfer reliably; the price revision clones the
original data inside the database, merges already collected prices and preserves
fixture indexes, sporting dossiers and actual observation dates. On 13 October
at 00:26 UTC, the actual catalog/calculator produced a six-pick, 30 EUR ticket
mixing Championship and Champions League. All 18 published upcoming fixtures
had recent quotes for each of CL, EL and Conference at that check. This was a
calculator verification, not a paid LLM replay. Freshness continues to evolve
with the real collection schedule.

## Final delivery

The demo alias points to `dpl_7yKSN3YLhHyPkpehBinUPeFw3hap` and is accessible
without Vercel authentication (anonymous HTTP 200). UI source 09ee236 passed full
CI: 941 Flutter tests passed, two skipped, and backend/deployment checks passed.
The public browser confirmed dark/light Champions cards, the Championship crest
and watermark, all five European detail tabs without Markets, and compact CL,
EL and Conference briefings. The original theme and date were restored.

A second actual catalog/calculator check at 08:33 UTC again produced the mixed
six-pick 30 EUR ticket. CL and EL prices remained recent. Conference's 18 prices
had crossed the unchanged 48-hour freshness threshold: they remain readable by
the agent but need a fresh provider observation before ticket eligibility.

No new competition artwork was generated; the three existing original bitmap
assets remain in place. Themes now control their material, text and contrast.
The delivery receipt contains source/deployment identities and capture paths.
