import { PGlite } from "npm:@electric-sql/pglite@0.5.8";
import assert from "node:assert/strict";
import capture from "../fixtures/generator_catalogue_parity_20261014.json" with {
  type: "json",
};
import { catalogueParity } from "../../tool/check_generator_catalogue_parity.ts";
import { ConversationReader } from "../../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  calendarDay,
  type Context,
  type Json,
  obj,
  rows,
  type Sport,
} from "../../supabase/functions/_shared/generator/contracts.ts";
import {
  type DaySourcePort,
  loadDaySources,
} from "../../supabase/functions/_shared/generator/day_sources.ts";

Deno.test("real public football and fast hockey captures retain every identity through search and details", async () => {
  for (const sport of ["football", "hockey"] as const) {
    const result = await catalogueParity(
      capture.sports[sport],
      capture.day,
      capture.asOf,
      sport,
    );
    assert.equal(result.visible, sport === "football" ? 14 : 26);
    assert.equal(result.discoverable, result.visible);
    assert.equal(result.paidModelCalls, 0);
    if (sport === "football") {
      const cl = result.matches.filter((m) =>
        m.sourceId === "ab203c43-3918-47ca-8851-aa4bc772633d"
      );
      assert.equal(cl.length, 9);
      assert.ok(
        cl.every((m) =>
          m.publishedQuotes > 0 &&
          String(obj(m.marketAvailability).warnings).includes(
            "Publication analytique ancienne",
          )
        ),
      );
      assert.ok(
        cl.every((m) =>
          !rows(obj(m.marketAvailability).reasons).some((r) =>
            r.code === "publication_stale" || r.code === "quotes_stale"
          )
        ),
      );
    }
  }
});

