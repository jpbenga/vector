import assert from "node:assert/strict";
import { converse } from "./conversation.ts";
import {
  ConversationReader,
  type ConversationReadPort,
  conversationTools,
} from "./conversation_tools.ts";
import {
  type ConversationPlan,
  initialIntent,
  knownFocus,
  matchKey,
  rememberTurn,
  resolvePlan,
  validatePlan,
} from "./conversation_memory.ts";
import { type Context, type Intent, type State } from "./contracts.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import { buildCatalog, type Source } from "./catalog.ts";
import { type ModelReceipt } from "./models.ts";
import { hockeyQuoteRecords } from "../sports/hockey_odds.ts";
import {
  oddsPayload,
  quoteAt,
  quotedFixture,
} from "../sports/hockey_odds_test.ts";

const date = "2026-10-10", id = "33333333-3333-4333-8333-333333333333";
function plan(
  patch: Partial<Intent> = {},
  changedFields: string[] = [],
  extra: Partial<ConversationPlan> = {},
): ConversationPlan {
  return {
    intent: { ...initialIntent(context, date), ...patch },
    changedFields,
    newTask: false,
    focusMode: "keep",
    focusKeys: [],
    ...extra,
  };
}
function baseState(request: Intent = intent): State {
  return {
    id,
    revision: 0,
    context: structuredClone(context),
    intent: structuredClone(request),
    tickets: [],
    versions: [],
    pending: null,
    messages: [],
    saved: false,
    updatedAt: now.toISOString(),
  };
}
const input = (
  state: State | null = null,
  message = "Compare les rencontres dans Pour moi.",
) => ({
  message,
  date,
  context: structuredClone(context),
  state,
  today: "2026-10-08",
  now,
  id,
});
const readPort = (): ConversationReadPort => ({
  sources: async () => [source()],
});
const toolCall = (name: string, args: unknown, call_id = name) => ({
  type: "function_call",
  name,
  call_id,
  arguments: JSON.stringify(args),
});
const output = (value: unknown) => ({
  type: "message",
  content: [{ type: "output_text", text: JSON.stringify(value) }],
});
const result = (outputs: unknown[], status = "completed") =>
  Response.json({
    status,
    id: "response-test",
    model: "gpt-6.1-sol",
    output: outputs,
    usage: {
      input_tokens: 100,
      output_tokens: 80,
      output_tokens_details: { reasoning_tokens: 30 },
    },
  });
const search = (view = "profile", sports = ["football"], day = date) => ({
  date: day,
  sports,
  view,
  radarKind: "teams",
  query: null,
  offset: 0,
  limit: 60,
});
const candidateId = `football:1:1:Home:1:publication-test`;
function analysisResponse(p: ConversationPlan) {
  return {
    plan: p,
    queryId: "q1",
    projectionId: null,
    text: "L’équipe 1 est à examiner, avec ses limites.",
    analysis: {
      text: "Analyse",
      selections: [{
        candidateId,
        reason: "La série à domicile soutient ce marché.",
        vigilance: "L’adversaire doit être examiné.",
        references: ["publication-test:strong_home_team:2"],
      }],
      observations: [],
      comparedMatchIds: ["football:1"],
      limitations: [],
    },
  };
}

