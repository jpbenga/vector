import assert from "node:assert/strict";
type Obj = Record<string, any>;
type Handler = (r: Request) => Promise<Response>;
Deno.test("actual queue and daily handlers checkpoint collection/results/snapshot/analysis; never publish incomplete batches", async () => {
  const originalFetch = globalThis.fetch, originalServe = Deno.serve;
  const keys = [
    "SUPABASE_URL",
    "SUPABASE_SERVICE_ROLE_KEY",
    "API_FOOTBALL_SYNC_SECRET",
  ];
  const saved = keys.map((k) => Deno.env.get(k));
  let handler: Handler;
  let job: Obj = {
    id: "job",
    payload: { league_ids: [2], api_request_delay_ms: 0 },
    status: "queued",
    attempts: 0,
  };
  let inserts = 0, collects = 0, results = 0, snapshots = 0, analyses = 0;
  const changes: Obj[] = [];
  const json = (body: unknown) => new Response(JSON.stringify(body));
  try {
    keys.forEach((k) =>
      Deno.env.set(
        k,
        k === "SUPABASE_URL" ? "https://european-test.invalid" : "local-only",
      )
    );
    Deno.serve = ((h: Handler) => {
      handler = h;
      return {};
    }) as typeof Deno.serve;
    await import("../daily-football-sync/index.ts");
    Deno.serve = originalServe;
    globalThis.fetch =
      (async (input: RequestInfo | URL, init?: RequestInit) => {
        const url = new URL(String(input)),
          body = init?.body ? JSON.parse(String(init.body)) : {};
        assert.equal(
          url.hostname,
          "european-test.invalid",
          "test must never contact production",
        );
        if (
          url.pathname.endsWith("/rpc/claim_next_api_football_sync_queue_job")
        ) {
          if (job.status === "succeeded") return json([]);
          job.status = "running";
          job.attempts++;
          return json([job]);
        }
        if (url.pathname.endsWith("/functions/v1/daily-football-sync")) {
          return await handler(new Request(url, init));
        }
        if (url.pathname.endsWith("/functions/v1/api-football-sync")) {
          assert.equal(body.bounded_european, true);
          collects++;
          return json({
            ok: true,
            runId: "collect-run",
            summary: { leagueSeasons: { 2: 2030 }, providerRequests: 7 },
            ...(collects === 1
              ? {
                continue: true,
                batch_cursor: {
                  version: 1,
                  run_id: "collect-run",
                  tasks: [],
                  offset: 0,
                  season: 2030,
                },
              }
              : {}),
          });
        }
        if (url.pathname.endsWith("/functions/v1/sync-match-results")) {
          results++;
          assert.equal(collects, 2);
          return json({ ok: true, summary: { providerRequests: 1 } });
        }
        if (url.pathname.endsWith("/functions/v1/build-match-feed-snapshot")) {
          snapshots++;
          assert.equal(results, 1);
          return json({ ok: true, snapshotId: "snapshot" });
        }
        if (
          url.pathname.endsWith("/functions/v1/analyze-match-feed-snapshot")
        ) {
          analyses++;
          assert.equal(snapshots, 1);
          return json({ ok: true });
        }
        if (url.pathname.endsWith("/rpc/current_database_size_bytes")) {
          return json(1000);
        }
        if (url.pathname === "/rest/v1/daily_football_sync_runs") {
          if (init?.method === "POST") {
            inserts++;
            return json([{ id: "daily-run" }]);
          }
          if (init?.method === "GET") {
            return json([{
              id: "daily-run",
              status: "running",
              league_ids: [2],
            }]);
          }
          return json([]);
        }
        if (
          url.pathname === "/rest/v1/api_football_sync_queue_jobs" &&
          init?.method === "PATCH"
        ) {
          changes.push(body);
          job = { ...job, ...body };
          return json([]);
        }
        throw Error("Unexpected local integration request " + url.pathname);
      }) as typeof fetch;
    const invoke = () =>
      handler(
        new Request(
          "https://european-test.invalid/functions/v1/daily-football-sync",
          {
            method: "POST",
            headers: {
              authorization: "Bearer local-only",
              "content-type": "application/json",
            },
            body: JSON.stringify({ process_queue: true }),
          },
        ),
      );
    for (let i = 0; i < 4; i++) {
      const res = await invoke();
      assert.equal(res.status, 200);
      assert.equal(job.status, "retrying");
      assert.equal(job.attempts, 0);
      assert.equal(analyses, 0);
      assert.equal(job.payload.daily_run_id, "daily-run");
    }
    await invoke();
    assert.equal(job.status, "succeeded");
    assert.equal(inserts, 1);
    assert.equal(collects, 2);
    assert.equal(results, 1);
    assert.equal(snapshots, 1);
    assert.equal(analyses, 1);
    assert.ok(
      changes.slice(0, 4).every((c) =>
        c.payload && c.lease_expires_at === null && c.attempts === 0
      ),
    );
  } finally {
    globalThis.fetch = originalFetch;
    Deno.serve = originalServe;
    keys.forEach((k, i) =>
      saved[i] === undefined ? Deno.env.delete(k) : Deno.env.set(k, saved[i]!)
    );
  }
});
