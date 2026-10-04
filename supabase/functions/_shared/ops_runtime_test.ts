import { fixtureSample, OpsReporter, stageCall } from "./ops_runtime.ts";
import { strict as assert } from "node:assert";
const id = "11111111-1111-4111-8111-111111111111";
Deno.test("stage dependencies use exact predecessor and date window", () => {
  const task = {
    id,
    stage_token: id,
    league_id: 12,
    day: "2026-09-30",
    started_at: "2026-09-30T02:00:00Z",
    context: {
      sync: { runId: id, summary: { leagueSeasons: { 12: 2026 } } },
      snapshot: { snapshotId: id },
    },
  };
  const collect = stageCall({ ...task, stage: 0 });
  assert.equal(collect.payload.window_end, "2026-10-13");
  assert.equal(collect.payload.include_player_statistics, false);
  assert.equal(
    stageCall({ ...task, stage: 0, job_kind: "enrichment" }).payload
      .include_player_statistics,
    true,
  );
  assert.equal(
    stageCall({ ...task, stage: 2 }).payload.window_end,
    collect.payload.window_end,
  );
  const result = stageCall({ ...task, stage: 1 });
  assert.equal(result.payload.window_start, "2026-09-23");
  assert.equal(result.payload.api_football_sync_run_id, id);
  assert.deepEqual(stageCall({ ...task, stage: 2 }).payload.season_by_league, {
    12: 2026,
  });
  assert.equal(stageCall({ ...task, stage: 3 }).payload.snapshot_id, id);
  assert.throws(
    () => stageCall({ ...task, stage: 1, context: {} }),
    /collecte manquant/,
  );
  assert.throws(
    () => stageCall({ ...task, stage: 3, context: {} }),
    /Snapshot manquant/,
  );
});
Deno.test("sample contains factual match fields only; empty response stays empty", () => {
  assert.deepEqual(fixtureSample({ response: [] }), {});
  const sample = fixtureSample({
    headers: { secret: "private" },
    response: [{
      fixture: {
        id: 42,
        date: "2026-10-01",
        status: { short: "FT" },
        private: "secret",
      },
      league: { name: "Coupe A" },
      teams: { home: { name: "Nord" }, away: { name: "Sud" } },
      goals: { home: 2, away: 1 },
      secret: "private",
    }],
  });
  assert.deepEqual(sample, {
    fixture_id: 42,
    kickoff: "2026-10-01",
    competition: "Coupe A",
    home: "Nord",
    away: "Sud",
    status: "FT",
    goals: { home: 2, away: 1 },
  });
});
Deno.test("reporter is inert for legacy requests and stops on revoked checkpoints", async () => {
  const original = globalThis.fetch;
  let calls = 0;
  globalThis.fetch = () => {
    calls++;
    return Promise.resolve(Response.json(false));
  };
  try {
    await new OpsReporter({}).checkpoint();
    assert.equal(calls, 0);
    await assert.rejects(
      () => new OpsReporter({ ops_task_id: id, ops_token: id }).checkpoint(),
      /Arrêt demandé/,
    );
    assert.equal(calls, 1);
  } finally {
    globalThis.fetch = original;
  }
});
