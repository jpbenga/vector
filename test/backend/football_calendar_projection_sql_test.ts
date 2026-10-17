import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";

Deno.test("football calendar projects only the requested day, preserves facts and source identity; Radar and historical cutoffs remain independent", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon;create role authenticated;create role service_role;
   create table match_feed_analysis_snapshots(id uuid primary key,scope text,scope_key text,league_ids integer[],captured_at timestamptz,as_of timestamptz,window_start date,window_end date,payload jsonb);`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261017190000_football_calendar_projection.sql",
      ),
    );
    const { rows } = await db.query<{ calendar_day: string }>(
      "select ((now() at time zone 'Europe/Paris')::date)::text as calendar_day",
    );
    const day = rows[0].calendar_day;
    const shifted = (n: number) => {
      const d = new Date(day + "T12:00:00Z");
      d.setUTCDate(d.getUTCDate() + n);
      return d.toISOString().slice(0, 10);
    };
    const fixture = (id: number, date: string) => ({
      fixture: { id, date: date + "T12:00:00Z" },
      league: { id: 61 },
      teams: { home: { id: 1 }, away: { id: 2 } },
    });
    const base = {
      schema_version: 1,
      source: "api-football",
      raw: {
        fixtures: [
          fixture(1, day),
          fixture(2, shifted(1)),
          fixture(3, shifted(-2)),
        ],
        odds: [{ fixture: { id: 1 }, price: 2.1 }, {
          fixture: { id: 2 },
          price: 1.8,
        }],
        recent_league_matches: [
          { team: { id: 1 }, matches: [{ result: "W" }] },
          { team: { id: 3 }, matches: [{ result: "L" }] },
        ],
        player_form_radar: [{ team: { id: 1 }, player: { id: 11 } }, {
          team: { id: 3 },
          player: { id: 33 },
        }],
        head_to_head: [{ privateSize: "unneeded history" }],
      },
      computed: {
        fixtures: [{ fixture_id: 1, readings: [{ id: "real-reading" }] }, {
          fixture_id: 2,
          readings: [],
        }],
      },
    };
    await db.query(
      `insert into match_feed_analysis_snapshots values($1,'league','league:61',array[61],now()-interval '1 minute',now()-interval '1 minute',$2,$3,$4::jsonb)`,
      [
        "00000000-0000-4000-8000-000000000001",
        shifted(-7),
        shifted(14),
        JSON.stringify(base),
      ],
    );
    const read = async (date: string, section = "calendar") =>
      (await db.query<{ result: Record<string, any>[] }>(
        `select read_football_calendar($1::date,$2)result`,
        [date, section],
      )).rows[0].result;
    const calendar = (await read(day))[0];
    assert.equal(calendar.id, "00000000-0000-4000-8000-000000000001");
    assert.deepEqual(calendar.payload.raw.fixtures, [base.raw.fixtures[0]]);
    assert.deepEqual(calendar.payload.raw.odds, [base.raw.odds[0]]);
    assert.deepEqual(calendar.payload.computed.fixtures, [
      base.computed.fixtures[0],
    ]);
    assert.equal(calendar.payload.raw.player_form_radar.length, 1);
    assert.equal(calendar.payload.raw.recent_league_matches.length, 1);
    assert.ok(!("head_to_head" in calendar.payload.raw));
    const radar = (await read(day, "radar"))[0];
    assert.equal(radar.payload.raw.recent_league_matches.length, 2);
    assert.equal(radar.payload.raw.player_form_radar.length, 2);
    assert.deepEqual(await read(shifted(-2)), []);
    const historic = {
      ...base,
      raw: { ...base.raw, fixtures: [fixture(9, shifted(-2))] },
    };
    await db.query(
      `insert into match_feed_analysis_snapshots values($1,'league','league:61',array[61],$2::timestamptz,$2::timestamptz,$3,$4,$5::jsonb)`,
      [
        "00000000-0000-4000-8000-000000000002",
        shifted(-2) + "T06:00:00Z",
        shifted(-7),
        shifted(14),
        JSON.stringify(historic),
      ],
    );
    assert.equal(
      (await read(shifted(-2)))[0].payload.raw.fixtures[0].fixture.id,
      9,
    );
    assert.equal(
      (await db.query<{ n: number }>(
        "select count(*)::int n from match_feed_analysis_snapshots",
      )).rows[0].n,
      2,
    );
  } finally {
    await db.close();
  }
});
