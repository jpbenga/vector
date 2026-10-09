import assert from "node:assert/strict";
import { buildCatalog, type Source } from "./catalog.ts";
import { context as profile, intent, now, source } from "./evaluation_cases.ts";
import {
  type Context,
  contextFrom,
  obj,
  type RadarScope,
  rows,
} from "./contracts.ts";
import { analysisContext, analyzeDay, validateAnalysis } from "./analysis.ts";
import { scopedRadarEvidence } from "./radar_scope.ts";

const snapshot = "11111111-1111-4111-8111-111111111111";
function scope(): RadarScope {
  return {
    version: 1,
    mode: "players",
    category: "club",
    capturedAt: now.toISOString(),
    sourceIds: [snapshot],
    includeWomen: false,
    includeYouth: false,
    competitionId: null,
    teams: [{
      id: "2",
      teamId: "2",
      rank: 1,
      matchIds: ["10", "11", "12", "13", "14"],
    }],
    players: [{ id: "7", teamId: "4", rank: 1, matchIds: ["20", "21", "22"] }],
  };
}
function publication(): Source {
  const p = source();
  p.id = snapshot;
  obj(p.payload.raw).recent_league_matches = [{
    team: { id: 2, name: "Penafiel" },
    league: { id: 61 },
    matches: [10, 11, 12, 13, 14].map((id, i) => ({
      fixture: { id, date: `2026-10-0${i + 1}T18:00:00Z` },
      result: "W",
    })),
  }];
  obj(p.payload.raw).player_form_radar = [{
    player: { id: 7, name: "Joueur A" },
    team: { id: 4 },
    activity: [20, 21, 22].map((id, i) => ({
      fixture_id: id,
      played_at: `2026-10-0${i + 1}T18:00:00Z`,
      goals: i === 2 ? 2 : 0,
      assists: 0,
    })),
  }];
  // The opponent has strong readings, but is absent from the user's Radar.
  for (const a of rows(obj(p.payload.computed).fixtures)) {
    rows(a.readings).push();
    (a.readings as unknown[]).push({
      id: "positive_streak",
      side: "away",
      subject_team_id: 3,
      label: "En série",
      sample_size: 5,
    });
  }
  for (const odds of rows(obj(p.payload.raw).odds)) {
    (rows(rows(odds.bookmakers)[0].bets)[0].values as unknown[]).push({
      value: "Away",
      odd: "2.00",
    });
  }
  return p;
}
const radar = (s = scope(), kind: "teams" | "players" = "teams"): Context => ({
  ...profile,
  view: "radar",
  scope: "discovery",
  radarKind: kind,
  radar: { football: s },
});
Deno.test("native Radar membership gates matches AND the team selected, not synthetic match readings", () => {
  const c = buildCatalog([publication()], radar(), intent.date, now);
  assert.deepEqual(c.matches?.map((m) => m.id), ["api-fixture-1"]);
  assert.equal(c.candidates.length, 2);
  assert.ok(c.candidates.every((c) => c.selection.includes("domicile")));
  assert.ok(
    c.candidates.every((c) =>
      c.evidence.some((e) => e.source === "radar" && e.subject === "football:2")
    ),
  );
  assert.match(c.signals[0].text, /15\/15/);
  assert.equal(
    buildCatalog([publication()], { ...radar(), radar: {} }, intent.date, now)
      .matchCount,
    0,
  );
});
Deno.test("explicit teams overrides displayed players, while current follows the actual Radar toggle", () => {
  const current = analysisContext({ ...radar(), radarKind: undefined }, {
    ...intent,
    view: "radar",
    radarKind: "current",
  });
  assert.deepEqual(
    buildCatalog([publication()], current, intent.date, now).matches?.map((m) =>
      m.id
    ),
    ["api-fixture-2"],
  );
  const teams = analysisContext(current, {
    ...intent,
    view: "radar",
    radarKind: "teams",
  });
  assert.deepEqual(
    buildCatalog([publication()], teams, intent.date, now).matches?.map((m) =>
      m.id
    ),
    ["api-fixture-1"],
  );
  // One decisive match with two contributions qualifies just as in native Radar.
  assert.match(
    buildCatalog([publication()], current, intent.date, now).signals[0].text,
    /2 but\(s\).*1\/3/,
  );
});
Deno.test("published IDs bind the context; newer snapshots and missing history never replace it", () => {
  const p = publication(), newer = publication();
  newer.id = "22222222-2222-4222-8222-222222222222";
  rows(rows(obj(newer.payload.raw).recent_league_matches)[0].matches).forEach(
    (r) => r.result = "L",
  );
  assert.equal(buildCatalog([newer], radar(), intent.date, now).matchCount, 0);
  assert.match(
    buildCatalog([newer, p], radar(), intent.date, now).signals[0].text,
    /15\/15/,
  );
  const invalid = scope();
  invalid.teams[0].matchIds[0] = "999";
  assert.equal(
    buildCatalog([p], radar(invalid), intent.date, now).matchCount,
    0,
  );
  const empty = scope();
  empty.teams = [];
  assert.equal(buildCatalog([p], radar(empty), intent.date, now).matchCount, 0);
});
Deno.test("Radar permits factual exploration with no enabled readings but never invents market support", () => {
  const ctx = radar();
  ctx.preferences = {
    football: { competitions: [], readings: [], markets: ["matchResult"] },
  };
  const c = buildCatalog([publication()], ctx, intent.date, now);
  assert.equal(c.matchCount, 1);
  assert.equal(c.candidates.length, 0);
  assert.equal(c.matches?.[0].evidence.length, 1);
});
Deno.test("scope parser bounds membership and accepts real event-name hockey player identities", () => {
  const h = {
    ...scope(),
    sourceIds: [],
    players: [{
      id: "event-name:35:2026:377:R.%20Rafikov",
      teamId: "377",
      rank: 1,
      matchIds: ["20", "21", "22"],
    }],
  };
  assert.equal(
    contextFrom({ ...profile, radar: { hockey: h } }).radar?.hockey?.players[0]
      .id,
    h.players[0].id,
  );
  assert.throws(
    () =>
      contextFrom({
        ...profile,
        radar: {
          football: { ...scope(), teams: [...scope().teams, ...scope().teams] },
        },
      }),
    /invalide/,
  );
  assert.throws(
    () =>
      contextFrom({
        ...profile,
        radar: { football: { ...scope(), sourceIds: ["invented"] } },
      }),
    /invalide/,
  );
  const passed = contextFrom({ ...profile, radar: { football: scope() } })
    .radar!.football!;
  assert.equal(passed.teams[0].rank, 1);
  assert.deepEqual(passed.sourceIds, [snapshot]);
});
Deno.test("hockey uses the same member gate and league filter, with independently verified goals/assists", () => {
  const h: Source = {
    id: "hockey-run",
    sport: "hockey",
    capturedAt: now.toISOString(),
    payload: {
      items: [{
        id: "100",
        startsAt: "2026-10-10T18:00:00Z",
        status: "scheduled",
        competitionId: "35",
        competitionName: "KHL",
        home: { id: "2", name: "Home" },
        away: { id: "3", name: "Away" },
      }],
      competitions: [{
        id: "35",
        formPhaseVerified: true,
        tables: [{
          rows: [{
            team: { id: "2", name: "Home" },
            formHistory: [10, 11, 12, 13, 14].map((id, i) => ({
              id: String(id),
              startsAt: `2026-10-0${i + 1}T18:00:00Z`,
              outcome: "win",
            })),
          }],
        }],
      }],
    },
  };
  const s = { ...scope(), sourceIds: [], competitionId: "35" };
  const ctx: Context = {
    ...radar(),
    preferences: { hockey: { competitions: [], readings: [], markets: [] } },
    radar: { hockey: s },
  };
  assert.equal(buildCatalog([h], ctx, intent.date, now).matchCount, 1);
  assert.match(scopedRadarEvidence([h], ctx).get("hockey:2")![0].text, /5\/5/);
  assert.equal(
    buildCatalog(
      [{ ...h, capturedAt: "2026-10-08T11:00:00Z" }],
      ctx,
      intent.date,
      now,
    ).matchCount,
    0,
  );
  assert.equal(
    buildCatalog(
      [h],
      { ...ctx, radar: { hockey: { ...s, competitionId: "57" } } },
      intent.date,
      now,
    ).matchCount,
    0,
  );
});
Deno.test("analysis cannot cite only a reading to skip the Radar membership check", () => {
  const c = buildCatalog([publication()], radar(), intent.date, now),
    candidate = c.candidates[0];
  const facts = {
    context: {
      date: intent.date,
      view: "radar",
      sports: ["football" as const],
      matchCount: 1,
      candidateCount: 2,
    },
    byMatch: new Map([[candidate.matchId, {}]]),
    byCandidate: new Map([[candidate.id, candidate]]),
    detailsRead: new Set([candidate.matchId]),
    limit: 2,
    missing: [],
  };
  const result = {
    text: "Une équipe présente dans votre Radar.",
    comparedMatchIds: [candidate.matchId],
    limitations: [],
    selections: [{
      candidateId: candidate.id,
      reason: "Lectures de forme.",
      vigilance: "Un résultat n’est pas garanti.",
      references: [candidate.evidence[0].id],
    }],
  };
  assert.throws(() => validateAnalysis(result, facts), /références/);
  result.selections[0].references.push(
    candidate.evidence.find((e) => e.source === "radar")!.id,
  );
  assert.equal(validateAnalysis(result, facts).selections.length, 1);
});
Deno.test("empty native Radar abstains without an analysis model call and never replays an old recommendation", async () => {
  let paid = 0;
  const ctx = radar({ ...scope(), teams: [] });
  const a = await analyzeDay({
    message: "Deux équipes du Radar",
    intent: {
      ...intent,
      action: "analyze",
      tickets: [],
      view: "radar",
      radarKind: "teams",
    },
    context: ctx,
    catalog: buildCatalog([publication()], ctx, intent.date, now),
    state: null,
    now,
  }, {
    key: "test",
    model: "gpt-6.1-sol",
    fetcher: (() => {
      paid++;
      throw Error("unexpected");
    }) as typeof fetch,
  });
  assert.equal(paid, 0);
  assert.deepEqual(a.selections, []);
  assert.equal(a.context.radarScopes?.[0].members, 0);
});
