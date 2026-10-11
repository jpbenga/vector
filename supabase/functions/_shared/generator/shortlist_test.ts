import assert from "node:assert/strict";
import {
  compactShortlistReferences,
  mergeShortlistSources,
  resolveShortlist,
  shortlistGroups,
  shortlistReference,
} from "./shortlist.ts";
import { ConversationReader, conversationTools } from "./conversation_tools.ts";
import type { Context } from "./contracts.ts";
import type { Source } from "./catalog.ts";
const now = new Date("2026-10-11T10:00:00Z"),
  id = "11111111-1111-4111-8111-111111111111";
const ref = {
  sessionId: id,
  revision: 3,
  keys: ["football:1", "football:2", "hockey:1"],
};
const snapshot = {
  sessions: [{
    id,
    revision: 3,
    timezone: "Europe/Paris",
    expiresAt: "2026-10-12T10:00:00Z",
    items: [
      {
        key: "football:1",
        sport: "football",
        fixtureId: "1",
        date: "2026-10-11",
        fixture: { kickoff: "2026-10-11T18:00:00Z" },
      },
      {
        key: "football:2",
        sport: "football",
        fixtureId: "2",
        date: "2026-10-12",
        fixture: { kickoff: "2026-10-12T18:00:00Z" },
      },
      {
        key: "hockey:1",
        sport: "hockey",
        fixtureId: "1",
        date: "2026-10-12",
        fixture: { kickoff: "2026-10-12T19:00:00Z" },
      },
    ],
  }],
};
Deno.test("Shortlist references validate owner-scoped membership, revisions and expiry", () => {
  const scope = resolveShortlist(ref, snapshot, now);
  assert.equal(scope.items.length, 3);
  assert.equal(shortlistGroups(scope, ["football", "hockey"]).length, 2);
  assert.throws(
    () => resolveShortlist({ ...ref, revision: 2 }, snapshot, now),
    /changé/,
  );
  assert.throws(
    () => resolveShortlist({ ...ref, keys: ["football:99"] }, snapshot, now),
    /appartient/,
  );
  assert.throws(() => resolveShortlist(ref, { sessions: [] }, now), /expiré/);
  assert.throws(
    () => resolveShortlist(ref, snapshot, new Date("2026-10-13")),
    /expiré/,
  );
  assert.throws(
    () => shortlistReference({ ...ref, keys: ["football:1", "football:1"] }),
    /invalide/,
  );
});
Deno.test("Shortlist reader resolves both dates and sports, excludes unrelated matches and keeps complete payloads", async () => {
  const context: Context = {
    origin: "profile",
    scope: "discovery",
    view: "shortlist",
    timezone: "Europe/Paris",
    budget: 100,
    configurationPolicy: "request",
    preferences: {
      football: { competitions: ["ignored"], readings: [], markets: [] },
      hockey: { competitions: [], readings: [], markets: [] },
    },
    shortlist: resolveShortlist(ref, snapshot, now),
  };
  const football = (date: string): Source => ({
    id: "same-football",
    sport: "football",
    capturedAt: now.toISOString(),
    payload: {
      raw: {
        fixtures: [{
          fixture: {
            id: date === "2026-10-11" ? 1 : 2,
            date: date + "T18:00:00Z",
            status: { short: "NS" },
          },
          league: { id: 1, name: "League" },
          teams: {
            home: { id: 1, name: "Home" },
            away: { id: 2, name: "Away" },
          },
        }, {
          fixture: {
            id: 99,
            date: date + "T20:00:00Z",
            status: { short: "NS" },
          },
          league: { id: 1, name: "Unrelated" },
          teams: {
            home: { id: 3, name: "Outside" },
            away: { id: 4, name: "Outside" },
          },
        }],
      },
      computed: { fixtures: [] },
    },
  });
  const reader = new ConversationReader({
    context,
    date: "2026-10-11",
    state: null,
    now,
    id: "test",
    message: "",
  }, {
    sources: async (_context, date, sports) => [
      ...(sports.includes("football") ? [football(date)] : []),
      ...(sports.includes("hockey")
        ? [{
          id: "hockey",
          sport: "hockey" as const,
          capturedAt: now.toISOString(),
          payload: {
            items: [{
              id: 1,
              startsAt: date + "T19:00:00Z",
              status: "scheduled",
              competitionId: 1,
              home: { id: 1, name: "Hockey home" },
              away: { id: 2, name: "Hockey away" },
            }],
          },
        }]
        : []),
    ],
  });
  const found = await reader.execute("read_shortlist", {}) as any;
  assert.equal(found.resolved, 3);
  assert.equal(found.expected, 3);
  assert.deepEqual(
    new Set(found.matches.map((m: any) => m.key)),
    new Set(ref.keys),
  );
  const query = reader.queries.get(found.queryId)!;
  assert.equal(query.sources.filter((s) => s.sport === "football").length, 1);
  assert.equal(
    (query.sources.find((s) => s.sport === "football")!.payload.raw as any)
      .fixtures.filter((f: any) => f.fixture.id !== 99).length,
    2,
  );
  const onlyFootball = await reader.query(
    "2026-10-11",
    ["football"],
    "shortlist",
    "teams",
  );
  assert.equal(onlyFootball.matches.length, 2);
  assert(
    !conversationTools.some((t) =>
      /write|remove_shortlist|add_shortlist/.test(t.name)
    ),
  );
});
Deno.test("Shortlist persistence keeps references, never duplicates hydrated fixture rows across tickets", () => {
  const scope = resolveShortlist(ref, snapshot, now);
  const state = {
    context: { shortlist: scope },
    tickets: [{ context: { shortlist: structuredClone(scope) } }],
  };
  compactShortlistReferences(state);
  assert.equal(state.context.shortlist.keys.length, 3);
  assert.equal(Object.hasOwn(state.context.shortlist, "items"), false);
  const sources: Source[] = [{
    id: "same",
    sport: "football",
    capturedAt: "at",
    payload: { raw: { fixtures: [{ id: 1 }] } },
  }, {
    id: "same",
    sport: "football",
    capturedAt: "at",
    payload: { raw: { fixtures: [{ id: 2 }] } },
  }];
  assert.equal(
    (mergeShortlistSources(sources)[0].payload.raw as any).fixtures.length,
    2,
  );
});

