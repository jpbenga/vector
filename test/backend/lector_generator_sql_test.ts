import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("generator migration isolates accounts, reserves quota once and fences concurrent edits", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
  create schema auth;create table auth.users(id uuid primary key);create function auth.uid() returns uuid language sql as $$select null::uuid$$;
  create table match_feed_analysis_snapshots(id uuid,scope_key text,captured_at timestamptz,as_of timestamptz,window_start date,window_end date,payload jsonb);
  create table sport_feed_publications(run_id uuid,sport text,captured_at timestamptz,payload jsonb);
  insert into auth.users values('11111111-1111-4111-8111-111111111111'),('22222222-2222-4222-8222-222222222222');`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261008120000_lector_generator.sql",
      ),
    );
    const user = "11111111-1111-4111-8111-111111111111",
      other = "22222222-2222-4222-8222-222222222222",
      conversation = "33333333-3333-4333-8333-333333333333",
      turn = "44444444-4444-4444-8444-444444444444";
    const reserve = async (u = user) =>
      (await db.query<{ v: any }>(
        "select lector_generator_reserve($1,$2,$3,0,10,100) v",
        [u, conversation, turn],
      )).rows[0].v;
    assert.equal((await reserve()).status, "reserved");
    assert.equal((await reserve()).status, "pending");
    assert.equal(
      (await db.query<{ calls: number }>(
        "select calls from lector_generator_usage",
      )).rows[0].calls,
      1,
    );
    await assert.rejects(reserve(other), /Unauthorized/);
    await assert.rejects(
      db.query("select lector_generator_commit($1,$2,0,'{}')", [
        other,
        conversation,
      ]),
      /Unauthorized/,
    );
    const commit = (await db.query<{ v: any }>(
      "select lector_generator_commit($1,$2,0,$3,$4,'{}') v",
      [user, conversation, {
        id: conversation,
        tickets: [],
        context: {},
        revision: 0,
      }, turn],
    )).rows[0].v;
    assert.equal(commit.revision, 1);
    assert.equal((await reserve()).cached.revision, 1);
    await assert.rejects(
      db.query("select lector_generator_commit($1,$2,0,'{}')", [
        user,
        conversation,
      ]),
      /changed/,
    );
    await db.exec(
      "update lector_generator_budget set limit_usd=0.03; update lector_generator_turns set started_at=now()-interval '1 minute'",
    );
    await assert.rejects(
      db.query(
        "select lector_generator_reserve($1,$2,'55555555-5555-4555-8555-555555555555',1,10,100)",
        [user, conversation],
      ),
      /test budget limit/,
    );
    assert.equal(
      (await db.query<{ v: string }>(
        "select reserved_usd::text v from lector_generator_budget",
      )).rows[0].v,
      "0.0250",
    );
    await assert.rejects(
      db.query(
        "select lector_generator_reserve($1,'66666666-6666-4666-8666-666666666666',$2,1,10,100)",
        [user, turn],
      ),
      /Unauthorized/,
    );
    await db.exec("set role anon");
    await assert.rejects(
      db.query("select * from lector_generator_conversations"),
      /permission denied/,
    );
    await assert.rejects(
      db.query("select lector_generator_sources(current_date)"),
      /permission denied/,
    );
  } finally {
    await db.close();
  }
});
