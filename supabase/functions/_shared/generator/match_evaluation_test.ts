import assert from "node:assert/strict";
import { ConversationReader, conversationTools } from "./conversation_tools.ts";
import { context, now } from "./evaluation_cases.ts";
import {
  evaluateMatches,
  prepareMatchSheets,
  validateEvaluations,
} from "./match_evaluation.ts";
import type { ModelReceipt } from "./models.ts";
import { obj } from "./contracts.ts";
import { largeQuery } from "./match_evaluation_cases.ts";

export const evaluationFor = (body: any) => ({
  evaluations: JSON.parse(body.input).matches.map((m: any) => ({
    key: m.key,
    fit: m.facts.some((f: any) => f.text.includes("15/15"))
      ? 4
      : m.facts.length
      ? 1
      : 0,
    status: m.facts.length ? "supported" : "insufficient",
    candidate: m.candidates[0]?.id ?? null,
    references: m.candidates[0]?.direct.slice(0, 1) ??
      (m.facts[0] ? [m.facts[0].id] : []),
    vigilanceReferences: m.candidates[0]?.vigilance ?? [],
    reason: "Écart de forme documenté dans la fenêtre publiée.",
    limitations: [],
  })),
});
export const modelResponse = (value: unknown) =>
  Response.json({
    id: "synthetic",
    model: "gpt-6-luna",
    status: "completed",
    usage: { input_tokens: 120, output_tokens: 180 },
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(value) }],
    }],
  });