Deno.test("SQL freshness regression: reproduce 5/14, correct 14/14; stale hockey, J+7/J+13, absent odds/readings stay discoverable", async () => {
  const db = new PGlite();
  try {
    await db.exec(
      `create role anon; create role authenticated; create role service_role;
      create table match_feed_analysis_snapshots(id uuid primary key,scope_key text,as_of timestamptz,captured_at timestamptz,window_start date,window_end date,payload jsonb);
      create table sport_feed_snapshots(id uuid primary key,sport text,captured_at timestamptz,window_start date,window_end date,overview jsonb);
      create function with_hockey_market_quotes(jsonb) returns jsonb language sql stable as $$select $1$$;`,
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261010090000_lector_generator_day_sources.sql",
      ),
    );
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261013210000_generator_domestic_form_projection.sql",
      ),
    );
    const now = new Date(), day = calendarDay(now, "Europe/Paris");
    const end = new Date(Date.parse(day) + 13 * 86400000).toISOString().slice(
      0,
      10,
    );
    for (const sport of ["football", "hockey"] as const) {
      for (const source of rows(capture.sports[sport].page.sources)) {
        const payload = structuredClone(obj(source.payload));
        const oldCl = source.id === "ab203c43-3918-47ca-8851-aa4bc772633d";
        const at = new Date(
          now.getTime() - (sport === "hockey" || oldCl ? 41 : 10) * 3600000,
        ).toISOString();
        const fixtures = rows(
          sport === "hockey" ? payload.items : obj(payload.raw).fixtures,
        );
        for (const fixture of fixtures) {
          if (sport === "hockey") fixture.startsAt = day + "T17:00:00Z";
          else obj(fixture.fixture).date = day + "T17:00:00Z";
        }
        // Extra dates use existing public fixture identities; no new sporting facts.
        const future = [7, 13].map((gap) => {
          const fixture = structuredClone(fixtures[0]),
            date = new Date(Date.parse(day) + gap * 86400000).toISOString()
              .slice(0, 10);
          if (sport === "hockey") {
            fixture.id = String(Number(fixture.id) + gap * 1000000);
            fixture.startsAt = date + "T17:00:00Z";
            fixture.readings = [];
            fixture.quotes = [];
          } else {
            obj(fixture.fixture).id = Number(obj(fixture.fixture).id) +
              gap * 1000000;
            obj(fixture.fixture).date = date + "T17:00:00Z";
          }
          return fixture;
        });
        fixtures.push(...future);
        if (sport === "hockey") payload.items = fixtures;
        else obj(payload.raw).fixtures = fixtures;
        if (sport === "football") {
          await db.query(
            "insert into match_feed_analysis_snapshots values($1,$2,$3,$3,$4,$5,$6)",
            [
              source.id,
              "league:" + obj(fixtures[0].league).id,
              at,
              day,
              end,
              payload,
            ],
          );
        } else {await db.query(
            "insert into sport_feed_snapshots values($1,'hockey',$2,$3,$4,$5)",
            [source.id, at, day, end, {
              ...payload,
              capturedAt: at,
              provider: "api-hockey",
            }],
          );}
      }
    }
    const port: DaySourcePort = {
      manifest: async (p) =>
        (await db.query<{ v: unknown }>(
          "select lector_generator_day_manifest($1,$2,$3,$4,$5,$6,$7) v",
          [
            p.p_date,
            p.p_timezone,
            p.p_sports,
            p.p_competitions,
            p.p_readings,
            p.p_scenarios,
            p.p_radar,
          ],
        )).rows[0].v,
      page: async (p) =>
        (await db.query<{ v: unknown }>(
          "select lector_generator_day_page($1,$2,$3,$4) v",
          [p.p_date, p.p_timezone, p.p_sources, p.p_matches],
        )).rows[0].v,
    };
    const context: Context = {
      origin: "profile",
      scope: "discovery",
      view: "all",
      configurationPolicy: "request",
      timezone: "Europe/Paris",
      budget: 100,
      preferences: {},
    };
    const reader = () =>
      new ConversationReader({
        context,
        date: day,
        now,
        state: null,
        id: "sql-parity",
        message: "",
      }, {
        sources: async () => {
          throw Error("Must use actual RPCs");
        },
        daySources: (c, d, s, p) => loadDaySources(c, d, s, port, p),
      });
    const search = (r: ConversationReader, sport: Sport, date = day) =>
      r.execute("search_matches", {
        date,
        sports: [sport],
        view: "all",
        radarKind: "teams",
        query: null,
        offset: 0,
        limit: 60,
      }).then(obj);
    assert.equal((await search(reader(), "football")).total, 5);
    assert.equal((await search(reader(), "hockey")).total, 0);
    await db.exec(
      await Deno.readTextFile(
        "supabase/migrations/20261014190000_generator_discovery_publication_parity.sql",
      ),
    );
    assert.equal((await search(reader(), "football")).total, 14);
    const hockeyReader = reader(),
      hockey = await search(hockeyReader, "hockey");
    assert.equal(hockey.total, 26);
    const details = rows(
      await hockeyReader.execute("read_matches", {
        queryId: hockey.queryId,
        matchKeys: rows(hockey.matches).slice(0, 8).map((m) => m.key),
      }),
    );
    assert.ok(
      details.every((m) =>
        !obj(m.marketAvailability).prematchEligible &&
        String(obj(m.marketAvailability).warnings).includes(
          "Publication analytique ancienne",
        )
      ),
    );
    for (const gap of [7, 13]) {
      for (const sport of ["football", "hockey"] as const) {
        const date = new Date(Date.parse(day) + gap * 86400000).toISOString()
          .slice(0, 10);
        const r = reader(), q = await search(r, sport, date);
        assert.equal(q.total, sport === "football" ? 3 : 1);
        const matches = rows(
          await r.execute("read_matches", {
            queryId: q.queryId,
            matchKeys: rows(q.matches).map((m) => m.key),
          }),
        );
        assert.ok(matches.every((m) =>
          rows(m.publishedQuotes).length === 0 &&
          rows(m.candidates).length === 0
        ));
      }
    }
    const audit = (await db.query<{ v: any }>(
      "select lector_generator_audit_summary($1) v",
      [{
        responseText: "Réponse conservée",
        tools: [{
          name: "search_matches",
          parameters: { date: day },
          result: { total: 14 },
        }],
      }],
    )).rows[0].v;
    assert.equal(audit.tools[0].result.total, 14);
    assert.equal(audit.responseText, "Réponse conservée");
    const acl = (await db.query<{ v: boolean }>(
      "select has_function_privilege('authenticated','lector_generator_day_manifest(date,text,text[],text[],text[],text[],jsonb)','execute') v",
    )).rows[0].v;
    assert.equal(acl, false);
  } finally {
    await db.close();
  }
});
