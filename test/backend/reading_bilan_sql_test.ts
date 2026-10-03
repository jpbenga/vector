import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";

Deno.test("Bilan SQL preserves pending fixture identity, latest results and league/venue counts", async () => {
  const db = new PGlite();
  try {
    await db.exec(`
      create role anon; create role authenticated; create role service_role;
      create table match_reading_announcements (
        id uuid primary key, fixture_id integer, league_id integer,
        source_snapshot_id uuid, kickoff_at timestamptz, announced_at timestamptz,
        reading_id text, reading_label text, subject_side text, subject_team_id text,
        player_id integer, evidence jsonb, sample_size integer, outcome_rule text,
        announcement_kind text, required_reading_ids text[], parent_announcement_key text
      );
      create table match_feed_snapshot_fixtures (
        snapshot_id uuid, fixture_id text, home_team_name text, away_team_name text,
        competition_name text, country_name text, primary key (snapshot_id,fixture_id)
      );
      create table match_result_snapshots (
        id uuid primary key, fixture_id integer, home_team_name text, away_team_name text,
        home_goals integer, away_goals integer, status text,
        captured_at timestamptz, created_at timestamptz
      );
      create table match_reading_evaluations (
        id uuid primary key, announcement_id uuid, result_snapshot_id uuid,
        verdict text, observed_value jsonb, explanation text, evaluated_at timestamptz
      );
    `);
    // Replace the real previous view, including its existing public grant.
    const previous = await Deno.readTextFile(
      "supabase/migrations/20260918113000_bilan_reading_outcomes_and_nuances.sql",
    );
    const oldView = previous.slice(
      previous.indexOf("create or replace view public.match_reading_bilan"),
      previous.indexOf(
        "drop function if exists public.match_reading_bilan_summary",
      ),
    );
    await db.exec(oldView);
    await db.exec("grant select on match_reading_bilan to anon,authenticated;");
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261003180000_reading_bilan_exploration.sql",
      ),
    );
    await db.exec(`
      insert into match_feed_snapshot_fixtures
      select '00000000-0000-0000-0000-000000000001'::uuid,
        'api-fixture-' || id, 'Club ' || id, 'Opponent ' || id,
        case when id in (2,3) then 'Premier League' else 'Ligue 1' end, 'Country'
      from generate_series(1,7) id;
      insert into match_reading_announcements
      select ('00000000-0000-0000-0000-' || lpad(id::text,12,'0'))::uuid,
        id, case when id in (2,3) then 39 else 61 end,
        '00000000-0000-0000-0000-000000000001'::uuid,
        '2026-10-02 20:00+00', '2026-10-02 10:00+00',
        case when id=4 then 'ranking_superiority' else 'positive_streak' end,
        case when id=4 then 'Supériorité au classement' else 'Dynamique positive' end,
        case when id=3 then 'away' else 'home' end, 'team', null,
        '[]'::jsonb, 5, case when id=4 then null else 'team_not_lose' end,
        case when id=6 then 'scenario' when id=7 then 'nuance' else 'reading' end,
        '{}'::text[], null
      from generate_series(1,7) id;
      insert into match_result_snapshots
      select ('10000000-0000-0000-0000-' || lpad(id::text,12,'0'))::uuid,
        id, 'Club ' || id, 'Opponent ' || id, 1, 0,
        case when id=5 then 'AET' else 'FT' end,
        '2026-10-02 22:00+00', '2026-10-02 22:00+00'
      from generate_series(2,7) id;
      insert into match_reading_evaluations
      select ('20000000-0000-0000-0000-' || lpad(id::text,12,'0'))::uuid,
        ('00000000-0000-0000-0000-' || lpad(id::text,12,'0'))::uuid,
        ('10000000-0000-0000-0000-' || lpad(id::text,12,'0'))::uuid,
        case when id=3 then 'contradicted' when id=4 then 'context_only'
          when id=5 then 'not_evaluable' else 'confirmed' end,
        '{}'::jsonb, 'Rule', '2026-10-02 22:01+00'
      from generate_series(2,7) id;
    `);
    const pending = (await db.query<Record<string, unknown>>(
      "select * from match_reading_bilan where fixture_id=1",
    )).rows[0];
    assert.equal(pending.home_team_name, "Club 1");
    assert.equal(pending.away_team_name, "Opponent 1");
    assert.equal(pending.competition_name, "Ligue 1");
    assert.equal(pending.verdict, null);
    assert.equal(pending.home_goals, null);

    const rows = (await db.query<Record<string, unknown>>(
      "select * from match_reading_bilan_breakdown('2026-10-01','2026-10-03')",
    )).rows;
    assert.equal(rows.length, 3);
    const english = rows.find((r) => r.league_id === 39)!;
    assert.equal(Number(english.total), 2);
    assert.equal(Number(english.evaluable), 2);
    assert.equal(Number(english.confirmation_rate), 50);
    assert.equal(Number(english.home_confirmed), 1);
    assert.equal(Number(english.away_confirmed), 0);
    assert.deepEqual(english.outcome_rules, ["team_not_lose"]);
    const french = rows.find((r) =>
      r.league_id === 61 && r.reading_id === "positive_streak"
    )!;
    assert.equal(Number(french.pending), 1);
    assert.equal(Number(french.not_evaluable), 1);
    assert.equal(french.confirmation_rate, null);
    const away = (await db.query<Record<string, unknown>>(
      "select * from match_reading_bilan_breakdown('2026-10-01','2026-10-03','away')",
    )).rows;
    assert.equal(away.length, 1);
    assert.equal(Number(away[0].contradicted), 1);
    const outside = await db.query<Record<string, unknown>>(
      "select * from match_reading_bilan_breakdown('2026-09-01','2026-09-02')",
    );
    assert.equal(outside.rows.length, 0);

    // Anonymous users retain access to the enriched public view and RPC.
    await db.exec("set role anon;");
    assert.equal(
      (await db.query<Record<string, unknown>>(
        "select home_team_name from match_reading_bilan where fixture_id=1",
      )).rows[0].home_team_name,
      "Club 1",
    );
    assert.equal(
      (await db.query<Record<string, unknown>>(
        "select * from match_reading_bilan_breakdown('2026-10-01','2026-10-03')",
      )).rows.length,
      3,
    );
    await db.exec("reset role;");

    // A newer result without evaluation must not borrow the old verdict.
    await db.exec(`insert into match_result_snapshots values (
      '10000000-0000-0000-0001-000000000002',2,'Club 2','Opponent 2',0,1,'FT',
      '2026-10-03 01:00+00','2026-10-03 01:00+00');`);
    const corrected = (await db.query<Record<string, unknown>>(
      "select * from match_reading_bilan where fixture_id=2",
    )).rows;
    assert.equal(corrected.length, 1);
    assert.equal(corrected[0].home_goals, 0);
    assert.equal(corrected[0].verdict, null);

    // Execute the actual existing outcome contract: a win and a draw continue
    // a positive unbeaten series, a defeat contradicts it.
    const verdictFunction = previous.slice(
      previous.indexOf(
        "create or replace function public.match_reading_verdict(",
      ),
      previous.indexOf(
        "create or replace function public.evaluate_match_result_snapshot()",
      ),
    );
    await db.exec(verdictFunction);
    const verdicts = (await db.query<Record<string, unknown>>(`select
      match_reading_verdict('team_not_lose','home','FT',2,1) as win,
      match_reading_verdict('team_not_lose','home','FT',1,1) as draw,
      match_reading_verdict('team_not_lose','home','FT',0,1) as loss`)).rows[0];
    assert.deepEqual(verdicts, {
      win: "confirmed",
      draw: "confirmed",
      loss: "contradicted",
    });
  } finally {
    await db.close();
  }
});