Deno.test("Shortlist composes a ticket across both dates instead of excluding the later fixture", async () => {
  const { source: factualSource } = await import("./evaluation_cases.ts");
  const { initialIntent } = await import("./conversation_memory.ts");
  const scope = resolveShortlist(
    { ...ref, keys: ["football:1", "football:2"] },
    snapshot,
    now,
  );
  const context: Context = {
    origin: "profile",
    scope: "discovery",
    view: "shortlist",
    configurationPolicy: "request",
    timezone: "Europe/Paris",
    budget: 100,
    preferences: { football: { competitions: [], readings: [], markets: [] } },
    shortlist: scope,
  };
  const reader = new ConversationReader({
    context,
    date: "2026-10-11",
    state: null,
    now,
    id: "test",
    message: "Un ticket sur ces deux rencontres",
  }, {
    sources: async (_c, date) => {
      const source = factualSource();
      source.capturedAt = now.toISOString();
      const id = date === "2026-10-11" ? 1 : 2;
      const raw = source.payload.raw as any;
      raw.fixtures = raw.fixtures.filter((f: any) => f.fixture.id === id).map((
        f: any,
      ) => ({ ...f, fixture: { ...f.fixture, date: date + "T18:00:00Z" } }));
      raw.odds = raw.odds.filter((f: any) => f.fixture.id === id).map((
        f: any,
      ) => ({ ...f, update: now.toISOString() }));
      (source.payload.computed as any).fixtures =
        (source.payload.computed as any).fixtures.filter((f: any) =>
          f.fixture_id === id
        );
      return [source];
    },
  });
  const query = await reader.execute("read_shortlist", {}) as any;
  const response = await reader.execute("read_composition_options", {
    plan: {
      intent: {
        ...initialIntent(context, "2026-10-11"),
        action: "generate",
        tickets: [{
          stake: 20,
          minimum: null,
          maximum: null,
          kind: "total",
          minSelections: 2,
          maxSelections: 2,
        }],
        maxSelections: 2,
        minSelections: 2,
      },
      changedFields: ["tickets", "maxSelections", "minSelections"],
      newTask: false,
      focusMode: "keep",
      focusKeys: [],
    },
  }) as any;
  assert.equal(query.resolved, 2);
  assert.equal(response.tickets.length, 1, JSON.stringify(response));
  assert.deepEqual(
    response.tickets[0].picks.map((p: any) => p.matchId).sort(),
    ["api-fixture-1", "api-fixture-2"],
  );
});
