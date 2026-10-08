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
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261008170000_lector_generator_conversation_controls.sql",
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
        drafts: [{ id: "77777777-7777-4777-8777-777777777777", number: 1 }],
        context: {},
        revision: 0,
      }, turn],
    )).rows[0].v;
    assert.equal(commit.revision, 1);
    assert.equal((await reserve()).cached.revision, 1);
    const archived = (await db.query<{ user_id: string; ticket: any }>(
      "select user_id,ticket from lector_generator_ticket_drafts",
    )).rows[0];
    assert.equal(archived.user_id, user);
    assert.equal(archived.ticket.number, 1);
    const early = "88888888-8888-4888-8888-888888888888";
    const cancel = (u = user, request = early) =>
      db.query<{ v: any }>("select lector_generator_cancel($1,$2,$3) v", [
        u,
        conversation,
        request,
      ]);
    assert.equal((await cancel(user, turn)).rows[0].v.status, "complete");
    assert.equal((await cancel()).rows[0].v.cancelled, true);
    await assert.rejects(cancel(other), /Unauthorized/);
    assert.equal(
      (await db.query<{ v: any }>(
        "select lector_generator_reserve($1,$2,$3,1,10,100) v",
        [user, conversation, early],
      )).rows[0].v.status,
      "failed",
    );
    await assert.rejects(
      db.query("select lector_generator_commit($1,$2,1,'{}',$3,'{}')", [
        user,
        conversation,
        early,
      ]),
      /Invalid reservation/,
    );
    await assert.rejects(
      db.query(
        "select lector_generator_finish_transcription($1,$2,$3,'dictée','{}')",
        [user, conversation, early],
      ),
      /Invalid reservation/,
    );

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
    await db.exec(`insert into match_feed_analysis_snapshots values(
      gen_random_uuid(),'league:61',now(),now(),current_date,current_date,
      jsonb_build_object('raw',jsonb_build_object('fixtures',jsonb_build_array(
        jsonb_build_object('fixture',jsonb_build_object('id',123,'date',(current_date+interval '12 hours') at time zone 'UTC'))
      )),'computed',jsonb_build_object('fixtures','[]'::jsonb)))`);
    const source = async () =>
      (await db.query<{ v: any }>(
        "select lector_generator_sources(current_date,'UTC') v",
      )).rows[0].v;
    const before = await source();
    assert.equal(before.length, 1);
    assert.equal(before[0].sport, "football");
    assert.equal(before[0].payload.raw.fixtures[0].fixture.id, 123);
    await db.exec("drop table sport_feed_publications");
    assert.deepEqual(await source(), before);
    await db.exec("set role anon");
    await assert.rejects(
      db.query("select * from lector_generator_ticket_drafts"),
      /permission denied/,
    );
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
Deno.test("compact generator sources keep day evidence and actual prices without unrelated profiles", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
      create table match_feed_analysis_snapshots(id uuid,source_snapshot_id uuid,scope_key text,league_ids integer[],captured_at timestamptz,as_of timestamptz,window_start date,window_end date,payload jsonb);
      create table match_feed_snapshot_fixtures(snapshot_id uuid,kickoff_at timestamptz);
      create table sport_feed_publications(run_id uuid,sport text,captured_at timestamptz,window_start date,window_end date,payload jsonb);
      create function lector_generator_sources(date,text default 'Europe/Paris') returns jsonb language sql as $$select '[]'::jsonb$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261008143000_lector_generator_compact_sources.sql",
      ),
    );
    const fixture = (id: number, day = 0) => ({
      fixture: {
        id,
        date: new Date(Date.now() + day * 86400000).toISOString(),
        status: { short: "NS" },
      },
      league: { id: 61 },
      teams: { home: { id: 1, name: "A" }, away: { id: 2, name: "B" } },
    });
    const quote = {
      fixture: { id: 123 },
      update: new Date().toISOString(),
      bookmakers: [{
        id: 8,
        name: "Bookmaker",
        bets: [{ id: 1, values: [{ value: "Home", odd: "2.00" }] }, {
          id: 99,
          values: [{ value: "fake", odd: "1.23" }],
        }],
      }],
    };
    const reading = {
      fixture_id: 123,
      readings: [{ id: "strong_home_team", sample_size: 3 }],
      scenarios: [{
        id: "ranking_gap",
        required_reading_ids: ["strong_home_team"],
      }],
      large_unused: "unused",
    };
    const payload = {
      raw: {
        fixtures: [fixture(123), fixture(124, 1)],
        odds: [quote, { ...quote, fixture: { id: 124 } }],
        player_form_radar: [{
          team: { id: 1 },
          player: { id: 7, name: "Player" },
          activity: [{
            played_at: new Date().toISOString(),
            goals: 1,
            assists: 0,
            unnecessary: "ignored",
          }],
        }, { team: { id: 999 }, player: { id: 9 }, activity: [] }],
      },
      computed: { fixtures: [reading, { fixture_id: 124 }] },
    };
    const id = "11111111-1111-4111-8111-111111111111";
    await db.query(
      "insert into match_feed_analysis_snapshots values($1,$1,'league:61',array[61],now(),now(),current_date,current_date+13,$2)",
      [id, payload],
    );
    await db.query(
      "insert into match_feed_snapshot_fixtures values($1,now())",
      [id],
    );
    const get = async (
      sports = ["football"],
      leagues: string[] | null = null,
    ) =>
      (await db.query<{ v: any }>(
        "select lector_generator_sources_filtered(current_date,'UTC',$1::text[],$2::text[]) v",
        [sports, leagues],
      )).rows[0].v;
    const sources = await get();
    assert.equal(sources.length, 1);
    const p = sources[0].payload;
    assert.equal(p.raw.fixtures.length, 1);
    assert.equal(p.raw.fixtures[0].fixture.id, 123);
    assert.equal(p.raw.odds[0].update, quote.update);
    assert.deepEqual(p.raw.odds[0].bookmakers[0].bets, [
      quote.bookmakers[0].bets[0],
    ]);
    assert.equal(p.raw.player_form_radar.length, 1);
    assert.equal(p.raw.player_form_radar[0].activity[0].goals, 1);
    assert.equal(p.raw.player_form_radar[0].activity[0].unnecessary, undefined);
    assert.deepEqual(p.computed.fixtures[0].readings, reading.readings);
    assert.deepEqual(p.computed.fixtures[0].scenarios, reading.scenarios);
    assert.equal(p.computed.fixtures[0].large_unused, undefined);
    assert.deepEqual(await get(["football"], ["62"]), []);
    assert.deepEqual(await get(["hockey"]), []);
    assert.deepEqual(await get([], null), []);
    const personalized = async (readings: string[], scenarios: string[] = []) =>
      (await db.query<{ v: any }>(
        "select lector_generator_sources_filtered(current_date,'UTC',array['football'],null,$1::text[],$2::text[]) v",
        [readings, scenarios],
      )).rows[0].v;
    assert.deepEqual(await personalized(["strong_home_team"]), sources);
    assert.deepEqual(await personalized(["unconfigured_reading"]), []);
    assert.deepEqual(await personalized([], ["ranking_gap"]), sources);
    await db.exec("drop table sport_feed_publications");
    assert.deepEqual(await get(), sources);
    await db.exec("set role anon");
    await assert.rejects(get(), /permission denied/);
  } finally {
    await db.close();
  }
});