Deno.test("conversation patches date, sports, size and odds without losing stake or return; clarification patches only its leaf", () => {
  let state = baseState();
  const changes: [Partial<Intent>, string[]][] = [
    [{ date: "2026-10-12" }, ["date"]],
    [{ sports: ["football", "hockey"] }, ["sports"]],
    [{ sports: ["football"] }, ["sports"]],
    [{ maxSelections: 5 }, ["maxSelections"]],
    [{ maxSelections: 2 }, ["maxSelections"]],
    [{ targetOdds: 3.5 }, ["targetOdds"]],
  ];
  for (const [patch, fields] of changes) {
    const resolved = resolvePlan(plan(patch, fields), state, context, date);
    assert.equal(resolved.tickets[0].stake, 50);
    assert.equal(resolved.tickets[0].minimum, 300);
    rememberTurn(state, structuredClone(state), resolved, [], []);
  }
  const final = state.conversation!.workingIntent;
  assert.equal(final.date, "2026-10-12");
  assert.deepEqual(final.sports, ["football"]);
  assert.equal(final.maxSelections, 2);
  assert.equal(final.targetOdds, 3.5);
  const answer = resolvePlan(
    plan({
      action: "generate",
      tickets: [{ stake: null, minimum: null, maximum: null, kind: "net" }],
    }, ["returnKind"]),
    state,
    context,
    date,
  );
  assert.deepEqual(answer.tickets, [{
    stake: 50,
    minimum: 300,
    maximum: null,
    kind: "net",
  }]);
  const stake = resolvePlan(
    plan({
      tickets: [{
        stake: 20,
        minimum: null,
        maximum: null,
        kind: "unspecified",
      }],
    }, ["stake"]),
    state,
    context,
    date,
  );
  assert.equal(stake.tickets[0].minimum, 300);
  assert.equal(stake.tickets[0].stake, 20);
  assert.equal(context.budget, 50);
});
Deno.test("new independent tasks reset constraints and focus; explicit old ticket references recover that object's constraints", async () => {
  const reader = new ConversationReader(input(baseState()), readPort());
  const projection = await reader.execute("read_composition_options", {
    plan: plan({ ...intent, targetOdds: null }, [], { focusMode: "clear" }),
  }) as any;
  const preview = reader.previews.get(projection.projectionId)!;
  const state = preview.next, ticket = state.tickets[0];
  assert.ok(ticket);
  state.intent = {
    ...intent,
    date: "2026-10-12",
    tickets: [{ stake: 10, minimum: null, maximum: null, kind: "total" }],
  };
  const resolved = resolvePlan(
    plan({ action: "alternative", referenceTicketId: ticket.id }),
    state,
    context,
    date,
  );
  assert.equal(resolved.date, date);
  assert.equal(resolved.tickets[0].stake, 50);
  const fresh = resolvePlan(
    plan({ sports: ["hockey"] }, ["sports"], {
      newTask: true,
      focusMode: "clear",
    }),
    state,
    context,
    "2026-10-13",
  );
  assert.equal(fresh.date, "2026-10-13");
  assert.deepEqual(fresh.tickets, []);
  assert.equal(fresh.fixtureFocus, undefined);
  assert.throws(
    () =>
      resolvePlan(
        plan({ referenceTicketId: "11111111-1111-4111-8111-111111111111" }),
        state,
        context,
        date,
      ),
    /session/,
  );
});
Deno.test("read capabilities reject mutations, SQL, URLs, user IDs, market overrides and out-of-scope identities before loading", async () => {
  let loads = 0;
  const reader = new ConversationReader(input(), {
    sources: async () => {
      loads++;
      return [source()];
    },
  });
  for (
    const name of [
      "execute_sql",
      "update_preferences",
      "save_ticket",
      "place_bet",
      "fetch",
      "delete_session",
      "constructor",
    ]
  ) {
    await assert.rejects(
      () =>
        reader.execute(name, {
          sql: "delete from profiles",
          userId: "another",
        }),
      /non autorisé/,
    );
  }
  for (
    const args of [{ userId: "another" }, { url: "https://example.test" }, {
      preferences: { markets: ["scorer"] },
    }]
  ) {
    await assert.rejects(
      () => reader.execute("read_profile", args),
      /non autorisés/,
    );
  }
  await assert.rejects(
    () =>
      reader.execute("search_matches", {
        ...search(),
        sql: "select * from auth.users",
      }),
    /non autorisés/,
  );
  await assert.rejects(
    () => reader.execute("search_matches", { ...search(), date: "2026-02-31" }),
    /invalide/,
  );
  await assert.rejects(
    () =>
      reader.execute("read_matches", {
        queryId: "q1",
        matchKeys: ["hockey:999"],
      }),
    /d’abord/,
  );
  assert.equal(loads, 0);
  assert.equal(
    conversationTools.every((t) =>
      t.strict && t.parameters.additionalProperties === false
    ),
    true,
  );
  const profile = await reader.execute("read_profile", {}) as any;
  profile.preferences.football.markets.push("forged");
  assert.ok(!context.preferences.football!.markets.includes("forged"));
});
Deno.test("queries page all matches, cache by day/sport/view and never silently fill an empty Radar from Tous", async () => {
  let loads = 0;
  const reader = new ConversationReader(input(), {
    sources: async (_context, _day, sports) => {
      loads++;
      assert.deepEqual(sports, ["football"]);
      return [source()];
    },
  });
  const page1 = await reader.execute("search_matches", {
    ...search(),
    limit: 2,
  }) as any;
  assert.equal(page1.total, 4);
  assert.equal(page1.hasMore, true);
  assert.equal(page1.matches.length, 2);
  const page2 = await reader.execute("search_matches", {
    ...search(),
    offset: 2,
    limit: 2,
  }) as any;
  assert.equal(page1.queryId, page2.queryId);
  assert.equal(loads, 1);
  assert.equal(page2.hasMore, false);
  assert.notEqual(page1.matches[0].key, page2.matches[0].key);
  const details = await reader.execute("read_matches", {
    queryId: page1.queryId,
    matchKeys: ["football:1"],
  }) as any;
  assert.equal(details[0].candidates[0].matchId, "api-fixture-1");
  await assert.rejects(
    () =>
      reader.execute("read_matches", {
        queryId: page1.queryId,
        matchKeys: ["football:999"],
      }),
    /périmètre/,
  );
  const radar = await reader.execute("search_matches", search("radar")) as any;
  assert.equal(radar.total, 0);
  assert.ok(radar.missing.length);
  assert.equal(loads, 2);
});
Deno.test("two sports may share a provider match ID without sharing facts or focus", async () => {
  const fixture = {
    ...quotedFixture,
    id: "1",
    startsAt: "2026-10-10T18:00:00Z",
  };
  const hockey: Source = {
    id: "hockey-source",
    sport: "hockey",
    capturedAt: now.toISOString(),
    payload: { items: [fixture] },
  };
  const reader = new ConversationReader(input(), {
    sources: async () => [source(), hockey],
  });
  const found = await reader.execute(
    "search_matches",
    search("all", ["football", "hockey"]),
  ) as any;
  assert.equal(
    found.matches.filter((m: any) => m.key.endsWith(":1")).length,
    2,
  );
  const details = await reader.execute("read_matches", {
    queryId: found.queryId,
    matchKeys: ["football:1", "hockey:1"],
  }) as any;
  assert.notEqual(details[0].home, details[1].home);
  assert.ok(details[0].candidates.every((c: any) => c.sport === "football"));
  assert.equal(matchKey("football", "api-fixture-1"), "football:1");
});
Deno.test("live and historical profile data stay readable without allowing prematch selections or substituting a different publication", async () => {
  const past = source();
  past.capturedAt = "2026-10-04T12:00:00Z";
  const fixtures = (past.payload.raw as any).fixtures;
  fixtures[0].fixture.date = "2026-10-05T18:00:00Z";
  fixtures[0].fixture.status.short = "FT";
  fixtures[1].fixture.date = "2026-10-08T11:00:00Z";
  fixtures[1].fixture.status.short = "2H";
  const reader = new ConversationReader(input(), {
    sources: async () => [past],
    matchData: async () => ({
      publication: {
        sport: "football",
        capturedAt: now.toISOString(),
        items: [{ id: "1" }],
      },
      live: { home_goals: 2, away_goals: 1, status: "FT" },
    }),
  });
  const found = await reader.execute(
    "search_matches",
    search("profile", ["football"], "2026-10-05"),
  ) as any;
  assert.equal(found.total, 1);
  assert.equal(found.matches[0].status, "FT");
  const details = await reader.execute("read_matches", {
    queryId: found.queryId,
    matchKeys: ["football:1"],
  }) as any;
  assert.equal(details[0].candidates.length, 0);
  assert.ok(details[0].evidence.length);
  const data = await reader.execute("read_match_data", {
    queryId: found.queryId,
    matchKey: "football:1",
  }) as any;
  assert.equal(data.data, null);
  assert.equal(data.live.home_goals, 2);
  assert.match(data.limitation, /diffère/);
  const live = await reader.execute(
    "search_matches",
    search("profile", ["football"], "2026-10-08"),
  ) as any;
  assert.equal(live.matches[0].status, "2H");
  assert.equal(reader.queries.get(live.queryId)!.catalog.candidates.length, 0);
});
Deno.test("a stake update may retain the same verified composition as a new proposal, while another ticket must differ", async () => {
  const firstReader = new ConversationReader(input(baseState()), readPort());
  const first = await firstReader.execute("read_composition_options", {
    plan: plan(
      {
        ...intent,
        tickets: [{ stake: 20, minimum: null, maximum: null, kind: "total" }],
        targetOdds: null,
      },
      ["tickets"],
      { focusMode: "clear" },
    ),
  }) as any;
  const state = firstReader.previews.get(first.projectionId)!.next;
  const old = state.tickets[0];
  assert.ok(old);
  const focus = old.picks.map((p) => ({
    sport: p.sport,
    matchId: p.matchId,
    match: `${p.home} — ${p.away}`,
  }));
  rememberTurn(state, null, state.intent!, focus, []);
  const updatedReader = new ConversationReader(
    input(state, "Même composition, mise 30 euros."),
    readPort(),
  );
  const changed = await updatedReader.execute("read_composition_options", {
    plan: plan({
      action: "generate",
      tickets: [{ stake: 30, minimum: null, maximum: null, kind: "total" }],
    }, ["stake"]),
  }) as any;
  assert.ok(changed.tickets.length);
  assert.equal(changed.tickets[0].stake, 30);
  assert.equal(state.tickets[0].stake, 20);
  assert.notEqual(changed.tickets[0].id, old.id);
  assert.deepEqual(
    changed.tickets[0].picks.map((p: any) => p.key).sort(),
    old.picks.map((p) => matchKey(p.sport, p.matchId)).sort(),
  );
  const alternative = await updatedReader.execute("read_composition_options", {
    plan: plan({ action: "alternative", referenceTicketId: old.id }),
  }) as any;
  const oldKeys = old.picks.map((p) =>
    `${matchKey(p.sport, p.matchId)}:${p.marketId}:${p.selection}`
  ).sort().join();
  assert.ok(
    alternative.tickets.every((t: any) =>
      t.picks.map((p: any) => `${p.key}:${p.marketId}:${p.selection}`).sort()
        .join() !== oldKeys
    ),
  );
});
Deno.test("a shorter follow-up chooses among retained matches rather than forcing every old match", async () => {
  const before = baseState({
    ...intent,
    goalMode: "unconstrained",
    tickets: [{ stake: 20, minimum: null, maximum: null, kind: "total" }],
  });
  const focus = [1, 2, 3, 4].map((n) => ({
    sport: "football" as const,
    matchId: `api-fixture-${n}`,
    match: `Équipe ${n}`,
  }));
  rememberTurn(before, null, before.intent!, focus, []);
  const reader = new ConversationReader(input(before), readPort());
  const beforeJson = JSON.stringify(before);
  const projected = await reader.execute("read_composition_options", {
    plan: plan({ action: "generate", maxSelections: 2 }, ["maxSelections"]),
  }) as any;
  assert.ok(projected.tickets.length);
  assert.ok(projected.tickets.every((t: any) => t.picks.length <= 2));
  assert.equal(JSON.stringify(before), beforeJson);
  assert.equal(projected.tickets[0].stake, 20);
});
Deno.test("independent odds goals guide verified search without inventing a stake or currency return", async () => {
  const before = baseState({
    ...intent,
    tickets: [{ stake: 20, minimum: null, maximum: null, kind: "unspecified" }],
  });
  const reader = new ConversationReader(input(before), readPort());
  const projected = await reader.execute("read_composition_options", {
    plan: plan({ action: "generate", targetOdds: 3.5, maxSelections: 2 }, [
      "targetOdds",
      "maxSelections",
    ], { focusMode: "clear" }),
  }) as any;
  assert.ok(projected.tickets.length);
  assert.ok(
    projected.tickets.every((t: any) =>
      t.totalOdds >= 3.15 && t.totalOdds <= 3.85
    ),
  );
  assert.equal(projected.intent.tickets[0].minimum, null);
  assert.equal(projected.intent.tickets[0].stake, 20);
  const noStake = new ConversationReader(input(), readPort());
  const clarification = await noStake.execute("read_composition_options", {
    plan: plan(
      {
        action: "generate",
        targetOdds: 3.5,
        tickets: [{
          stake: null,
          minimum: null,
          maximum: null,
          kind: "unspecified",
        }],
      },
      ["tickets", "targetOdds"],
      { newTask: true, focusMode: "clear" },
    ),
  }) as any;
  assert.equal(clarification.tickets.length, 0);
  assert.match(clarification.clarification, /mise/);
});
Deno.test("natural analysis then stake clarification then ticket preserves chosen football matches through the generic agent loop", async () => {
  const p = plan({ action: "analyze", maxSelections: 2 }, ["maxSelections"], {
    newTask: true,
    focusMode: "clear",
  });
  let calls = 0;
  const requests: any[] = [], receipts: ModelReceipt[] = [];
  const state = (await converse(input(), {
    key: "test",
    model: "gpt-6.1-sol",
    reads: readPort(),
    onReceipt: (r) => receipts.push(r),
    fetcher: (async (_url, init) => {
      const body = JSON.parse(String(init?.body));
      requests.push(body);
      calls++;
      assert.equal(body.store, false);
      assert.deepEqual(body.include, ["reasoning.encrypted_content"]);
      if (calls === 1) {
        return result([{
          type: "reasoning",
          encrypted_content: "opaque-test",
          summary: [],
        }, toolCall("search_matches", search())]);
      }
      if (calls === 2) {
        return result([
          toolCall("read_matches", {
            queryId: "q1",
            matchKeys: ["football:1"],
          }),
        ]);
      }
      return result([output(analysisResponse(p))]);
    }) as typeof fetch,
  })).next;
  assert.equal(receipts.length, 3);
  assert.ok(
    requests[1].input.some((m: any) => m.encrypted_content === "opaque-test"),
  );
  assert.ok(!JSON.stringify(state).includes("opaque-test"));
  assert.deepEqual(knownFocus(state).map((m) => m.matchId), ["api-fixture-1"]);
  assert.equal(state.messages.at(-1)!.analysis!.selections.length, 1);
  const clarifyPlan = plan({
    action: "clarify",
    message: "Quelle mise souhaitez-vous prévoir ?",
  });
  const clarified =
    (await converse(input(state, "Compose avec les rencontres retenues."), {
      key: "test",
      model: "gpt-6.1-sol",
      reads: readPort(),
      fetcher: (async () =>
        result([
          output({
            plan: clarifyPlan,
            text: "Quelle mise souhaitez-vous prévoir ?",
            analysis: null,
            queryId: null,
            projectionId: null,
          }),
        ])) as typeof fetch,
    })).next;
  assert.deepEqual(knownFocus(clarified), knownFocus(state));
  const ticketPlan = plan({
    action: "generate",
    tickets: [{ stake: 20, minimum: null, maximum: null, kind: "unspecified" }],
  }, ["stake"]);
  let rounds = 0;
  const generated =
    (await converse(input(clarified, "Vingt euros pour celui-ci."), {
      key: "test",
      model: "gpt-6.1-sol",
      reads: readPort(),
      fetcher: (async (_url, init) => {
        const body = JSON.parse(String(init?.body));
        rounds++;
        assert.ok(
          body.input.some((m: any) =>
            m.role === "assistant" && String(m.content).includes("Quelle mise")
          ),
        );
        if (rounds === 1) {
          return result([
            toolCall("read_composition_options", { plan: ticketPlan }),
          ]);
        }
        const toolOutput = JSON.parse(
          body.input.findLast((m: any) => m.type === "function_call_output")
            .output,
        );
        assert.ok(toolOutput.tickets.length);
        assert.equal(toolOutput.tickets[0].picks[0].matchId, "api-fixture-1");
        return result([
          output({
            // JSON property ordering cannot change the meaning of a validated projection.
            plan: {
              ...ticketPlan,
              intent: Object.fromEntries(
                Object.entries({
                  ...ticketPlan.intent,
                  message: "Même exécution avec une explication reformulée.",
                }).reverse(),
              ),
            },
            text: "Voici la composition calculée sur la rencontre retenue.",
            analysis: null,
            queryId: null,
            projectionId: toolOutput.projectionId,
          }),
        ]);
      }) as typeof fetch,
    })).next;
  assert.equal(generated.tickets[0].stake, 20);
  assert.deepEqual(generated.tickets[0].picks.map((p) => p.matchId), [
    "api-fixture-1",
  ]);
});
Deno.test("hockey analysis-to-ticket uses the same conversation memory and real regulation quotes", async () => {
  const hockeyContext: Context = {
    ...context,
    preferences: {
      hockey: {
        competitions: ["hockey:api-hockey:competition:35"],
        readings: ["winning_streak"],
        markets: ["result_regulation", "double_chance_regulation"],
      },
    },
  };
  const hockeySource: Source = {
    id: "hockey-source",
    sport: "hockey",
    capturedAt: quoteAt,
    payload: {
      items: [{
        ...quotedFixture,
        quotesCollectedAt: quoteAt,
        quotes: hockeyQuoteRecords(
          oddsPayload(),
          [quotedFixture],
          "35",
          "2026",
          quoteAt,
        )[0].quotes,
        readings: [{
          id: "winning_streak",
          subject_team_id: "2",
          sample_size: 3,
          explanation: "Trois victoires finales",
        }],
      }],
    },
  };
  const hockeyInput = {
    ...input(),
    date: "2026-10-09",
    today: "2026-10-09",
    now: new Date(quoteAt),
    context: hockeyContext,
  };
  const request = {
    ...initialIntent(hockeyContext, hockeyInput.date),
    sports: ["hockey" as const],
    maxSelections: 1,
  };
  let step = 0;
  const found = (await converse(hockeyInput, {
    key: "test",
    model: "gpt-6-luna",
    reads: { sources: async () => [hockeySource] },
    fetcher: (async (_url, init) => {
      const body = JSON.parse(String(init?.body));
      step++;
      if (step === 1) {
        return result([
          toolCall(
            "search_matches",
            search("profile", ["hockey"], hockeyInput.date),
          ),
        ]);
      }
      const key = matchKey("hockey", String(quotedFixture.id));
      if (step === 2) {
        return result([
          toolCall("read_matches", { queryId: "q1", matchKeys: [key] }),
        ]);
      }
      const facts = JSON.parse(
        body.input.findLast((m: any) => m.type === "function_call_output")
          .output,
      )[0];
      assert.ok(facts.candidates.length);
      const candidate = facts.candidates[0];
      return result([
        output({
          plan: plan(request, ["date", "sports", "maxSelections"], {
            newTask: true,
            focusMode: "clear",
          }),
          text: "Cette rencontre hockey est à examiner.",
          queryId: "q1",
          projectionId: null,
          analysis: {
            text: "Analyse",
            selections: [{
              candidateId: candidate.id,
              reason: "Série de victoires",
              vigilance: "Temps réglementaire uniquement",
              references: [candidate.evidence[0].id],
            }],
            observations: [],
            comparedMatchIds: [key],
            limitations: [],
          },
        }),
      ]);
    }) as typeof fetch,
  })).next;
  assert.equal(found.conversation!.focus[0].sport, "hockey");
  const reader = new ConversationReader({ ...hockeyInput, state: found }, {
    sources: async () => [hockeySource],
  });
  const projected = await reader.execute("read_composition_options", {
    plan: plan({
      action: "generate",
      tickets: [{
        stake: 20,
        minimum: null,
        maximum: null,
        kind: "unspecified",
      }],
    }, ["stake"]),
  }) as any;
  assert.ok(projected.tickets.length);
  assert.equal(projected.tickets[0].picks[0].sport, "hockey");
  assert.ok(
    ["result_regulation", "double_chance_regulation"].includes(
      projected.tickets[0].picks[0].marketId,
    ),
  );
  assert.equal(projected.tickets[0].picks[0].sport, "hockey");
});
Deno.test("failed tools are returned as read errors; invented tickets, details or changed projection constraints are rejected", async () => {
  let step = 0;
  const before = baseState(), frozen = JSON.stringify(before);
  const unsupported = plan({
    action: "unsupported",
    message: "Lecture seule.",
  });
  await converse(input(before, "Modifie mes marchés."), {
    key: "test",
    model: "gpt-6.1-sol",
    reads: {
      sources: async () => {
        throw new Error("Must not read");
      },
    },
    fetcher: (async (_url, init) => {
      step++;
      if (step === 1) {
        return result([toolCall("execute_sql", { query: "update profiles" })]);
      }
      const body = JSON.parse(String(init?.body));
      const denied = JSON.parse(
        body.input.findLast((m: any) => m.type === "function_call_output")
          .output,
      );
      assert.equal(denied.noMutation, true);
      assert.match(denied.error, /non autorisé/);
      return result([
        output({
          plan: unsupported,
          text: "Je peux consulter ces données, pas les modifier.",
          analysis: null,
          queryId: null,
          projectionId: null,
        }),
      ]);
    }) as typeof fetch,
  });
  assert.equal(JSON.stringify(before), frozen);
  await assert.rejects(
    () =>
      converse(input(), {
        key: "test",
        model: "gpt-6.1-sol",
        reads: readPort(),
        fetcher: (async () =>
          result([
            output({
              plan: plan({ action: "generate" }),
              text: "Ticket inventé",
              analysis: null,
              queryId: null,
              projectionId: null,
            }),
          ])) as typeof fetch,
      }),
    /calculé/,
  );
  const p = plan({ ...intent, action: "generate" }, [], { focusMode: "clear" });
  step = 0;
  await assert.rejects(
    () =>
      converse(input(baseState()), {
        key: "test",
        model: "gpt-6.1-sol",
        reads: readPort(),
        fetcher: (async (_url, init) => {
          if (++step === 1) {
            return result([toolCall("read_composition_options", { plan: p })]);
          }
          const body = JSON.parse(String(init?.body)),
            projected = JSON.parse(
              body.input.findLast((m: any) => m.type === "function_call_output")
                .output,
            );
          return result([
            output({
              plan: { ...p, changedFields: ["maxSelections"] },
              text: "Ticket",
              analysis: null,
              queryId: null,
              projectionId: projected.projectionId,
            }),
          ]);
        }) as typeof fetch,
      }),
    /contraintes examinées/,
  );
});
Deno.test("incomplete model output and cancellation leave the old session intact and record the paid receipt", async () => {
  const before = baseState(),
    frozen = JSON.stringify(before),
    receipts: ModelReceipt[] = [];
  await assert.rejects(
    () =>
      converse(input(before), {
        key: "test",
        model: "gpt-6.1-sol",
        reads: readPort(),
        onReceipt: (r) => receipts.push(r),
        fetcher: (async () => result([], "incomplete")) as typeof fetch,
      }),
    /fin/,
  );
  assert.equal(receipts[0].status, "incomplete");
  assert.equal(JSON.stringify(before), frozen);
  let calls = 0;
  await assert.rejects(
    () =>
      converse(input(before), {
        key: "test",
        model: "gpt-6.1-sol",
        reads: readPort(),
        onProgress: async () => {
          throw new Error("Interrupted");
        },
        fetcher: (async () => {
          calls++;
          return result([]);
        }) as typeof fetch,
      }),
    /Interrupted/,
  );
  assert.equal(calls, 0);
});
Deno.test("conversation ledger bounds long sessions while preserving exact active constraints and references", () => {
  let state = baseState();
  const focus = [{
    sport: "football" as const,
    matchId: "api-fixture-1",
    match: "A — B",
  }];
  for (let turn = 0; turn < 70; turn++) {
    const before = structuredClone(state);
    state.messages = [{ role: "user", text: "request".repeat(250) }, {
      role: "assistant",
      text: "response".repeat(400),
    }];
    rememberTurn(
      state,
      before,
      { ...intent, targetOdds: 3.5, maxSelections: 2 },
      focus,
      [],
    );
  }
  assert.ok(state.conversation!.olderTurns > 0);
  assert.ok(JSON.stringify(state).length < 210000);
  assert.equal(state.conversation!.workingIntent.tickets[0].stake, 50);
  assert.equal(state.conversation!.workingIntent.targetOdds, 3.5);
  assert.deepEqual(knownFocus(state), focus);
  assert.throws(
    () => validatePlan({ ...plan(), userId: "foreign" }),
    /invalide/,
  );
});
