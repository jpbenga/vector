import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("delivery SQL fences stale workers and exposes only public pointers", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
 create schema cron;create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
 create schema storage;create table storage.buckets(id text primary key,name text,public boolean,file_size_limit bigint,allowed_mime_types text[]);
 create table ops_configuration(singleton boolean,base_url text,sync_secret text);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261007213000_feed_delivery.sql",
      ),
    );
    const one = async (sql: string) =>
      (await db.query<{ v: any }>(sql)).rows[0]?.v;
    const register = async (id: string) =>
      db.query(
        `select feed_delivery_register('football',$1,'league:61',now(),now(),current_date,current_date+13,$2,'{}')`,
        [id, `delivery/football/${id}/full.json`],
      );
    assert.deepEqual(await one("select feed_delivery_claim('football') v"), {});
    await register("first");
    await register("first");
    assert.equal(
      await one(
        "select revision v from sport_feed_delivery_jobs where sport='football'",
      ),
      1,
    );
    await db.exec(
      "update sport_feed_delivery_jobs set enabled=true where sport='football'",
    );
    const claim = await one("select feed_delivery_claim('football') v");
    await register("second");
    assert.equal(
      (await db.query<{ v: boolean }>(
        "select feed_delivery_finish('football',$1,$2,'[]') v",
        [claim.token, claim.revision],
      )).rows[0].v,
      false,
    );
    assert.equal(
      await one("select count(*)::int v from sport_feed_delivery_heads"),
      0,
    );
    const next = await one("select feed_delivery_claim('football') v");
    const manifest = {
      schemaVersion: 1,
      sport: "football",
      day: "2026-10-07",
      path: "delivery/football/version/2026-10-07.json",
    };
    assert.equal(
      (await db.query<{ v: boolean }>(
        "select feed_delivery_finish('football',$1,$2,$3) v",
        [next.token, next.revision, JSON.stringify([manifest])],
      )).rows[0].v,
      true,
    );
    await register("third");
    const failed = await one("select feed_delivery_claim('football') v");
    await db.query(
      "select feed_delivery_finish('football',$1,$2,'[]','upload failed')",
      [failed.token, failed.revision],
    );
    assert.equal(
      await one("select count(*)::int v from sport_feed_delivery_heads"),
      1,
    );
    await db.exec("set role anon");
    assert.equal(
      await one("select count(*)::int v from sport_feed_delivery_heads"),
      1,
    );
    await assert.rejects(
      () => db.exec("select * from sport_feed_delivery_parts"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("delete from sport_feed_delivery_heads"),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("select feed_delivery_claim('football')"),
      /permission denied/,
    );
  } finally {
    await db.close();
  }
});