Deno.test("all 500 sheets are evaluated with bounded concurrency, local aliases and no initial shortlist; late best matches survive", async () => {
  const { query } = await largeQuery();
  const receipts: ModelReceipt[] = [];
  let active = 0, maximum = 0, calls = 0;
  const report = await evaluateMatches({
    id: "e1",
    query,
    criteria: "Grand écart de forme",
    now,
    deadline: performance.now() + 10000,
  }, {
    key: "test",
    model: "gpt-6-luna",
    onReceipt: (r) => receipts.push(r),
    fetcher: (async (url, init) => {
      assert.equal(url, "https://api.openai.com/v1/responses");
      const body = JSON.parse(String(init?.body));
      assert.ok(String(init?.body).length < 48000);
      assert.equal(body.store, false);
      assert.equal(body.reasoning.effort, "low");
      const data = JSON.parse(body.input);
      assert.ok(data.matches.length <= 24);
      assert.ok(!body.input.includes("publication-test"));
      calls++;
      maximum = Math.max(maximum, ++active);
      await new Promise((r) => setTimeout(r, 1));
      active--;
      return modelResponse(evaluationFor(body));
    }) as typeof fetch,
  });
  assert.equal(report.expected, 500);
  assert.equal(report.evaluated, 500);
  assert.equal(report.complete, true);
  assert.equal(new Set(report.rows.map((r) => r.key)).size, 500);
  assert.deepEqual(
    report.rows.filter((r) => r.fit === 4).map((r) => r.key),
    [495, 496, 497, 498, 499, 500].map((i) => `football:${i}`),
  );
  assert.ok(maximum <= 8 && maximum > 1);
  assert.ok(calls > 1);
  assert.equal(receipts.length, calls);
  assert.ok(receipts.every((r) => r.evaluationBatch?.keys.length));
});
Deno.test("missing, duplicate, invented references and unrelated markets invalidate a whole batch rather than inflate coverage", async () => {
  const { query } = await largeQuery(4),
    sheets = prepareMatchSheets(query, now);
  const good = sheets.map((s, i) => ({
    key: `m${i}`,
    fit: 3,
    status: "supported",
    candidate: "c0",
    references: [
      `f${s.facts.findIndex((f) => f.id === s.candidates[0].evidence[0].id)}`,
    ],
    vigilanceReferences: [],
    reason: "Fait cité",
    limitations: [],
  }));
  assert.equal(
    validateEvaluations({ evaluations: good }, sheets, now).length,
    4,
  );
  for (
    const bad of [
      good.slice(1),
      [...good.slice(0, 3), good[0]],
      good.map((r) => ({ ...r, references: ["f999"] })),
      good.map((r) => ({ ...r, candidate: "c99" })),
    ]
  ) {
    assert.throws(() => validateEvaluations({ evaluations: bad }, sheets, now));
  }
  const report = await evaluateMatches({
    id: "e1",
    query,
    criteria: "forme",
    now,
    deadline: performance.now() + 10000,
  }, {
    key: "test",
    model: "gpt-6-luna",
    fetcher: (async () =>
      modelResponse({ evaluations: good.slice(1) })) as typeof fetch,
  });
  assert.equal(report.evaluated, 0);
  assert.equal(report.complete, false);
  assert.equal(report.failed[0].keys.length, 4);
});
Deno.test("no price, no data and elapsed deadlines remain distinct from a full evaluation", async () => {
  const { query } = await largeQuery(4);
  query.catalog.candidates = [];
  query.catalog.matches = [];
  assert.ok(
    prepareMatchSheets(query, now).every((s) =>
      !s.facts.length && !s.candidates.length
    ),
  );
  let calls = 0;
  const report = await evaluateMatches({
    id: "e1",
    query,
    criteria: "forme",
    now,
    deadline: performance.now() - 1,
  }, {
    key: "test",
    model: "gpt-6-luna",
    fetcher: (async () => {
      calls++;
      throw Error("unexpected");
    }) as typeof fetch,
  });
  assert.equal(calls, 0);
  assert.equal(report.evaluated, 0);
  assert.equal(report.expected, 4);
  assert.equal(report.complete, false);
});
Deno.test("tool scope rejects forged keys and writes, caches the exact criterion, and exposes paged audit without another paid call", async () => {
  const { publication } = await largeQuery(4);
  let calls = 0;
  const reader = new ConversationReader(
    {
      context,
      date: "2026-10-10",
      state: null,
      now,
      id: "t",
      message: "forme",
    },
    { sources: async () => [publication] },
    async () => {},
    {
      key: "test",
      model: "gpt-6-luna",
      deadline: performance.now() + 10000,
      fetcher: (async (_u, init) => {
        calls++;
        return modelResponse(evaluationFor(JSON.parse(String(init?.body))));
      }) as typeof fetch,
    },
  );
  await reader.query("2026-10-10", ["football"], "profile", "teams");
  await assert.rejects(
    () =>
      reader.execute("evaluate_matches", {
        queryId: "q1",
        criteria: "forme",
        matchKeys: ["hockey:1"],
      }),
    /périmètre/,
  );
  await assert.rejects(
    () =>
      reader.execute("evaluate_matches", {
        queryId: "q1",
        criteria: "forme",
        matchKeys: null,
        sql: "select",
      }),
    /non autorisés/,
  );
  const args = { queryId: "q1", criteria: "forme", matchKeys: null };
  const report = await reader.execute("evaluate_matches", args) as any;
  assert.equal(report.coverage.complete, true);
  assert.equal(reader.detailsRead.size, 4);
  await reader.execute("evaluate_matches", args);
  assert.equal(calls, 1);
  const audit = await reader.execute("read_match_evaluations", {
    evaluationId: report.evaluationId,
    offset: 2,
    limit: 2,
  }) as any;
  assert.equal(audit.rows.length, 2);
  assert.equal(audit.nextOffset, null);
  assert.equal(calls, 1);
  assert.ok(
    conversationTools.every((t) =>
      t.strict && t.parameters.additionalProperties === false
    ),
  );
});
Deno.test("published histories are deduplicated and exclude future results, preserving a declared window without inventing hockey points", async () => {
  const { query } = await largeQuery(1);
  obj(query.sources[0].payload.raw).recent_league_matches = [{
    team: { id: 2, name: "Home" },
    matches: [
      {
        fixture: { id: 8 },
        date: "2026-10-01T12:00:00Z",
        result: "W",
        venue: "home",
      },
      {
        fixture: { id: 8 },
        date: "2026-10-01T12:00:00Z",
        result: "W",
        venue: "home",
      },
      {
        fixture: { id: 9 },
        date: "2026-10-09T12:00:00Z",
        result: "W",
        venue: "home",
      },
    ],
  }];
  const f = prepareMatchSheets(query, now)[0].facts.find((f) =>
    f.id.includes("published_form")
  )!;
  assert.equal(f.sample, 1);
  assert.ok(f.text.includes("1 rencontres"));
  assert.equal(f.supportsMarket, false);
});
Deno.test("same numeric match in two sports keeps disjoint facts, candidates and audit identities", async () => {
  const { query } = await largeQuery(2);
  query.matches[1] = {
    ...query.matches[1],
    key: "hockey:1",
    id: "1",
    sport: "hockey",
    sourceId: "hockey-source",
  };
  for (
    const c of query.catalog.candidates.filter((c) =>
      c.matchId === "api-fixture-2"
    )
  ) {
    c.sport = "hockey";
    c.matchId = "1";
    c.id = `hockey-${c.id}`;
    for (const f of c.evidence) f.id = `hockey-${f.id}`;
  }
  query.catalog.matches = query.catalog.matches?.map((m) =>
    m.id === "api-fixture-2" ? { ...m, sport: "hockey", id: "1" } : m
  );
  const result = await evaluateMatches({
    id: "e1",
    query,
    criteria: "forme",
    now,
    deadline: performance.now() + 10000,
  }, {
    key: "test",
    model: "gpt-6-luna",
    fetcher: (async (_u, init) =>
      modelResponse(
        evaluationFor(JSON.parse(String(init?.body))),
      )) as typeof fetch,
  });
  assert.equal(result.complete, true);
  assert.deepEqual(result.rows.map((r) => r.key), ["football:1", "hockey:1"]);
  assert.ok(result.rows[1].references.every((id) => id.startsWith("hockey-")));
});
Deno.test("cancelling progress aborts every active batch and does not keep launching paid requests", async () => {
  const { query } = await largeQuery(250);
  let calls = 0, aborted = 0;
  await assert.rejects(
    () =>
      evaluateMatches({
        id: "e1",
        query,
        criteria: "forme",
        now,
        deadline: performance.now() + 10000,
        onProgress: async (n) => {
          if (n) throw Error("cancelled by user");
        },
      }, {
        key: "test",
        model: "gpt-6-luna",
        fetcher: (async (_u, init) => {
          const n = ++calls;
          if (n === 1) {
            return modelResponse(evaluationFor(JSON.parse(String(init?.body))));
          }
          if (init?.signal?.aborted) {
            aborted++;
            throw Error("aborted");
          }
          return await new Promise<Response>((_resolve, reject) => {
            init?.signal?.addEventListener("abort", () => {
              aborted++;
              reject(Error("aborted"));
            }, { once: true });
          });
        }) as typeof fetch,
      }),
    /cancelled/,
  );
  assert.ok(calls <= 8);
  assert.equal(aborted, calls - 1);
});
Deno.test("conversation compares all 500 evaluations before selecting six late matches and retains the audit", async () => {
  const { publication } = await largeQuery(500);
  const { converse } = await import("./conversation.ts");
  const { initialIntent } = await import("./conversation_memory.ts");
  const p = {
    intent: {
      ...initialIntent(context, "2026-10-10"),
      action: "analyze",
      maxSelections: 6,
    },
    changedFields: ["maxSelections"],
    newTask: true,
    focusMode: "choose",
    focusKeys: [495, 496, 497, 498, 499, 500].map((i) => `football:${i}`),
  };
  let round = 0;
  const call = (name: string, args: unknown) =>
    Response.json({
      status: "completed",
      model: "gpt-6-luna",
      output: [
        {
          type: "function_call",
          call_id: name,
          name,
          arguments: JSON.stringify(args),
        },
      ],
    });
  const answer = await converse({
    context,
    date: "2026-10-10",
    today: "2026-10-08",
    now,
    state: null,
    message: "Six plus grands écarts de forme sur tous les matchs de samedi",
    id: "33333333-3333-4333-8333-333333333333",
  }, {
    key: "test",
    model: "gpt-6-luna",
    reads: { sources: async () => [publication] },
    fetcher: (async (_u, init) => {
      const b = JSON.parse(String(init?.body));
      if (b.text.format.name === "lector_match_evaluations") {
        return modelResponse(evaluationFor(b));
      }
      round++;
      if (round === 1) {
        return call("search_matches", {
          date: "2026-10-10",
          sports: ["football"],
          view: "profile",
          radarKind: "teams",
          query: null,
          offset: 0,
          limit: 20,
        });
      }
      if (round === 2) {
        return call("evaluate_matches", {
          queryId: "q1",
          criteria: "grand écart de forme",
          matchKeys: null,
        });
      }
      const data = JSON.parse(
        b.input.findLast((v: any) => v.type === "function_call_output").output,
      );
      if (round === 3) {
        assert.equal(data.evaluations.length, 500);
        assert.equal(data.coverage.complete, true);
        return call("read_matches", { queryId: "q1", matchKeys: p.focusKeys });
      }
      assert.equal(data.length, 6);
      return modelResponse({
        plan: p,
        text:
          "Les six écarts les plus nets ont été comparés à l’ensemble des fiches.",
        queryId: "q1",
        projectionId: null,
        analysis: {
          text: "Six rencontres",
          selections: data.map((m: any) => ({
            candidateId: m.candidates[0].id,
            reason: "Écart de forme élevé.",
            vigilance: "Échantillon récent, pas de garantie.",
            references: m.candidates[0].assessment.directReferences,
          })),
          observations: [],
          comparedMatchIds: Array.from(
            { length: 500 },
            (_, i) => `football:${i + 1}`,
          ),
          limitations: [],
        },
      });
    }) as typeof fetch,
  });
  assert.equal(answer.evaluations[0].evaluated, 500);
  assert.equal(answer.next.messages.at(-1)?.analysis?.selections.length, 6);
  assert.equal(
    answer.next.messages.at(-1)?.analysis?.context.evaluation?.complete,
    true,
  );
  assert.equal(round, 4);
});
Deno.test("a later message reads the owned archived evaluation without paying or consulting a new publication", async () => {
  const { query } = await largeQuery(2);
  const report = await evaluateMatches({
    id: "33333333-3333-4333-8333-333333333333",
    query,
    criteria: "forme",
    now,
    deadline: performance.now() + 10000,
  }, {
    key: "test",
    model: "gpt-6-luna",
    fetcher: (async (_u, init) =>
      modelResponse(
        evaluationFor(JSON.parse(String(init?.body))),
      )) as typeof fetch,
  });
  let reads = 0;
  const reader = new ConversationReader({
    context,
    date: "2026-10-10",
    state: null,
    now,
    id: "owned-session",
    message: "Pourquoi ce choix ?",
  }, {
    sources: async () => {
      throw Error("unexpected source read");
    },
    evaluation: async (id) => {
      reads++;
      assert.equal(id, "latest");
      return report;
    },
  });
  const page = await reader.execute("read_match_evaluations", {
    evaluationId: "latest",
    offset: 0,
    limit: 1,
  }) as any;
  assert.equal(page.rows.length, 1);
  assert.equal(page.nextOffset, 1);
  assert.equal(page.scope.date, "2026-10-10");
  await assert.rejects(
    () =>
      reader.execute("read_match_evaluations", {
        evaluationId: "select * from users",
        offset: 0,
        limit: 1,
      }),
    /invalide/,
  );
  assert.equal(reads, 1);
  assert.equal(reader.queries.size, 0);
});
