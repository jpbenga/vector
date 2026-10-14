import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("freshness alert and retry are opt-in, deduplicated, private; calendar survives; quotes cannot refresh old analytics", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
 create table match_feed_analysis_snapshots(id uuid primary key,league_ids integer[],window_start date,window_end date,captured_at timestamptz,as_of timestamptz,created_at timestamptz default now(),payload jsonb);
 create table api_football_sync_queue_jobs(id uuid default gen_random_uuid(),dedupe_key text unique,payload jsonb,priority integer,status text default 'queued',cancel_requested_at timestamptz);
 create table ops_events(actor text,kind text,message text);
 create schema cron;create table cron.job(jobid bigint generated always as identity,jobname text,active boolean default true);
 create function cron.schedule(text,text,text) returns bigint language sql as $$insert into cron.job(jobname) values($1) returning jobid$$;
 create function cron.alter_job(job_id bigint,active boolean) returns void language sql as $$update cron.job set active=$2 where jobid=$1$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261014220000_european_publication_freshness.sql",
      ),
    );
    const now = "2030-10-14T17:20:00Z";
    for (const league of [2, 3, 848]) {
      const payload = {
        quoteRevision: { analysisAsOf: "2030-10-12T23:55:00Z" },
        raw: {
          fixtures: [{
            fixture: {
              id: league,
              date: "2030-10-14T19:00:00Z",
              status: { short: "NS" },
            },
          }],
          odds: [{
            fixture: { id: league },
            update: "2030-10-14T16:00:00Z",
            bookmakers: [{ id: 8 }],
          }],
        },
      };
      await db.query(
        "insert into match_feed_analysis_snapshots values($1,$2,$3,$4,$5,$5,$5,$6)",
        [
          `00000000-0000-0000-0000-000000000${
            league === 848 ? "848" : String(league).padStart(3, "0")
          }`,
          [league],
          "2030-10-14",
          "2030-10-27",
          "2030-10-14T17:00:00Z",
          payload,
        ],
      );
    }
    const health =
      (await db.query<any>("select * from european_publication_health($1)", [
        now,
      ])).rows;
    assert.equal(health.length, 3);
    assert.ok(
      health.every((h) =>
        h.needs_refresh && h.analytically_stale && h.missing_or_old_quotes === 0
      ),
    );
    assert.equal(
      (await db.query<any>("select european_publication_tick($1) n", [now]))
        .rows[0].n,
      0,
    );
    assert.equal(
      (await db.query<any>("select active from cron.job")).rows[0].active,
      false,
    );
    await db.exec("update european_refresh_control set enabled=true");
    assert.equal(
      (await db.query<any>("select european_publication_tick($1) n", [now]))
        .rows[0].n,
      3,
    );
    assert.equal(
      (await db.query<any>("select european_publication_tick($1) n", [now]))
        .rows[0].n,
      0,
    );
    assert.equal(
      (await db.query<any>("select count(*)::int n from ops_events")).rows[0].n,
      3,
    );
    assert.equal(
      (await db.query<any>(
        "select count(*)::int n from match_feed_analysis_snapshots",
      )).rows[0].n,
      3,
      "immutable calendar unchanged",
    );
    assert.equal(
      (await db.query<any>(
        "select has_function_privilege('authenticated','european_publication_health(timestamptz)','execute') ok",
      )).rows[0].ok,
      false,
    );
    await db.exec("update api_football_sync_queue_jobs set status='failed'");
    assert.equal(
      (await db.query<any>("select european_publication_tick($1) n", [
        "2030-10-14T18:20:00Z",
      ])).rows[0].n,
      3,
      "terminal daily failure gets a later pre-match retry",
    );
    // New source legitimately recomputed, old immutable source retained.
    await db.query(
      "insert into match_feed_analysis_snapshots values('00000000-0000-0000-0000-000000999002',array[2],'2030-10-14','2030-10-27',$1,$1,$1,$2)",
      ["2030-10-14T18:00:00Z", {
        raw: {
          fixtures: [{
            fixture: {
              id: 2,
              date: "2030-10-14T19:00:00Z",
              status: { short: "NS" },
            },
          }],
          odds: [{
            fixture: { id: 2 },
            update: "2030-10-14T18:00:00Z",
            bookmakers: [{}],
          }],
        },
      }],
    );
    const fresh = (await db.query<any>(
      "select * from european_publication_health($1) where league_id=2",
      ["2030-10-14T18:20:00Z"],
    )).rows[0];
    assert.equal(fresh.needs_refresh, false);
  } finally {
    await db.close();
  }
});
