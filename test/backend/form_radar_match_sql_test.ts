import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
Deno.test("Radar snapshots qualify before kickoff, freeze, stay public read-only and preserve hockey events", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
   create schema cron;create function cron.schedule(text,text,text) returns bigint language sql as $$select 1::bigint$$;
   create table ops_configuration(singleton boolean,base_url text,sync_secret text);
   insert into ops_configuration values(true,'https://example.supabase.co','secret');
   create table match_feed_analysis_snapshots(id uuid,scope_key text,captured_at timestamptz,payload jsonb);
   create table sport_feed_snapshots(id uuid,sport text,captured_at timestamptz,payload jsonb);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261005180000_hockey_live_collection.sql",
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261009230000_form_radar_match_snapshots.sql",
      ),
    );
    const now = Date.now(),
      at = new Date(now - 60000).toISOString(),
      kickoff = new Date(now + 3600000).toISOString();
    const player = (id: number, goals: number) => ({
      player: { id, name: `Player ${id}` },
      team: { id: 2, name: "Home" },
      activity: [1, 2, 3].map((n) => ({
        fixture_id: 10 + n,
        played_at: new Date(now - (4 - n) * 86400000).toISOString(),
        goals,
        assists: 0,
        appeared: true,
      })),
    });
    const payload = {
      raw: {
        fixtures: [{
          fixture: { id: 1, date: kickoff, status: { short: "NS" } },
          teams: { home: { id: 2 }, away: { id: 3 } },
        }],
        player_form_radar: [player(7, 1), player(8, 0)],
      },
    };
    const source = "11111111-1111-4111-8111-111111111111";
    await db.query(
      "insert into match_feed_analysis_snapshots values($1,'league:1',$2,$3)",
      [source, at, payload],
    );
    const one = async (sql: string) =>
      (await db.query<{ v: any }>(sql)).rows[0]?.v;
    const snapshot = await one(
      "select form_radar_for_fixtures('football',array['1'])->0 v",
    );
    assert.equal(snapshot.profiles.length, 1);
    assert.equal(snapshot.profiles[0].player.id, 7);
    assert.ok(Date.parse(snapshot.recordedAt) < Date.parse(kickoff));
    // The latest pre-match publication replaces the hot roster, including empty.
    await db.query(
      "select form_radar_record_publication('football',$1,$2,$3)",
      [source, new Date(now - 30000).toISOString(), {
        raw: { ...payload.raw, player_form_radar: [player(7, 0)] },
      }],
    );
    assert.equal(
      await one(
        "select jsonb_array_length(profiles) v from form_radar_match_snapshots",
      ),
      0,
    );
    // A late import cannot create a retrospective claim, or modify a locked one.
    await db.query(
      "select form_radar_record_publication('football',$1,$2,$3)",
      [source, at, {
        raw: {
          ...payload.raw,
          fixtures: [{
            ...payload.raw.fixtures[0],
            fixture: {
              id: 2,
              date: new Date(now - 3600000).toISOString(),
              status: { short: "NS" },
            },
          }],
        },
      }],
    );
    assert.equal(
      await one(
        "select jsonb_array_length(form_radar_for_fixtures('football',array['2'])) v",
      ),
      0,
    );
    await db.exec(
      "update form_radar_match_snapshots set kickoff_at=now()-interval '1 minute',captured_at=now()-interval '2 minutes',recorded_at=now()-interval '2 minutes'",
    );
    await db.query(
      "select form_radar_record_publication('football',$1,$2,$3)",
      [source, at, payload],
    );
    assert.equal(
      await one(
        "select jsonb_array_length(profiles) v from form_radar_match_snapshots",
      ),
      0,
    );
    await db.exec("set role anon");
    assert.equal(
      await one(
        "select jsonb_array_length(form_radar_for_fixtures('football',array['1'])) v",
      ),
      1,
    );
    await assert.rejects(
      () => db.exec("delete from form_radar_match_snapshots"),
      /permission denied/,
    );
    await assert.rejects(
      () =>
        db.query(
          "select form_radar_record_publication('football',$1,now(),'{}')",
          [source],
        ),
      /permission denied/,
    );
    await assert.rejects(
      () => db.exec("select hockey_radar_event_due(array['1'])"),
      /permission denied/,
    );
    await db.exec("reset role;select hockey_live_set_enabled(true)");
    const publish = async (withEvents: boolean) => {
      await db.exec(
        "update hockey_live_configuration set last_started_at=now()-interval '60 seconds'",
      );
      const token = await one("select hockey_live_claim()->>'token' v");
      const fixture = {
        id: "9",
        competitionId: "35",
        competitionName: "KHL",
        season: "2026",
        calendarDate: new Date(now).toISOString().slice(0, 10),
        startsAt: at,
        status: "live",
        providerStatus: "P2",
        home: { id: "2" },
        away: { id: "3" },
        scores: { current: { home: 1, away: 0 } },
        ...(withEvents
          ? {
            matchEvents: {
              collectedAt: at,
              events: [{ type: "goal" }],
              isFinal: false,
            },
          }
          : {}),
      };
      await db.query("select hockey_live_publish($1,$2,5,false)", [token, [{
        fixture,
        capturedAt: new Date().toISOString(),
      }]]);
    };
    await publish(true);
    await publish(false);
    assert.equal(
      await one(
        "select jsonb_array_length(payload#>'{matchEvents,events}') v from sport_live_states",
      ),
      1,
    );
  } finally {
    await db.close();
  }
});
