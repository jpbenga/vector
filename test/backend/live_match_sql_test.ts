import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
import {
  finalResult,
  liveState,
} from "../../supabase/functions/_shared/live_matches.ts";

const fixture = (id: number, status: string, home = 1, away = 3) => ({
  fixture: {
    id,
    date: new Date(Date.now() - 2 * 3600000).toISOString(),
    status: { short: status, elapsed: 67 },
  },
  league: { id: 140 },
  teams: { home: { id: 1, name: "Club A" }, away: { id: 2, name: "Club B" } },
  goals: { home, away },
  score: { halftime: { home: 0, away: 1 }, fulltime: { home, away } },
});

Deno.test("live SQL: lease, public scores, immutable final evaluations, corrections, no-data and shared permissions", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role;
      create schema cron;
      create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
      create table ops_competitions(league_id integer primary key,enabled boolean);
      create table ops_configuration(singleton boolean,base_url text,sync_secret text);
      insert into ops_competitions values(140,true),(61,false);
      insert into ops_configuration values(true,'https://example.supabase.co','example-secret');
      create table match_feed_snapshot_fixtures(
        snapshot_id uuid,fixture_id text,api_football_fixture_id integer,api_football_league_id integer,
        fixture_date date,kickoff_at timestamptz,created_at timestamptz default now(),
        home_team_name text,away_team_name text,competition_name text,country_name text,
        primary key(snapshot_id,fixture_id));
      create table match_reading_announcements(
        id uuid primary key default gen_random_uuid(),announcement_key text,fixture_id integer,league_id integer,
        source_snapshot_id uuid,kickoff_at timestamptz,announced_at timestamptz,reading_id text,reading_label text,
        subject_side text,subject_team_id text,player_id integer,evidence jsonb default '[]',sample_size integer,
        outcome_rule text,rule_version integer default 1,announcement_kind text,parent_announcement_key text,
        required_reading_ids text[] default '{}');
      create table match_result_snapshots(
        id uuid primary key default gen_random_uuid(),fixture_id integer,league_id integer,fixture_date date,kickoff_at timestamptz,
        status text check(status in('FT','AET','PEN')),home_team_id integer,away_team_id integer,
        home_team_name text,away_team_name text,home_goals integer,away_goals integer,halftime_home_goals integer,
        halftime_away_goals integer,score jsonb,source_payload jsonb,content_hash text,captured_at timestamptz default now(),
        created_at timestamptz default now(),unique(fixture_id,content_hash));
      create table match_reading_evaluations(
        id uuid primary key default gen_random_uuid(),announcement_id uuid,result_snapshot_id uuid,rule_version integer,
        verdict text,observed_value jsonb,explanation text,evaluated_at timestamptz default now(),unique(announcement_id,result_snapshot_id,rule_version));
    `);
    const previous = await Deno.readTextFile(
      "supabase/migrations/20260918113000_bilan_reading_outcomes_and_nuances.sql",
    );
    await db.exec(
      previous.slice(
        previous.indexOf(
          "create or replace function public.match_reading_verdict(",
        ),
        previous.indexOf("create or replace view public.match_reading_bilan"),
      ),
    );
    await db.exec(
      `create trigger evaluate_match_result_snapshot_after_insert after insert on match_result_snapshots for each row execute function evaluate_match_result_snapshot();
      create trigger evaluate_late_reading_announcement_after_insert after insert on match_reading_announcements for each row execute function evaluate_late_reading_announcement();`,
    );
    const view = await Deno.readTextFile(
      "supabase/migrations/20261003180000_reading_bilan_exploration.sql",
    );
    await db.exec(
      view.slice(
        view.indexOf("create or replace view"),
        view.indexOf("create or replace function"),
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261004100000_live_match_collection.sql",
      ),
    );
    await db.exec(
      `grant select on match_result_snapshots,match_reading_bilan to anon,authenticated;
      insert into match_feed_snapshot_fixtures(snapshot_id,fixture_id,api_football_fixture_id,api_football_league_id,fixture_date,kickoff_at,home_team_name,away_team_name,competition_name,country_name)
      select '00000000-0000-0000-0000-000000000001','api-fixture-'||id,id,140,current_date,now()-interval '2 hours','Club A','Club B','LaLiga','Espagne' from generate_series(1,21) id;
      insert into match_reading_announcements(announcement_key,fixture_id,league_id,source_snapshot_id,kickoff_at,announced_at,reading_id,reading_label,subject_side,outcome_rule,announcement_kind)
      select reading,1,140,'00000000-0000-0000-0000-000000000001',now()-interval '2 hours',now()-interval '3 hours',reading,reading,'away',rule,'reading'
      from (values('positive_streak','team_not_lose'),('both_teams_score','btts'),('under_25','under_25'),('context',null),('standout_decisive_player','player_decisive')) as rules(reading,rule);
      update match_reading_announcements set player_id=7 where reading_id='standout_decisive_player';
    `,
    );
    const rawClaim = async () =>
      (await db.query<{ plan: { token?: string; fixture_ids: number[] } }>(
        "select match_live_claim() plan",
      )).rows[0].plan;
    const claim = async () => {
      // Move to the next scheduler minute after a completed run.
      await db.exec(
        "update match_live_configuration set last_started_at=now()-interval '1 minute' where stage_token is null",
      );
      return rawClaim();
    };
    assert.equal((await claim()).token, undefined, "migration starts disabled");
    await db.exec("select match_live_set_enabled(true)");
    let plan = await claim();
    assert.equal(plan.fixture_ids.length, 20);
    assert.equal(
      (await claim()).token,
      undefined,
      "a second collector cannot overlap",
    );
    const publish = async (
      states: unknown[],
      results: unknown[] = [],
      checked: number[] = [1],
    ) =>
      db.query(
        "select match_live_publish($1,$2::jsonb,$3::jsonb,$4::int[],2,false)",
        [plan.token, JSON.stringify(states), JSON.stringify(results), checked],
      );
    await db.exec(await Deno.readTextFile('supabase/migrations/20261004230000_premium_live_statistics.sql'));
    const now = new Date().toISOString();
    const stats = [{team: {id: 1}, statistics: [{type: 'Total Shots', value: 0}]}];
    await publish([liveState({...fixture(1, "2H", 1, 2), statistics: stats}, now)]);
    await db.exec("set role anon");
    let rows = (await db.query<{ states: Record<string, unknown>[] }>(
      "select match_live_for_fixtures(array[1,2]) states",
    )).rows[0].states;
    assert.deepEqual(rows.find((r) => r.fixture_id === 1)?.statistics, stats, 'anon reads exact current statistics');
    assert.ok(rows.find((r) => r.fixture_id === 1)?.statistics_captured_at);
    assert.equal(rows.find((r) => r.fixture_id === 1)?.home_goals, 1);
    assert.equal(rows.find((r) => r.fixture_id === 1)?.away_goals, 2);
    assert.equal(
      rows.find((r) => r.fixture_id === 2)?.home_goals,
      null,
      "upcoming fixtures never become fake 0-0 scores",
    );
    await assert.rejects(
      () => db.query("select match_live_set_enabled(false)"),
      /permission denied/,
    );
    await db.exec("reset role");
    assert.equal(
      (await rawClaim()).token,
      undefined,
      "a completed tick cannot spend quota twice in one minute",
    );
    plan = await claim();
    assert.ok(
      plan.fixture_ids.includes(21),
      "the backlog advances beyond the first group of 20",
    );
    // Empty live feed does not overwrite the last known score or prove FT.
    await publish([], [], [2]);
    assert.equal(
      (await db.query<{ status: string }>(
        "select status from match_live_states where fixture_id=1",
      )).rows[0].status,
      "2H",
    );
    plan = await claim();
    const final = fixture(1, "FT");
    const result = await finalResult(
      final,
      new Date(Date.now() + 1000).toISOString(),
    );
    await publish([liveState(final, String(result?.captured_at))], [result]);
    assert.deepEqual((await db.query<{statistics: unknown}>('select statistics from match_live_states where fixture_id=1')).rows[0].statistics, stats,
      'a score-only update does not erase statistics or invent new values');
    const verdicts = async () =>
      (await db.query<{ reading_id: string; verdict: string }>(
        "select reading_id,verdict from match_reading_bilan where fixture_id=1 order by reading_id",
      )).rows;
    assert.deepEqual(await verdicts(), [
      { reading_id: "both_teams_score", verdict: "confirmed" },
      { reading_id: "context", verdict: "context_only" },
      { reading_id: "positive_streak", verdict: "confirmed" },
      { reading_id: "standout_decisive_player", verdict: "not_evaluable" },
      { reading_id: "under_25", verdict: "contradicted" },
    ]);
    const count = async () =>
      Number(
        (await db.query<{ n: number }>(
          "select count(*)::int n from match_result_snapshots",
        )).rows[0].n,
      );
    assert.equal(await count(), 1);
    plan = await claim();
    await publish([], [result]);
    assert.equal(
      await count(),
      1,
      "identical final response remains idempotent",
    );
    plan = await claim();
    const correction = await finalResult(
      fixture(1, "FT", 1, 0),
      new Date(Date.now() + 2000).toISOString(),
    );
    await publish([], [correction]);
    assert.equal(await count(), 2);
    assert.equal(
      (await verdicts()).find((v) => v.reading_id === "positive_streak")
        ?.verdict,
      "contradicted",
    );
    plan = await claim();
    await publish([], [
      await finalResult(final, new Date(Date.now() + 3000).toISOString()),
    ]);
    assert.equal(
      await count(),
      3,
      "a reverted correction is a new immutable audit record",
    );
    assert.equal(
      (await verdicts()).find((v) => v.reading_id === "positive_streak")
        ?.verdict,
      "confirmed",
    );
    plan = await claim();
    const expiredToken = plan.token;
    await db.exec(
      "update match_live_configuration set lease_until=now()-interval '1 second',last_started_at=now()-interval '2 minutes'",
    );
    plan = await claim();
    assert.notEqual(plan.token, expiredToken);
    assert.equal(
      (await db.query<{ status: string }>(
        "select status from match_live_runs where id=$1",
        [expiredToken],
      )).rows[0].status,
      "failed",
    );
    await assert.rejects(
      () =>
        db.query("select match_live_publish($1,'[]','[]','{}',0,false)", [
          expiredToken,
        ]),
      /lease revoked/,
    );
    await db.exec("select match_live_set_enabled(false)");
    await assert.rejects(() => publish([], []), /lease revoked/);
    // Results persist independently of the live cache and remain publicly readable.
    await db.exec(
      "delete from match_live_states where fixture_id=1; set role anon",
    );
    rows = (await db.query<{ states: Record<string, unknown>[] }>(
      "select match_live_for_fixtures(array[1]) states",
    )).rows[0].states;
    assert.equal(rows[0].away_goals, 3);
    assert.equal((rows[0].readings as unknown[]).length, 5);
  } finally {
    await db.close();
  }
});
