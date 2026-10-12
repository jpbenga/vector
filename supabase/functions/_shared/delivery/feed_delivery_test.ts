import assert from "node:assert/strict";
import {
  dayKey,
  dayOverview,
  type DeliveryPart,
  europeanCardForms,
  footballCardMarketIds,
  overviewPart,
  partArtifacts,
  selectParts,
} from "./feed_delivery.ts";
import football from "../../../../test/fixtures/football_calendar_14_days_compact.json" with {
  type: "json",
};
import hockey from "../../../../test/fixtures/sports/nhl_compact.json" with {
  type: "json",
};
import europeanFormFixture from "../../../../test/fixtures/european_lask_liverpool_card_form.json" with {
  type: "json",
};
function part(
  sport: "football" | "hockey",
  payload: Record<string, unknown>,
  id = "source",
): DeliveryPart {
  const bundle = partArtifacts(sport, id, payload);
  return {
    id,
    scopeKey: sport,
    capturedAt: String(payload.captured_at ?? payload.capturedAt),
    asOf: String(payload.captured_at ?? payload.capturedAt),
    windowStart: String(payload.window_start ?? payload.windowStart),
    windowEnd: String(payload.window_end ?? payload.windowEnd),
    overview: bundle.overview,
    fullPath: `delivery/${sport}/${id}/full.json`,
  };
}
Deno.test("football daily delivery retains all card odds and server readings without rankings or history", () => {
  const p = part("football", football);
  const day = dayOverview("football", [p], "2030-10-04")!;
  const raw = day.raw as Record<string, unknown>;
  assert.equal((raw.fixtures as unknown[]).length, 1);
  assert.equal(raw.standings, undefined);
  assert.equal(raw.head_to_head, undefined);
  const fixture =
    (day.computed as { fixtures: Record<string, unknown>[] }).fixtures[0];
  assert.deepEqual(fixture.readings, football.computed.fixtures[0].readings);
  assert.equal(fixture.tier_snapshot, undefined);
  const artifacts = partArtifacts("football", "source", football).artifacts;
  const full = artifacts.get("delivery/football/source/match-1.json")!;
  assert.deepEqual((full.computed as { fixtures: unknown[] }).fixtures, [
    football.computed.fixtures[0],
  ]);
  assert.ok(artifacts.has("delivery/football/source/context.json"));
  const radar = artifacts.get("delivery/football/source/radar.json")!;
  assert.equal((radar.raw as Record<string, unknown>).standings, undefined);
  assert.deepEqual(
    (radar.computed as { fixtures: Record<string, unknown>[] }).fixtures[0]
      .readings,
    football.computed.fixtures[0].readings,
  );
  assert.deepEqual(
    (radar.raw as Record<string, unknown>).recent_league_matches,
    football.raw.recent_league_matches,
  );
  assert.deepEqual((day.delivery as Record<string, unknown>).radarPaths, [
    "delivery/football/source/radar.json",
  ]);
});
Deno.test("hockey overview keeps reading facts and defers event logs, preserving originals", () => {
  const full = structuredClone(hockey) as unknown as Record<string, unknown>;
  const item = (full.items as Record<string, unknown>[])[0];
  item.headToHead = {
    collectedAt: full.capturedAt,
    meetings: [{
      id: "old",
      scores: { final: { home: 2, away: 1 } },
      events: [{ type: "goal" }],
      eventsCollected: true,
    }],
  };
  item.matchEvents = { events: [{ type: "goal" }] };
  const compact = overviewPart("hockey", full);
  const card = (compact.items as Record<string, unknown>[])[0];
  assert.equal(card.matchEvents, undefined);
  const h =
    (card.headToHead as { meetings: Record<string, unknown>[] }).meetings[0];
  assert.deepEqual(h.events, []);
  assert.equal(h.eventsCollected, false);
  assert.deepEqual(h.scores, { final: { home: 2, away: 1 } });
  assert.equal(
    ((item.headToHead as { meetings: Record<string, unknown>[] }).meetings[0]
      .events as unknown[]).length,
    1,
  );
  const artifacts = partArtifacts("hockey", "source", full).artifacts;
  const detail = artifacts.get(`delivery/hockey/source/match-${item.id}.json`)!;
  assert.deepEqual((detail.items as unknown[])[0], item);
});
Deno.test("calendar boundaries and historical selection use Paris and frozen source times", () => {
  assert.equal(dayKey("2026-10-24T23:30:00Z"), "2026-10-25");
  assert.equal(dayKey("2026-10-25T23:30:00Z"), "2026-10-26");
  const old = {
    ...part("football", football, "old"),
    scopeKey: "league:61",
    windowStart: "2026-10-24",
    windowEnd: "2026-11-07",
    asOf: "2026-10-25T22:59:00Z",
  };
  const next = { ...old, id: "next", asOf: "2026-10-25T23:00:00Z" };
  assert.deepEqual(
    selectParts([next, old], "2026-10-25", "2026-10-26").map((p) => p.id),
    ["old"],
  );
  assert.deepEqual(
    selectParts([next, old], "2026-10-26", "2026-10-26").map((p) => p.id),
    ["next"],
  );
  assert.equal(dayOverview("football", [], "2026-10-25"), null);
});
Deno.test("covered league publication wins over newer fallback and duplicate fixture authority stays coherent", () => {
  const covered = {
    ...part("football", football, "covered"),
    windowStart: "2030-10-04",
    windowEnd: "2030-10-17",
    asOf: "2030-10-04T04:00:00Z",
  };
  const fallback = {
    ...covered,
    id: "newer",
    windowStart: "2030-10-05",
    asOf: "2030-10-04T05:00:00Z",
  };
  assert.deepEqual(
    selectParts([fallback, covered], "2030-10-04", "2030-10-04").map((p) =>
      p.id
    ),
    ["covered"],
  );
});

