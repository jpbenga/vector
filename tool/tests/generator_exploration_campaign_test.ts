import assert from "node:assert/strict";
import {
  domesticCampaignReadiness,
  pilotCoverage,
  pilotResumePlan,
  prepareReadingsCampaign,
  runTwoCallPilot,
  sportingReviewPacket,
} from "../generator_exploration_campaign.ts";
import { defaultExplorationBudget } from "../../supabase/functions/_shared/generator/exploration_budget.ts";
import { buildExplorationReport } from "../../supabase/functions/_shared/generator/exploration.ts";
import { ConversationReader } from "../../supabase/functions/_shared/generator/conversation_tools.ts";
import { type DayEvaluation } from "../../supabase/functions/_shared/generator/match_evaluation.ts";
import { type ModelReceipt } from "../../supabase/functions/_shared/generator/models.ts";
const path = "test/fixtures/generator_published_day.json";
async function fixture() {
  return await prepareReadingsCampaign(await Deno.readFile(path));
}
function grading(body: any, invalid = false) {
  return {
    evaluations: Object.fromEntries(
      JSON.parse(body.input).matches.map((m: any) => {
        const f = m.facts[0];
        return [m.key, {
          fit: f ? 3 : 0,
          status: f ? "supported" : "insufficient",
          candidate: null,
          references: f ? [invalid ? "f999" : f.id] : [],
          vigilanceReferences: [],
          reason: f
            ? "Lecture publiée citée pour la validation contrôlée."
            : "Preuves publiées insuffisantes.",
          limitations: ["Aucune série domestique vérifiée."],
        }];
      }),
    ),
  };
}
function response(value: unknown) {
  return Response.json({
    id: "controlled-receipt",
    model: "gpt-6-luna",
    status: "completed",
    usage: { input_tokens: 120, output_tokens: 180 },
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(value) }],
    }],
  });
}
Deno.test("campaign 1 pins the accepted corpus, keeps all six undocumented matches and excludes inferred domestic series from its criterion", async () => {
  const p = await fixture();
  assert.deepEqual(p.preflight.coverage, {
    manifest: 119,
    documented: 113,
    insufficientEvidence: 6,
    verifiedDomesticSeries: 0,
  });
  assert.equal(p.sheets.filter((s) => !s.facts.length).length, 6);
  assert.match(p.criterion.criteria, /hors critère/);
  assert.equal(
    p.preflight.testProfile.id,
    "validation-published-readings-2026-10-10-v1",
  );
  const changed = new Uint8Array(await Deno.readFile(path));
  changed[changed.length - 1] = 32;
  await assert.rejects(
    () => prepareReadingsCampaign(changed),
    /corpus figé a changé/,
  );
});
Deno.test("two mocked model lots keep a valid partial 119-match archive, honest partition and readable checkpoint, without a third or follow-up call", async () => {
  const prepared = await fixture();
  let calls = 0, checkpoint: DayEvaluation | undefined;
  const receipts: ModelReceipt[] = [];
  const report = await runTwoCallPilot(
    prepared,
    {
      model: "gpt-6-luna",
      key: "controlled-no-network",
      onReceipt: (r) => receipts.push(r),
      fetcher: (async (_u, init) => {
        calls++;
        const body = JSON.parse(String(init?.body));
        assert.equal(body.text.format.name, "lector_match_evaluations");
        assert.match(JSON.parse(body.input).criteria, /hors critère/);
        return response(grading(body));
      }) as typeof fetch,
    },
    defaultExplorationBudget,
    async (r) => {
      checkpoint = structuredClone(r);
    },
  );
  assert.equal(calls, 2);
  assert.equal(receipts.length, 2);
  assert.equal(report.batches, 2);
  assert.equal(report.expected, 119);
  assert.ok(report.evaluated > 0 && report.evaluated <= 24);
  assert.equal(report.complete, false);
  const c = pilotCoverage(report);
  assert.equal(c.supportedOrMixed + c.insufficient + c.notEvaluated, 119);
  assert.deepEqual(checkpoint!.rows, report.rows);
  assert.equal(checkpoint!.snapshot!.sheets.length, 119);
  const restored = JSON.parse(JSON.stringify(checkpoint)) as DayEvaluation;
  assert.equal(restored.evaluated, report.evaluated);
  const resume = pilotResumePlan(restored, prepared);
  assert.equal(resume.canResume, true);
  assert.equal(resume.reused, report.evaluated);
  assert.equal(resume.pending, 119 - report.evaluated);
  assert.equal(resume.paidCalls, 0);
  assert.throws(() =>
    pilotResumePlan({ ...restored, model: "another-model" }, prepared)
  );
  assert.equal(calls, 2);
  const packet = sportingReviewPacket(report);
  assert.equal(packet.readyForTop10AndFiveAlternatives, false);
  assert.equal(packet.rankingScope, "evaluated_subset");
  assert.equal(packet.status, "human-review-pending");
  assert.ok(
    report.failed.every((f) =>
      f.reason.includes("Budget d’évaluation atteint")
    ),
  );
});
Deno.test("a second-lot schema/proof failure is retained and never destroys the first accepted lot or triggers an automatic repair", async () => {
  let calls = 0;
  let checkpoint: DayEvaluation | undefined;
  const report = await runTwoCallPilot(
    await fixture(),
    {
      model: "gpt-6-luna",
      key: "controlled",
      fetcher: (async (_u, init) =>
        response(
          grading(JSON.parse(String(init?.body)), ++calls === 2),
        )) as typeof fetch,
    },
    defaultExplorationBudget,
    async (r) => {
      checkpoint = structuredClone(r);
    },
  );
  assert.equal(calls, 2);
  assert.ok(report.evaluated > 0);
  assert.ok(
    report.failed.some((f) =>
      !f.reason.includes("Budget d’évaluation atteint")
    ),
  );
  assert.deepEqual(checkpoint!.rows, report.rows);
  assert.equal(report.complete, false);
});
Deno.test("complete mechanical grading prepares ten retained and five non-retained frontier alternatives, flags ties and never approves sporting quality", async () => {
  const p = await fixture();
  const partial = await runTwoCallPilot(
    p,
    {
      model: "gpt-6-luna",
      key: "controlled",
      fetcher:
        (async (_u, init) =>
          response(grading(JSON.parse(String(init?.body))))) as typeof fetch,
    },
    defaultExplorationBudget,
    async () => {},
  );
  const complete = structuredClone(partial);
  complete.rows = p.sheets.map((s) => ({
    key: s.key,
    fit: s.facts.length ? 3 : 0,
    status: s.facts.length ? "supported" as const : "insufficient" as const,
    candidateId: null,
    references: s.facts.length ? [s.facts[0].id] : [],
    vigilanceReferences: [],
    reason: "Évaluation mécanique contrôlée.",
    limitations: [],
  }));
  complete.evaluated = 119;
  complete.complete = true;
  complete.failed = [];
  complete.exploration = await buildExplorationReport(
    complete,
    p.sheets,
    p.criterion,
    p.now,
  );
  const packet = sportingReviewPacket(complete);
  assert.equal(packet.readyForTop10AndFiveAlternatives, true);
  assert.equal(packet.retained.length, 10);
  assert.equal(packet.nearBoundaryAlternatives.length, 5);
  assert.ok(packet.nearBoundaryAlternatives.every((a) => a.tiesWithBoundary));
  assert.equal(
    new Set(
      [...packet.retained, ...packet.nearBoundaryAlternatives].map((x) =>
        x.match.key
      ),
    ).size,
    15,
  );
  assert.ok(packet.retained.every((x) => x.review.relevance === null));
  assert.equal(packet.status, "human-review-pending");
});
Deno.test("campaign 2 independently rejects an absent finished status and accepts five explicitly completed results per team with correct season and dates", async () => {
  const now = new Date("2026-10-08T10:00:00Z"),
    league = { id: 61, type: "League", season: 2026 };
  const histories = [2, 3].map((id) => ({
    team: { id },
    league,
    matches: Array.from(
      { length: 5 },
      (_, i) => ({
        fixture: {
          id: id * 100 + i,
          date: `2026-10-0${i + 1}T10:00:00Z`,
          status: { short: "FT" },
        },
        league,
        result: "W",
        goals: { for: 2, against: 1 },
        opponent: { name: "Adversaire contrôlé" },
      }),
    ),
  }));
  const payload = {
    raw: {
      fixtures: [{
        fixture: {
          id: 1,
          date: "2026-10-10T18:00:00Z",
          status: { short: "NS" },
        },
        league: { ...league, name: "Ligue contrôlée" },
        teams: {
          home: { id: 2, name: "Domicile contrôlé" },
          away: { id: 3, name: "Extérieur contrôlé" },
        },
      }],
      recent_league_matches: histories,
    },
    computed: { fixtures: [] },
  };
  const context = {
    view: "all" as const,
    origin: "profile" as const,
    scope: "strict" as const,
    timezone: "Europe/Paris",
    budget: 0,
    preferences: {},
  };
  async function query() {
    return await new ConversationReader({
      context,
      date: "2026-10-10",
      now,
      state: null,
      id: "domestic-test",
      message: "Audit",
    }, {
      sources: async () => [{
        id: "controlled-publication",
        sport: "football",
        capturedAt: now.toISOString(),
        payload,
      }],
    }).query("2026-10-10", ["football"], "all", "teams");
  }
  const ready = domesticCampaignReadiness(await query(), now);
  assert.equal(ready.fullyVerified, 1);
  assert.equal(ready.status, "data-ready-awaiting-authorization");
  const staleQuery = await query();
  staleQuery.sources[0].capturedAt = "2026-10-06T10:00:00Z";
  const stale = domesticCampaignReadiness(staleQuery, now);
  assert.equal(stale.fullyVerified, 0);
  assert.ok(stale.matches[0].sides[0].problems.some((p) => p.includes("24 h")));
  for (const h of histories) {
    for (const m of h.matches) m.fixture.status.short = "";
  }
  const missing = domesticCampaignReadiness(await query(), now);
  assert.equal(missing.fullyVerified, 0);
  assert.equal(missing.status, "awaiting-verified-publications");
  assert.equal(missing.paidCalls, 0);
});
