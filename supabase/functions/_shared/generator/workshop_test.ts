import assert from "node:assert/strict";
import { type Candidate, type Context, type Intent } from "./contracts.ts";
import { compose, compositionKey, totals } from "./engine.ts";
import {
  assessCandidate,
  compareCompositions,
  exploreCompositions,
} from "./workshop.ts";

const now = new Date("2026-10-08T12:00:00Z");
const context: Context = {
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {
    football: {
      competitions: ["61"],
      readings: ["strong_home_team", "positive_streak"],
      markets: ["matchResult", "doubleChance"],
    },
  },
};
const intent: Intent = {
  action: "generate",
  date: "2026-10-10",
  sports: ["football"],
  tickets: [{ stake: 50, minimum: 300, maximum: 330, kind: "total" }],
  diversify: false,
  requireEachSport: false,
  maxSelections: 6,
  ticketIndex: null,
  selectionIndex: null,
  marketIds: [],
  message: "",
};
function pick(id: string, odds: number, family = "venue"): Candidate {
  return {
    id,
    matchId: id,
    sport: "football",
    competitionId: "61",
    competition: "Test",
    home: `Home ${id}`,
    away: `Away ${id}`,
    teams: [`football:${id}-h`, `football:${id}-a`],
    kickoff: "2026-10-10T18:00:00Z",
    marketId: "matchResult",
    market: "Résultat du match",
    selection: `Home ${id} gagne`,
    odds,
    oddsAt: now.toISOString(),
    bookmaker: "Test",
    snapshotId: "published-source",
    discovery: false,
    warnings: [],
    evidence: [{
      id: `${id}:support`,
      label: "Lecture",
      family,
      source: "reading",
      subject: id,
      sample: 5,
      asOf: now.toISOString(),
      text: "Fait publié",
      supportsMarket: true,
    }],
  };
}
Deno.test("workshop compares solutions instead of keeping a needless first 1.04 condition", () => {
  const candidates = [pick("a", 1.04), pick("b", 2), pick("c", 3)];
  const request = {
    ...intent,
    tickets: [{ ...intent.tickets[0], maximum: null }],
  };
  const old = compose(candidates, request, context)[0];
  assert.equal(old.picks.length, 3);
  const result = exploreCompositions(candidates, request, context, { now });
  assert.equal(result.alternatives[0].picks.length, 2);
  assert.equal(result.alternatives[0].returnTotal, 300);
  assert.ok(result.report.feasibleObserved > 1);
  assert.equal(result.alternatives[0].stake, 50);
});
Deno.test("correlated form/venue, supplementary Radar and unrelated markets cannot inflate support", () => {
  const c = pick("a", 2, "form");
  c.evidence.push(
    { ...c.evidence[0], id: "venue", family: "venue" },
    {
      ...c.evidence[0],
      id: "goals",
      family: "production",
      supportsMarket: false,
    },
    { ...c.evidence[0], id: "radar", source: "radar", family: "player" },
    { ...c.evidence[0], id: "scenario", source: "scenario", family: "derived" },
  );
  const assessment = assessCandidate(c, now);
  assert.equal(assessment.dataGroups.length, 1);
  assert.equal(assessment.redundantReferences, 1);
  assert.equal(assessment.contextReferences.length, 3);
  assert.equal(assessment.independence, "unverified");
  assert.equal(assessment.history, "not_available");
});
Deno.test("equivalent compositions account for opposing evidence without treating it as support", () => {
  const opposed = pick("a", 6), other = pick("b", 6);
  opposed.evidence.push({
    ...opposed.evidence[0],
    id: "opponent-support",
    supportsMarket: false,
    role: "vigilance",
    subject: "opponent",
  });
  const result = exploreCompositions(
    [opposed, other],
    { ...intent, maxSelections: 1 },
    context,
    { now },
  );
  assert.equal(result.alternatives[0].picks[0].id, "b");
  assert.equal(assessCandidate(opposed, now).directReferences.length, 1);
  assert.equal(assessCandidate(opposed, now).vigilanceReferences.length, 1);
});
Deno.test("same fixtures can carry different markets; marginal odds never create a new variant", () => {
  const a = pick("a", 2), b = pick("b", 3);
  const differentMarket = {
    ...a,
    id: "a-dc",
    marketId: "doubleChance",
    selection: "Home a ou nul",
    odds: 2.05,
  };
  const comparison = compareCompositions([a, b], [differentMarket, b]);
  assert.equal(comparison.replaced.length, 1);
  assert.equal(comparison.sharedFixtures, 2);
  assert.ok(comparison.significant);
  const refreshed = { ...a, odds: 2.01, snapshotId: "new", id: "new-id" };
  assert.equal(compareCompositions([a, b], [refreshed, b]).significant, false);
  const result = exploreCompositions([a, b, differentMarket], intent, context, {
    now,
    reference: [a, b],
    excludedCompositions: [compositionKey([a, b])],
  });
  assert.equal(result.alternatives.length, 1);
  assert.ok(result.alternatives[0].comparison!.replaced.length);
});
Deno.test("other ticket remembers prior compositions and does not force three proposals", () => {
  const candidates = [pick("a", 2), pick("b", 3)];
  const result = exploreCompositions(candidates, intent, context, { now });
  assert.equal(result.alternatives.length, 1);
  const next = exploreCompositions(
    candidates,
    { ...intent, action: "alternative" },
    context,
    {
      now,
      excludedCompositions: result.alternatives.map((a) => a.fingerprint),
    },
  );
  assert.equal(next.alternatives.length, 0);
  assert.equal(next.status, "none_found_in_bounded_search");
});
Deno.test("same fixtures means all reference fixtures, even with tempting unrelated candidates", () => {
  const reference = Array.from({ length: 6 }, (_, i) => pick(String(i), 1.4));
  const changed = {
    ...reference[0],
    id: "changed",
    marketId: "doubleChance",
    selection: "Home 0 ou nul",
    odds: 1.41,
  };
  const result = exploreCompositions(
    [...reference, changed, pick("unrelated", 6.1)],
    { ...intent, tickets: [{ ...intent.tickets[0], maximum: 400 }] },
    context,
    { now, reference, preserveFixtures: true },
  );
  assert.equal(result.alternatives.length, 1);
  assert.deepEqual(
    result.alternatives[0].picks.map((p) => p.matchId).sort(),
    reference.map((p) => p.matchId).sort(),
  );
  assert.equal(result.alternatives[0].comparison!.replaced.length, 1);
  assert.ok(
    result.report.exclusions.some((e) =>
      e.reasons.includes("outside_preserved_fixtures")
    ),
  );
});
Deno.test("small samples, expired quotes and another day are rejected without filling the target", () => {
  const a = pick("a", 6), b = pick("b", 6), c = pick("c", 6);
  a.evidence[0].sample = 2;
  b.oddsAt = "2026-10-01T12:00:00Z";
  c.kickoff = "2026-10-11T18:00:00Z";
  const result = exploreCompositions([a, b, c], intent, context, { now });
  assert.equal(result.alternatives.length, 0);
  assert.equal(result.report.exclusions.length, 3);
  assert.ok(
    result.report.exclusions.some((e) =>
      e.reasons.includes("outside_requested_day")
    ),
  );
});
Deno.test("budget, one fixture, shared team, bookmaker and required sport remain hard constraints", () => {
  const a = pick("a", 2), b = pick("b", 3);
  for (
    const blocked of [{ ...b, matchId: "a" }, { ...b, teams: a.teams }, {
      ...b,
      bookmaker: "Other",
    }]
  ) {
    assert.equal(
      exploreCompositions([a, blocked], intent, context, { now }).alternatives
        .length,
      0,
    );
  }
  assert.equal(
    exploreCompositions([a, b], intent, { ...context, budget: 49 }, { now })
      .alternatives.length,
    0,
  );
  assert.equal(
    exploreCompositions(
      [a, b],
      { ...intent, sports: ["football", "hockey"], requireEachSport: true },
      context,
      { now },
    ).alternatives.length,
    0,
  );
});
Deno.test("less matches is a changed maximum, not a reason to alter the stake", () => {
  const result = exploreCompositions(
    [pick("a", 2), pick("b", 2), pick("c", 2)],
    { ...intent, maxSelections: 2 },
    context,
    { now },
  );
  assert.equal(result.alternatives.length, 0);
});
Deno.test("targeted substitution can change the same match market while retaining five picks", () => {
  const original = Array.from({ length: 6 }, (_, i) => pick(String(i), 1.4));
  const changed = {
    ...original[0],
    id: "changed",
    marketId: "doubleChance",
    selection: "Home 0 ou nul",
    odds: 1.45,
  };
  const broad = {
    ...intent,
    tickets: [{
      stake: 50,
      minimum: 300,
      maximum: 400,
      kind: "total" as const,
    }],
  };
  const result = exploreCompositions([...original, changed], broad, context, {
    now,
    fixed: original.slice(1),
    reference: original,
  });
  assert.equal(result.alternatives.length, 1);
  assert.equal(result.alternatives[0].comparison!.kept.length, 5);
  assert.equal(result.alternatives[0].comparison!.replaced.length, 1);
  assert.equal(
    result.alternatives[0].returnTotal,
    totals([...original.slice(1), changed], 50).returnTotal,
  );
});
Deno.test("bounded search reports its limits and is invariant to input order", () => {
  const candidates = Array.from(
    { length: 45 },
    (_, i) => pick(String(i).padStart(2, "0"), 1.4 + i % 5 * .1),
  );
  const result = exploreCompositions(candidates, intent, context, {
    now,
    maxExpansions: 1000,
  });
  assert.ok(result.report.exploredStates <= 1000);
  assert.equal(result.report.limited.states, true);
  const one = exploreCompositions(candidates.slice(0, 8), intent, context, {
    now,
  });
  const reverse = exploreCompositions(
    candidates.slice(0, 8).reverse(),
    intent,
    context,
    { now },
  );
  assert.deepEqual(
    one.alternatives.map((a) => a.fingerprint),
    reverse.alternatives.map((a) => a.fingerprint),
  );
  assert.equal(
    new Set(one.alternatives.map((a) => a.fingerprint)).size,
    one.alternatives.length,
  );
});