Deno.test("card markets stay aligned with the Flutter odds catalogue", async () => {
  const dart = await Deno.readTextFile(
    "lib/features/matches/domain/odds_normalization.dart",
  );
  const ids = [...dart.matchAll(/apiFootballBetId: (\d+),/g)].map((m) =>
    Number(m[1])
  );
  assert.deepEqual(footballCardMarketIds, ids);
});
Deno.test("European dossiers travel only with the requested detail, not all day cards or shared context", () => {
  const full = structuredClone(football) as unknown as Record<string, unknown>;
  const raw = full.raw as Record<string, unknown>;
  raw.european_comparisons = [{ fixtureId: 1, home: { teamId: 10 } }, {
    fixtureId: 99,
    home: { teamId: 20 },
  }];
  const result = partArtifacts("football", "european-contract", full);
  assert.equal(
    (result.overview.raw as Record<string, unknown>).european_comparisons,
    undefined,
  );
  const context = result.artifacts.get(
    "delivery/football/european-contract/context.json",
  )!;
  assert.equal(
    (context.raw as Record<string, unknown>).european_comparisons,
    undefined,
  );
  const detail = result.artifacts.get(
    "delivery/football/european-contract/match-1.json",
  )!;
  assert.deepEqual(
    (detail.raw as Record<string, unknown>).european_comparisons,
    [{ fixtureId: 1, home: { teamId: 10 } }],
  );
});

Deno.test("European day cards carry played competition results while domestic form remains in the detail", () => {
  const full = structuredClone(europeanFormFixture) as unknown as Record<
    string,
    unknown
  >;
  const bundle = part("football", full);
  const raw = bundle.overview.raw as Record<string, unknown>;
  const forms = raw.european_card_forms as Record<string, unknown>[];
  assert.equal(forms.length, 1);
  assert.equal(
    ((forms[0].home as Record<string, unknown>)
      .europeanRecentMatches as unknown[]).length,
    3,
  );
  assert.equal(
    ((forms[0].away as Record<string, unknown>)
      .europeanRecentMatches as unknown[]).length,
    1,
  );
  assert.equal(
    (forms[0].away as Record<string, unknown>).domesticRecentMatches,
    undefined,
  );
  const day = dayOverview("football", [bundle], "2026-10-14")!;
  assert.deepEqual(
    (day.raw as Record<string, unknown>).european_card_forms,
    forms,
  );
  const detail = partArtifacts("football", "europe-form", full).artifacts.get(
    "delivery/football/europe-form/match-1635674.json",
  )!;
  const detailDossier = (detail.raw as {
    european_comparisons: {
      away: {
        domesticRecentMatches: unknown[];
        europeanRecentMatches: unknown[];
      };
    }[];
  }).european_comparisons[0];
  assert.equal(detailDossier.away.domesticRecentMatches.length, 5);
  assert.equal(detailDossier.away.europeanRecentMatches.length, 1);
  const sourceRaw = full.raw as Record<string, unknown>;
  const dossier =
    (sourceRaw.european_comparisons as Record<string, unknown>[])[0];
  const home = dossier.home as Record<string, unknown>;
  const games = home.europeanRecentMatches as Record<string, unknown>[];
  games.push({
    ...games[0],
    fixtureId: 900001,
    playedAt: "2026-10-15T18:00:00Z",
  });
  games.push({ ...games[0], fixtureId: 900002, competitionId: 61 });
  games.push({ ...games[0], fixtureId: 900003, season: 1999 });
  games.push({ ...games[0] });
  const projected = europeanCardForms(sourceRaw);
  assert.equal(
    ((projected[0].home as Record<string, unknown>)
      .europeanRecentMatches as unknown[]).length,
    3,
  );
  dossier.home = { ...home, teamId: 99 };
  assert.equal(europeanCardForms(sourceRaw).length, 0);
});
