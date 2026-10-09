// Synthetic, deterministic evaluation corpus. No real account or provider access.
import { ConversationReader } from "./conversation_tools.ts";
import { context, now, source } from "./evaluation_cases.ts";
import { obj } from "./contracts.ts";
export async function largeQuery(count = 500) {
  const s = source(),
    raw = obj(s.payload.raw),
    computed = obj(s.payload.computed);
  const fixture = (raw.fixtures as any[])[0],
    quote = (raw.odds as any[])[0],
    reading = (computed.fixtures as any[])[0];
  raw.fixtures = Array.from(
    { length: count },
    (_, i) => ({
      ...structuredClone(fixture),
      fixture: { ...fixture.fixture, id: i + 1 },
      teams: {
        home: { id: i * 2 + 2, name: `Home ${i + 1}` },
        away: { id: i * 2 + 3, name: `Away ${i + 1}` },
      },
    }),
  );
  raw.odds = Array.from(
    { length: count },
    (_, i) => ({ ...structuredClone(quote), fixture: { id: i + 1 } }),
  );
  computed.fixtures = Array.from(
    { length: count },
    (_, i) => ({
      fixture_id: i + 1,
      readings: reading.readings.filter((r: any) => r.side === "home").map((
        r: any,
      ) => ({
        ...r,
        subject_team_id: i * 2 + (r.side === "home" ? 2 : 3),
        evidence: [{
          label: i >= count - 6
            ? "Écart de forme : domicile 15/15, extérieur 0/15 sur cinq matchs."
            : "Écart de forme : domicile 9/15, extérieur 6/15 sur cinq matchs.",
        }],
      })),
    }),
  );
  s.payload.raw = raw;
  s.payload.computed = computed;
  const reader = new ConversationReader({
    context: { ...context, view: "all" },
    date: "2026-10-10",
    state: null,
    now,
    id: "test",
    message: "Les six plus forts écarts de forme",
  }, { sources: async () => [s] });
  return {
    reader,
    query: await reader.query("2026-10-10", ["football"], "all", "teams"),
    publication: s,
  };
}
/** 250 football + 250 hockey matches, with colliding provider IDs. The only six
 * very large form gaps are the last three of each sport. */
export async function mixedDay() {
  const { publication: football } = await largeQuery(250);
  const raw = obj(football.payload.raw),
    computed = obj(football.payload.computed);
  computed.fixtures = (computed.fixtures as any[]).map((r, i) => ({
    ...r,
    readings: r.readings.map((f: any) => ({
      ...f,
      evidence: [{
        label: i >= 247
          ? "Sur cinq matchs : domicile cinq victoires, extérieur cinq défaites (15/15 contre 0/15)."
          : "Sur cinq matchs : domicile trois victoires, extérieur deux victoires (9/15 contre 6/15).",
      }],
    })),
  }));
  raw.fixtures = (raw.fixtures as any[]).map((f) => ({
    ...f,
    teams: {
      home: { ...f.teams.home, name: `Football domicile ${f.fixture.id}` },
      away: { ...f.teams.away, name: `Football extérieur ${f.fixture.id}` },
    },
  }));
  const hockey = {
    id: "hockey-publication-test",
    sport: "hockey" as const,
    capturedAt: now.toISOString(),
    payload: {
      items: Array.from({ length: 250 }, (_, i) => ({
        id: String(i + 1),
        competitionId: "35",
        competitionName: "Hockey de test",
        season: "2026",
        status: "scheduled",
        startsAt: "2026-10-10T18:30:00Z",
        calendarDate: "2026-10-10",
        home: { id: String(i * 2 + 2), name: `Hockey domicile ${i + 1}` },
        away: { id: String(i * 2 + 3), name: `Hockey extérieur ${i + 1}` },
        scores: {},
        readings: [{
          id: "winning_streak",
          subject_team_id: String(i * 2 + 2),
          side: "home",
          sample_size: 5,
          explanation: i >= 247
            ? "Sur cinq matchs : domicile cinq victoires finales, extérieur cinq défaites finales."
            : "Sur cinq matchs : domicile trois victoires finales, extérieur deux victoires finales.",
        }],
        quotesCollectedAt: now.toISOString(),
        quotes: [{
          marketCode: "result_regulation",
          scope: "regulation",
          selectionCode: "home",
          decimalOdds: 2.2,
          capturedAt: now.toISOString(),
          bookmakerId: "1",
          bookmaker: "Test",
        }],
      })),
    },
  };
  return {
    sources: [football, hockey],
    context: {
      ...context,
      preferences: {
        ...context.preferences,
        hockey: {
          competitions: ["hockey:api-hockey:competition:35"],
          readings: ["winning_streak"],
          markets: ["result_regulation"],
        },
      },
    },
  };
}
