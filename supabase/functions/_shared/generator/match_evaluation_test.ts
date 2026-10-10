import assert from "node:assert/strict";
import { ConversationReader, conversationTools } from "./conversation_tools.ts";
import { context, now } from "./evaluation_cases.ts";
import {
  evaluateMatches,
  evaluationConcurrency,
  evaluationSchema,
  prepareMatchSheets,
  validateEvaluations,
} from "./match_evaluation.ts";
import type { ModelReceipt } from "./models.ts";
import { obj } from "./contracts.ts";
import { largeQuery } from "./match_evaluation_cases.ts";

export const evaluationFor = (body: any) => ({
  evaluations: Object.fromEntries(
    JSON.parse(body.input).matches.map((m: any) => [m.key, {
      fit: m.facts.some((f: any) => f.text.includes("15/15"))
        ? 4
        : m.facts.length
        ? 1
        : 0,
      status: m.facts.length ? "supported" : "insufficient",
      candidate: m.candidates[0]?.citations[0] ?? null,
      references: m.candidates[0]?.direct.slice(0, 1) ??
        (m.facts[0] ? [m.facts[0].id] : []),
      vigilanceReferences: m.candidates[0]?.vigilance ?? [],
      reason: "Écart de forme documenté dans la fenêtre publiée.",
      limitations: [],
    }]),
  ),
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
      assert.ok(data.matches.length <= 12);
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
  assert.ok(maximum <= 24 && maximum > 1);
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
    candidate: `c0/f${
      s.facts.findIndex((f) => f.id === s.candidates[0].evidence[0].id)
    }`,
    references: [
      `f${s.facts.findIndex((f) => f.id === s.candidates[0].evidence[0].id)}`,
    ],
    vigilanceReferences: [],
    reason: "Fait cité",
    limitations: [],
  }));
  const responseRows = (rs: typeof good) => ({
    evaluations: Object.fromEntries(rs.map(({ key, ...row }) => [key, row])),
  });
  assert.equal(
    validateEvaluations(responseRows(good), sheets, now).length,
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
    assert.throws(() => validateEvaluations(responseRows(bad), sheets, now));
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
      modelResponse(responseRows(good.slice(1)))) as typeof fetch,
  });
  assert.equal(report.evaluated, 0);
  assert.equal(report.complete, false);
  assert.equal(report.failed[0].keys.length, 4);
});
Deno.test("constrained output ties each market choice to its explicitly cited direct proof; context facts cannot substitute for it", async () => {
  const { query } = await largeQuery(2),
    sheets = prepareMatchSheets(query, now);
  sheets[0].facts.push({
    ...sheets[0].facts[0],
    id: "context-only",
    supportsMarket: false,
    role: "context",
  });
  const schema = evaluationSchema(sheets, now);
  const alternatives = schema.properties.evaluations.properties;
  assert.deepEqual(schema.properties.evaluations.required, ["m0", "m1"]);
  assert.deepEqual(Object.keys(alternatives), ["m0", "m1"]);
  const contextCitation = `c0/f${sheets[0].facts.length - 1}`;
  assert.ok(
    !alternatives.m0.properties.candidate.enum.includes(contextCitation),
  );
  const body = {
    input: JSON.stringify({
      matches: sheets.map((s, i) => ({
        key: `m${i}`,
        facts: [{ id: "f0", text: "15/15" }],
        candidates: [{ citations: ["c0/f0"], direct: ["f0"], vigilance: [] }],
      })),
    }),
  };
  const valid = evaluationFor(body);
  valid.evaluations.m0.references = [];
  assert.ok(
    validateEvaluations(valid, sheets, now)[0].references.includes(
      sheets[0].facts[0].id,
    ),
  );
  valid.evaluations.m0.candidate = contextCitation;
  assert.throws(
    () => validateEvaluations(valid, sheets, now),
    /soutien direct/,
  );
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
  assert.deepEqual(
    reader.expandComparedKeys("q1", [report.comparisonReference]),
    ["football:1", "football:2", "football:3", "football:4"],
  );
  assert.throws(
    () => reader.expandComparedKeys("q2", [report.comparisonReference]),
    /étrangère/,
  );
  assert.throws(
    () => reader.expandComparedKeys("q1", ["evaluation:inconnue"]),
    /étrangère/,
  );
  assert.throws(() => reader.expandComparedKeys("q1", [42]), /invalides/);
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
Deno.test("resuming a failed batch preserves the original criterion and full coverage, pays only for missing matches and retains both audits", async () => {
  const { publication } = await largeQuery(26);
  const batches: number[] = [], criteria: string[] = [], audits: unknown[] = [];
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
      onEvaluation: async (report) => {
        audits.push(report);
      },
      fetcher: (async (_u, init) => {
        const body = JSON.parse(String(init?.body)),
          data = JSON.parse(body.input);
        batches.push(data.matches.length);
        criteria.push(data.criteria);
        const value = evaluationFor(body);
        if (batches.length === 1) value.evaluations.m0.references = ["f999"];
        return modelResponse(value);
      }) as typeof fetch,
    },
  );
  await reader.query("2026-10-10", ["football"], "profile", "teams");
  const first = await reader.execute("evaluate_matches", {
    queryId: "q1",
    criteria: "écart de forme",
    matchKeys: null,
  }) as any;
  assert.equal(first.coverage.evaluated, 26 - batches[0]);
  assert.equal(first.coverage.complete, false);
  const next = await reader.execute("continue_match_evaluation", {
    evaluationId: first.evaluationId,
  }) as any;
  assert.equal(next.coverage.expected, 26);
  assert.equal(next.coverage.evaluated, 26);
  assert.equal(next.coverage.complete, true);
  assert.equal(batches.at(-1), batches[0]);
  assert.equal(batches.reduce((a, b) => a + b, 0), 26 + batches[0]);
  assert.ok(criteria.every((c) => c === "écart de forme"));
  assert.equal(audits.length, 2);
  await reader.execute("continue_match_evaluation", {
    evaluationId: next.evaluationId,
  });
  assert.equal(batches.length, 4);
  await assert.rejects(
    () =>
      reader.execute("continue_match_evaluation", {
        evaluationId: first.evaluationId,
        sql: "select *",
      }),
    /non autorisés/,
  );
  assert.equal(reader.detailsRead.size, 26);
  const cached = await reader.execute("evaluate_matches", {
    queryId: "q1",
    criteria: "écart de forme",
    matchKeys: null,
  }) as any;
  assert.equal(cached.coverage.evaluated, 26);
  assert.equal(batches.length, 4);
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
  assert.ok(calls <= 24);
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
  let round = 0, largestRequest = 0;
  const call = (name: string, args: unknown) =>
    Response.json({
      status: "completed",
      model: "gpt-6-luna",
      output: [
        ...(name === "search_matches"
          ? [{
            type: "reasoning",
            id: "synthetic-replay",
            summary: [],
            encrypted_content: "x".repeat(310000),
          }]
          : []),
        {
          type: "function_call",
          call_id: name,
          name,
          arguments: JSON.stringify(args),
        },
      ],
    });
  let comparisonReference = "";
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
      largestRequest = Math.max(largestRequest, String(init?.body).length);
      round++;
      assert.equal(b.parallel_tool_calls, true);
      assert.equal(b.reasoning.effort, round === 2 ? "low" : "medium");
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
        comparisonReference = data.comparisonReference;
        assert.match(comparisonReference, /^evaluation:/);
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
          comparedMatchIds: [comparisonReference],
          limitations: [],
        },
      });
    }) as typeof fetch,
  });
  assert.equal(answer.evaluations[0].evaluated, 500);
  assert.equal(
    answer.next.messages.at(-1)?.analysis?.comparedMatchIds.length,
    500,
  );
  assert.ok(largestRequest > 380000 && largestRequest < 1200000);
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

