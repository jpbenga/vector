import assert from "node:assert/strict";
import {
  CompositionContractError,
  requestedSports,
} from "./conversation_scope.ts";
import {
  ConversationReader,
  type ConversationReadPort,
} from "./conversation_tools.ts";
import {
  type ConversationPlan,
  initialIntent,
  rememberTurn,
  resolvePlan,
} from "./conversation_memory.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import { type Context, obj, type State } from "./contracts.ts";
import { converse } from "./conversation.ts";
import { turnStatus } from "./turn_status.ts";
const both: Context = {
  ...context,
  preferences: {
    ...context.preferences,
    hockey: { competitions: [], readings: [], markets: [] },
  },
  configurationPolicy: "request",
};
const input = (message = "", state: State | null = null) => ({
  context: both,
  date: intent.date,
  today: "2026-10-08",
  now,
  state,
  message,
  id: "scope-test",
});
const plan = (
  patch = {},
  changedFields: string[] = [],
  extra = {},
) => ({
  intent: { ...initialIntent(both, intent.date), ...patch },
  changedFields,
  newTask: false,
  focusMode: "keep",
  focusKeys: [],
  ...extra,
} as ConversationPlan);
const port: ConversationReadPort = {
  sources: async (_c, _d, sports) =>
    sports.includes("football") ? [source()] : [],
};
const search = (sports: string[]) => ({
  date: intent.date,
  sports,
  view: "all",
  radarKind: "teams",
  query: null,
  offset: 0,
  limit: 60,
});
Deno.test("literal sport constraints handle exclusion, multisport and deliberate switches without converting questions into scope changes", () => {
  assert.deepEqual(requestedSports("Depuis Tous en hockey aujourd’hui"), [
    "hockey",
  ]);
  assert.deepEqual(requestedSports("football et hockey"), [
    "football",
    "hockey",
  ]);
  assert.deepEqual(requestedSports("football sans hockey"), ["football"]);
  assert.deepEqual(requestedSports("hockey, pas de football"), ["hockey"]);
  assert.deepEqual(requestedSports("Passons du hockey au football"), [
    "football",
  ]);
  assert.equal(
    requestedSports("Pourquoi ce match football plutôt que le hockey ?"),
    null,
  );
  assert.equal(requestedSports("Sans hockey"), null);
});
Deno.test("changedFields is a patch: unrelated values cannot silently replace dates, markets, stake or sport", () => {
  const s = {
    messages: [],
    intent: {
      ...intent,
      sports: ["hockey"],
      date: "2026-10-11",
      marketIds: ["result_regulation"],
    },
  } as unknown as State;
  const resolved = resolvePlan(
    plan({
      tickets: [{
        stake: 30,
        kind: "unspecified",
        minimum: null,
        maximum: null,
      }],
    }, ["stake"]),
    s,
    both,
    intent.date,
  );
  assert.deepEqual(resolved.sports, ["hockey"]);
  assert.equal(resolved.date, "2026-10-11");
  assert.deepEqual(resolved.marketIds, ["result_regulation"]);
  assert.equal(resolved.tickets[0].stake, 30);
});
Deno.test("an explicit hockey request repairs the omitted sports patch before any composition search", async () => {
  const calls: string[][] = [];
  const r = new ConversationReader(
    input("En hockey seulement, prépare deux rencontres"),
    {
      sources: async (_c, _d, sports) => {
        calls.push(sports);
        return [];
      },
    },
  );
  await r.execute("search_matches", search(["hockey"]));
  const result = obj(
    await r.execute("read_composition_options", {
      plan: plan({
        sports: ["hockey"],
        action: "generate",
        view: "all",
        tickets: [{
          stake: null,
          kind: "unspecified",
          minimum: null,
          maximum: null,
        }],
        minSelections: 2,
        maxSelections: 2,
      }, ["view", "tickets", "minSelections", "maxSelections"]),
    }),
  );
  assert.deepEqual(obj(result.intent).sports, ["hockey"]);
  assert.deepEqual(calls, [["hockey"]]);
  assert.equal(result.projectionId, "projection-1");
  assert.match(String(result.result), /mise/);
});
Deno.test("compatible chosen query repairs an omitted sport patch even for an inferred competition, without altering other constraints", async () => {
  const r = new ConversationReader(
    input("Prépare les rencontres déjà consultées"),
    port,
  );
  await r.execute("search_matches", search(["football"]));
  await r.execute("read_matches", {
    queryId: "q1",
    matchKeys: ["football:1", "football:2"],
  });
  const p = plan(
    {
      ...intent,
      view: "all",
      minSelections: 2,
      maxSelections: 2,
      tickets: [{
        stake: 30,
        kind: "unspecified",
        minimum: null,
        maximum: null,
      }],
    },
    ["view", "tickets", "minSelections", "maxSelections"],
    { focusMode: "choose", focusKeys: ["football:1", "football:2"] },
  );
  const result = obj(await r.execute("read_composition_options", { plan: p }));
  assert.deepEqual(obj(result.intent).sports, ["football"]);
  assert.equal(result.queryId, "q1");
  assert.equal(r.queries.size, 1);
  assert.ok(Array.isArray(result.tickets) && result.tickets.length);
});
Deno.test("a remembered sport survives another message; an explicit switch preserves the stake and count", async () => {
  const r = new ConversationReader(input("En hockey"), port);
  const previous = {
    id: "session",
    revision: 0,
    intent: { ...intent, sports: ["hockey"] },
    context: both,
    tickets: [],
    versions: [],
    pending: null,
    messages: [],
    updatedAt: now.toISOString(),
    saved: false,
  } as State;
  rememberTurn(previous, null, r.resolveIntent(plan({ sports: ["hockey"] })), [{
    sport: "hockey",
    matchId: "425260",
    match: "Stored matchup",
  }], []);
  const next = new ConversationReader(
    input("Change une sélection", previous),
    port,
  );
  assert.deepEqual(
    next.resolveIntent(plan({ action: "replace", selectionIndex: 0 })).sports,
    ["hockey"],
  );
  assert.equal(
    next.resolveIntent(plan({ action: "replace" })).fixtureFocus?.[0].sport,
    "hockey",
  );
  await assert.rejects(
    next.execute("search_matches", search(["football", "hockey"])),
    CompositionContractError,
  );
  const switched = new ConversationReader(
    input("Passe au football", previous),
    port,
  );
  const change = switched.resolveIntent(
    plan({ sports: ["football"], action: "generate" }),
  );
  assert.deepEqual(change.sports, ["football"]);
  assert.equal(change.fixtureFocus, undefined);
  assert.deepEqual(
    change.tickets,
    previous.conversation!.workingIntent.tickets,
  );
});
Deno.test("explicit multisport scope never shrinks just because the chosen fixtures belong to football", async () => {
  const r = new ConversationReader(input("Compare football et hockey"), port);
  await r.execute("search_matches", search(["football", "hockey"]));
  await r.execute("read_matches", { queryId: "q1", matchKeys: ["football:1"] });
  const result = obj(
    await r.execute("read_composition_options", {
      plan: plan(
        {
          ...intent,
          view: "all",
          maxSelections: 1,
          minSelections: 1,
          tickets: [{
            stake: 30,
            kind: "unspecified",
            minimum: null,
            maximum: null,
          }],
        },
        ["view", "tickets", "maxSelections", "minSelections"],
        { focusMode: "choose", focusKeys: ["football:1"] },
      ),
    }),
  );
  assert.deepEqual(obj(result.intent).sports, ["football", "hockey"]);
  assert.equal(result.queryId, "q1");
  assert.equal(r.queries.size, 1);
});
Deno.test("same immutable dossiers can be reused after a deliberate sport narrowing", async () => {
  const r = new ConversationReader(input(), port);
  await r.execute("search_matches", search(["football", "hockey"]));
  await r.execute("read_matches", { queryId: "q1", matchKeys: ["football:1"] });
  const p = plan(
    { ...intent, view: "all", maxSelections: 1, minSelections: 1 },
    ["sports", "view", "tickets", "maxSelections", "minSelections"],
    { focusMode: "choose", focusKeys: ["football:1"] },
  );
  const resolved = await r.resolve(p);
  assert.equal(resolved.query.id, "q2");
  assert.ok(r.detailsRead.has("q2:football:1"));
});
Deno.test("a changed publication cannot reuse old dossiers: the structured refusal points to precisely the missing query and keys", async () => {
  let calls = 0;
  const r = new ConversationReader(input(), {
    sources: async () => [{
      ...source(),
      id: ++calls === 1 ? "initial-publication" : "new-publication",
    }],
  });
  await r.execute("search_matches", search(["football", "hockey"]));
  await r.execute("read_matches", { queryId: "q1", matchKeys: ["football:1"] });
  const p = plan({ ...intent, view: "all" }, ["sports", "view", "tickets"], {
    focusMode: "choose",
    focusKeys: ["football:1"],
  });
  await assert.rejects(r.resolve(p), (e: unknown) => {
    assert.ok(e instanceof CompositionContractError);
    assert.equal(e.contract.queryId, "q2");
    assert.deepEqual(e.contract.dossierKeys, ["football:1"]);
    assert.deepEqual(e.contract.compatibleQueryIds, ["q1"]);
    return true;
  });
  await r.execute("read_matches", { queryId: "q2", matchKeys: ["football:1"] });
  assert.equal((await r.resolve(p)).query.id, "q2");
});
Deno.test("repeating a deterministic contract refusal stops before a third model repair, even with changed markets", async () => {
  let modelCalls = 0;
  const p = plan({ ...intent, view: "all" }, ["sports", "view", "tickets"], {
    focusMode: "choose",
    focusKeys: ["football:999"],
  });
  const call = (name: string, args: unknown) => ({
    type: "function_call",
    name,
    arguments: JSON.stringify(args),
    call_id: "call-" + modelCalls,
  });
  await assert.rejects(
    converse(input("En football"), {
      key: "test",
      model: "gpt-6-luna",
      reads: port,
      fetcher: (async (_url, init) => {
        const body = JSON.parse(String(init?.body));
        modelCalls++;
        if (modelCalls === 3) {
          const last = JSON.parse(body.input.at(-1).output);
          assert.equal(last.contract.code, "composition_details_missing");
          assert.equal(last.contract.queryId, "q1");
          p.intent.marketIds = ["doubleChance"];
        }
        return Response.json({
          status: "completed",
          output: [
            modelCalls === 1
              ? call("search_matches", search(["football"]))
              : call("read_composition_options", { plan: p }),
          ],
        });
      }) as typeof fetch,
    }),
    CompositionContractError,
  );
  assert.equal(modelCalls, 3); // search, refusal, one repair; all mocked and free.
});
Deno.test("contract failures have an actionable owner-visible explanation; raw provider errors remain hidden", () => {
  const contract = {
    code: "composition_details_missing",
    queryId: "q2",
    dossierKeys: ["hockey:425260"],
  };
  const result = obj(
    turnStatus({
      status: "failed",
      usage: {
        failure_name: "CompositionContractError",
        failure_message: "Relisez les dossiers dans q2.",
        failure_contract: contract,
      },
    }, true).turn,
  );
  assert.match(String(result.error), /q2/);
  assert.deepEqual(result.contract, contract);
});
