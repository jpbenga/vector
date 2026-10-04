import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
import expected from "../fixtures/sports/nhl_compact.json" with {
  type: "json",
};
import raw from "../fixtures/sports/nhl_raw.json" with { type: "json" };
import {
  calendarDate,
  shiftDate,
} from "../../supabase/functions/_shared/sports/hockey_feed.ts";

Deno.test("multisport SQL: disabled install, atomic quota, raw lineage, public compact, failed and empty collections", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      "create role anon; create role authenticated; create role service_role bypassrls;",
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261004140000_sport_feed_collection.sql",
      ),
    );
    const claim = async () =>
      (await db.query<{ plan: { run_id?: string; started_at: string } }>(
        "select sport_collection_claim('hockey','57') plan",
      )).rows[0].plan;
    assert.equal(
      (await claim()).run_id,
      undefined,
      "installation sends no external requests",
    );
    await db.exec("update sport_collection_configuration set enabled=true");
    let plan = await claim();
    assert.ok(plan.run_id);
    assert.equal(
      (await claim()).run_id,
      undefined,
      "one active NHL collection",
    );
    const reserve = async () =>
      (await db.query<{ allowed: boolean }>(
        "select reserve_sport_request($1) allowed",
        [plan.run_id],
      )).rows[0].allowed;
    await db.exec("update sport_provider_budgets set minute_limit=1");
    assert.equal(await reserve(), true);
    assert.equal(
      await reserve(),
      false,
      "minute budget is enforced before calls",
    );
    await db.exec(
      "update sport_provider_budgets set minute_limit=280,daily_limit=1",
    );
    assert.equal(
      await reserve(),
      false,
      "daily reservation includes failed calls",
    );
    await db.exec("update sport_provider_budgets set daily_limit=7500");
    const day = calendarDate(new Date(plan.started_at));
    const payload = {
      ...expected,
      collectionId: plan.run_id,
      capturedAt: new Date(plan.started_at).toISOString(),
      windowStart: shiftDate(day, -7),
      windowEnd: shiftDate(day, 13),
      items: expected.items.map((item) => ({
        ...item,
        calendarDate: day,
        startsAt: new Date(plan.started_at).toISOString(),
      })),
    };
    const finish = (value: unknown, error: string | null = null) =>
      db.query<{ ok: boolean }>(
        "select sport_collection_finish($1,$2::jsonb,$3) ok",
        [plan.run_id, value ? JSON.stringify(value) : null, error],
      );
    await assert.rejects(() => finish(payload), /untraceable/);
    const saveRaw = async () => {
      await db.query(
        "insert into sport_raw_responses(run_id,kind,payload) values($1,'leagues',$2::jsonb),($1,'games',$3::jsonb)",
        [plan.run_id, JSON.stringify(raw.leagues), JSON.stringify(raw.games)],
      );
    };
    await saveRaw();
    await assert.rejects(
      () => finish({ ...payload, sport: "football" }),
      /Invalid/,
    );
    assert.equal((await finish(payload)).rows[0].ok, true);
    await db.exec("set role anon");
    assert.deepEqual(
      (await db.query<{ payload: unknown }>(
        "select payload from sport_feed_publications where sport='hockey'",
      )).rows[0].payload,
      payload,
    );
    await assert.rejects(
      () => db.query("select * from sport_raw_responses"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.query("select sport_collection_claim('hockey','57')"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.query("delete from sport_feed_publications"),
      /permission denied/,
    );
    await db.exec("reset role");
    plan = await claim();
    assert.equal((await finish(null, "provider unavailable")).rows[0].ok, true);
    assert.deepEqual(
      (await db.query<{ payload: unknown }>(
        "select payload from sport_feed_publications",
      )).rows[0].payload,
      payload,
      "failed collection preserves last public snapshot",
    );
    plan = await claim();
    await db.exec(
      "update sport_collection_configuration set lease_until=now()-interval '1 second'",
    );
    assert.equal(await reserve(), false);
    assert.equal(
      (await finish(payload)).rows[0].ok,
      false,
      "expired worker cannot publish",
    );
    plan = await claim();
    await saveRaw();
    const emptyDay = calendarDate(new Date(plan.started_at));
    const empty = {
      ...payload,
      collectionId: plan.run_id,
      capturedAt: new Date(plan.started_at).toISOString(),
      windowStart: shiftDate(emptyDay, -7),
      windowEnd: shiftDate(emptyDay, 13),
      items: [],
    };
    assert.equal(
      (await finish(empty)).rows[0].ok,
      true,
      "empty calendar is a valid successful publication",
    );
    await db.exec("set role authenticated");
    assert.deepEqual(
      (await db.query<{ payload: unknown }>(
        "select payload from sport_feed_publications",
      )).rows[0].payload,
      empty,
    );
  } finally {
    await db.close();
  }
});