Deno.test("persisted exact evaluations avoid paid calls; changed criteria, data, model and expired entries miss", async () => {
  const { query } = await largeQuery();
  query.matches = query.matches.slice(0, 2);
  let calls = 0;
  const options = {
    key: "test",
    model: "gpt-6-luna",
    fetcher: (async (_url, init) => {
      calls++;
      return modelResponse(evaluationFor(JSON.parse(String(init?.body))));
    }) as typeof fetch,
  };
  const input = {
    id: "cached",
    query,
    criteria: "Écart de forme",
    now,
    deadline: performance.now() + 10000,
  };
  const first = await evaluateMatches(input, options);
  assert.equal(first.complete, true);
  const count = calls;
  const second = await evaluateMatches(
    { ...input, cachedReports: [first] },
    options,
  );
  assert.equal(calls, count);
  assert.equal(second.reused, 2);
  assert.equal(second.batches, 0);
  assert.deepEqual(second.rows, first.rows);
  const reusedLater = await evaluateMatches({
    ...input,
    now: new Date(now.getTime() + 240000),
    cachedReports: [second],
  }, options);
  assert.equal(reusedLater.reused, 2);
  assert.deepEqual(reusedLater.cache?.evaluatedAt, first.cache?.evaluatedAt);
  const noRenewal = await evaluateMatches({
    ...input,
    now: new Date(now.getTime() + 300000),
    cachedReports: [reusedLater],
  }, options);
  assert.equal(noRenewal.reused, 0);
  const changed = await evaluateMatches({
    ...input,
    criteria: "Autre critère",
    cachedReports: [first],
  }, options);
  assert.equal(changed.reused, 0);
  const expired = await evaluateMatches({
    ...input,
    now: new Date(now.getTime() + 300000),
    cachedReports: [first],
  }, options);
  assert.equal(expired.reused, 0);
  const model = await evaluateMatches({
    ...input,
    cachedReports: [{ ...first, model: "gpt-6.1-sol" }],
  }, options);
  assert.equal(model.reused, 0);
  const altered = structuredClone(query);
  altered.matches[0].status = "changed";
  const data = await evaluateMatches({
    ...input,
    query: altered,
    cachedReports: [first],
  }, options);
  assert.equal(data.reused, 1);
});

Deno.test("evaluation concurrency is bounded without requiring environment permissions", () => {
  assert.equal(evaluationConcurrency(), 24);
  assert.equal(evaluationConcurrency(48), 48);
  assert.equal(evaluationConcurrency(96), 96);
  assert.equal(evaluationConcurrency(500), 96);
  for (const value of [0, -1, 1.5, NaN, Infinity]) {
    assert.equal(evaluationConcurrency(value), 24);
  }
});
