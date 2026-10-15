import assert from "node:assert/strict";
import {
  evaluateFixture,
  explorationDay,
  modelResponse,
} from "./exploration_cases.ts";
import { now } from "./evaluation_cases.ts";
import { evaluateMatches, prepareMatchSheets } from "./match_evaluation.ts";
import {
  buildExplorationReport,
  explainExplorationChoice,
  explorationCriterion,
  hashCriterion,
} from "./exploration.ts";
import { ExplorationBudget } from "./exploration_budget.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { obj } from "./contracts.ts";
import { mixedDay } from "./match_evaluation_cases.ts";

Deno.test("80 matches without any odds produce ten justified observations, including late best cases, with no detailed read", async () => {
  const { query, criterion } = await explorationDay();
  const sheets = prepareMatchSheets(query, now, criterion);
  assert.equal(query.catalog.candidates.length, 0);
  assert.ok(
    sheets.every((s) =>
      !s.candidates.length && s.form?.home.results.length === 5
    ),
  );
  let calls = 0;
  const budget = new ExplorationBudget();
  const report = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    criteria: criterion.criteria,
    exploration: criterion,
    budget,
    now,
    deadline: performance.now() + 10000,
  }, {
    model: "gpt-6-luna",
    key: "test",
    fetcher: (async (_u, init) => {
      calls++;
      const body = JSON.parse(String(init?.body)),
        data = JSON.parse(body.input);
      assert.ok(data.matches.every((m: any) => !m.candidates.length));
      assert.ok(data.matches.length <= 12);
      return modelResponse(evaluateFixture(body));
    }) as typeof fetch,
  });
  const audit = report.exploration!;
  assert.deepEqual(audit.coverage, {
    expected: 80,
    evaluated: 80,
    insufficient: 0,
    failed: 0,
    reused: 0,
    complete: true,
  });
  assert.equal(audit.selectedKeys.length, 10);
  assert.deepEqual(
    audit.selectedKeys.slice(0, 6),
    [75, 76, 77, 78, 79, 80].map((id) => `football:${id}`),
  );
  assert.ok(audit.selectedKeys.every((key) => audit.evidence[key].length));
  assert.ok(report.rows.every((r) => r.candidateId === null));
  assert.equal(report.budgetUsage!.deepened, 0);
  assert.equal(report.budgetUsage!.evaluationCalls, calls);
  console.log(
    JSON.stringify({
      corpus: "controlled-80-no-odds",
      expected: report.expected,
      evaluated: report.evaluated,
      retained: audit.selectedKeys.length,
      batches: calls,
      elapsedMs: report.elapsedMs,
      deepened: 0,
      paidCalls: 0,
    }),
  );
});

Deno.test("ranking is reproducible after input permutation; reserves and stable ties are explicit; explanations use the original snapshot", async () => {
  const { query, criterion } = await explorationDay(16, true);
  const sheets = prepareMatchSheets(query, now, criterion);
  assert.ok(sheets.every((s) => !s.candidates.length));
  const report = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    criteria: criterion.criteria,
    exploration: criterion,
    now,
    deadline: performance.now() + 10000,
  }, {
    model: "gpt-6-luna",
    key: "test",
    fetcher: (async (_u, init) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(init?.body))),
      )) as typeof fetch,
  });
  report.rows.forEach((r) => {
    r.fit = 2;
  });
  report.rows[0].status = "mixed";
  report.rows[0].vigilanceReferences = [sheets[0].facts.at(-1)!.id];
  report.exploration = await buildExplorationReport(
    report,
    sheets,
    criterion,
    now,
  );
  const permuted = await buildExplorationReport(
    { ...report, rows: [...report.rows].reverse() },
    [...sheets].reverse(),
    criterion,
    now,
  );
  assert.deepEqual(permuted, report.exploration);
  assert.equal(report.exploration.rankedKeys.at(-1), "football:1");
  assert.equal(
    report.exploration.decisions.find((d) => d.key === "football:9")?.reason,
    "stable_tie_break",
  );
  const explanation = explainExplorationChoice(report, "football:9");
  assert.equal(
    explanation.evidence[0].id,
    report.rows.find((r) => r.key === "football:9")!.references[0],
  );
  assert.throws(
    () => explainExplorationChoice(report, "hockey:9"),
    /hors exploration/,
  );
  sheets[0].facts[0].text = "Changed source after initial evaluation";
  assert.ok(
    !explainExplorationChoice(report, "football:1").evidence[0].text.includes(
      "Changed source",
    ),
  );
  const forged = structuredClone(report);
  forged.rows[0].references = ["foreign"];
  await assert.rejects(
    buildExplorationReport(forged, sheets, criterion, now),
    /Preuve/,
  );
  const missing = structuredClone(report);
  missing.rows.pop();
  missing.evaluated--;
  missing.complete = false;
  await assert.rejects(
    buildExplorationReport(missing, sheets, criterion, now),
    /Manifeste/,
  );
});

Deno.test("62/80 coverage and only eight defensible matches remain partial with no fabricated completion", async () => {
  const { query, criterion } = await explorationDay();
  const sheets = prepareMatchSheets(query, now, criterion);
  const report = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    criteria: criterion.criteria,
    exploration: criterion,
    now,
    deadline: performance.now() + 10000,
  }, {
    model: "gpt-6-luna",
    key: "test",
    fetcher: (async (_u, init) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(init?.body))),
      )) as typeof fetch,
  });
  report.rows = report.rows.slice(0, 62).map((r, i) =>
    i < 8 ? r : ({
      ...r,
      fit: 0,
      status: "insufficient",
      references: [],
      reason: "Informations insuffisantes.",
    })
  );
  report.evaluated = 62;
  report.complete = false;
  report.failed = [{
    keys: sheets.slice(62).map((s) => s.key),
    reason: "Controlled interrupted batch",
  }];
  report.exploration = await buildExplorationReport(
    report,
    sheets,
    criterion,
    now,
  );
  assert.deepEqual(report.exploration.coverage, {
    expected: 80,
    evaluated: 62,
    failed: 18,
    insufficient: 54,
    reused: 0,
    complete: false,
  });
  assert.equal(report.exploration.selectedKeys.length, 8);
  assert.equal(
    report.exploration.decisions.filter((d) => d.reason === "not_evaluated")
      .length,
    18,
  );
  assert.ok(report.exploration.limitations.some((l) => l.includes("62/80")));
  assert.ok(report.exploration.limitations.some((l) => l.includes("8/10")));
});

Deno.test("profile-only readings, form scope and independent observation count are validated; exact grades are reused for a smaller top", async () => {
  const { query, criterion } = await explorationDay(12);
  query.context.preferences.football!.readings = ["positive_streak"];
  const narrowed = explorationCriterion({
    request: criterion.originalRequest,
    criteria: criterion.criteria,
    query,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  });
  const sheets = prepareMatchSheets(query, now, narrowed);
  assert.ok(
    sheets.every((s) =>
      s.facts.filter((f) => f.source === "reading").every((f) =>
        f.id.includes(":positive_streak:")
      )
    ),
  );
  let calls = 0;
  const options = {
    model: "gpt-6-luna",
    key: "test",
    fetcher: (async (_u, init) => {
      calls++;
      return modelResponse(evaluateFixture(JSON.parse(String(init?.body))));
    }) as typeof fetch,
  };
  const args = {
    id: crypto.randomUUID(),
    query,
    criteria: narrowed.criteria,
    exploration: narrowed,
    now,
    deadline: performance.now() + 10000,
  };
  const original = await evaluateMatches(args, options);
  const second = await evaluateMatches({
    ...args,
    id: crypto.randomUUID(),
    exploration: { ...narrowed, observationCount: 8 },
    cachedReports: [original],
  }, options);
  assert.equal(second.reused, 12);
  assert.equal(second.batches, 0);
  assert.equal(second.exploration!.selectedKeys.length, 8);
  assert.equal(calls, original.batches);
  assert.equal(
    await hashCriterion(narrowed),
    second.exploration!.criterionHash,
  );
  const changed = await evaluateMatches({
    ...args,
    exploration: { ...narrowed, formScope: "competition" },
    cachedReports: [original],
  }, options);
  assert.equal(changed.reused, 0);
  assert.throws(
    () =>
      explorationCriterion({
        request: "x",
        criteria: "y",
        query,
        observationCount: 0,
        useProfileReadings: true,
        formScope: "competition",
      }),
    /invalide/,
  );
});

Deno.test("reader admits only four justified detailed reads, transports cancellation and returns paginated archive without regrading", async () => {
  const { publication, context } = await explorationDay(12);
  let calls = 0, details = 0;
  const reader = new ConversationReader(
    {
      context,
      date: "2026-10-10",
      now,
      state: null,
      id: "test",
      message: "Compare ces douze rencontres",
    },
    {
      sources: async () => [publication],
      matchData: async (_sport, _day, id, capturedAt, _source, signal) => {
        details++;
        assert.ok(signal instanceof AbortSignal);
        return { sport: "football", capturedAt, items: [{ id }] };
      },
    },
    async () => {},
    {
      key: "test",
      model: "gpt-6-luna",
      deadline: performance.now() + 10000,
      fetcher: (async (_u, init) => {
        calls++;
        return modelResponse(evaluateFixture(JSON.parse(String(init?.body))));
      }) as typeof fetch,
    },
  );
  await reader.query("2026-10-10", ["football"], "all", "teams");
  const overview = await reader.execute("evaluate_matches", {
    queryId: "q1",
    criteria: "forme",
    matchKeys: null,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  }) as any;
  for (let i = 1; i <= 5; i++) {
    const detail = await reader.execute("read_match_data", {
      queryId: "q1",
      matchKey: `football:${i}`,
    }) as any;
    assert.equal(Boolean(detail.data ?? detail.items), i <= 4);
  }
  assert.equal(details, 4);
  await reader.execute("read_match_data", {
    queryId: "q1",
    matchKey: "football:1",
  });
  assert.equal(details, 4);
  const initialCalls = calls;
  const archived = await reader.execute("read_match_evaluations", {
    evaluationId: overview.evaluationId,
    offset: 8,
    limit: 4,
  }) as any;
  assert.equal(archived.exploration.manifest.length, 4);
  assert.deepEqual(
    archived.rows.map((r: any) => r.key),
    archived.exploration.manifest.map((m: any) => m.key),
  );
  assert.deepEqual(
    Object.keys(archived.exploration.forms),
    archived.rows.map((r: any) => r.key),
  );
  assert.equal(archived.budgetUsage.deepened, 4);
  assert.ok(
    archived.budgetUsage.deepenings.every((d: any) => d.result === "available"),
  );
  assert.equal(calls, initialCalls);
  assert.ok(Object.keys(obj(archived.exploration.evidence)).length === 4);
});

Deno.test("evaluation call ceiling yields explicit partial coverage; missing form is unavailable data, never invented losses", async () => {
  const { query, criterion } = await explorationDay();
  let calls = 0;
  const budget = new ExplorationBudget();
  const options = {
    model: "gpt-6-luna",
    key: "test",
    evaluationConcurrency: 1,
    fetcher: (async (_u, init) => {
      calls++;
      return modelResponse(evaluateFixture(JSON.parse(String(init?.body))));
    }) as typeof fetch,
  };
  const report = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    now,
    criteria: criterion.criteria,
    exploration: criterion,
    budget,
    batchCallLimit: 2,
    deadline: performance.now() + 10000,
  }, options);
  assert.equal(calls, 2);
  assert.equal(report.complete, false);
  assert.ok(report.evaluated < 80);
  assert.equal(
    report.failed.flatMap((f) => f.keys).length + report.evaluated,
    80,
  );
  assert.ok(
    report.exploration!.limitations.some((l) => l.includes("partielle")),
  );
  query.catalog.matches = [];
  query.catalog.candidates = [];
  obj(query.sources[0].payload.raw).recent_league_matches = [];
  const empty = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    now,
    criteria: criterion.criteria,
    exploration: criterion,
    deadline: performance.now() + 10000,
  }, options);
  assert.equal(empty.evaluated, 80);
  assert.equal(empty.exploration!.coverage.insufficient, 80);
  assert.equal(empty.exploration!.selectedKeys.length, 0);
  assert.ok(
    Object.values(empty.exploration!.forms).every((f) =>
      f.home.state === "absent" && !f.home.results.length
    ),
  );
});

Deno.test("detail cancellation preserves the evaluated ranking, records timeout and uses no fifth read or regrading", async () => {
  const { publication, context } = await explorationDay(4);
  let elapsed = 0, calls = 0;
  const reader = new ConversationReader(
    {
      context,
      date: "2026-10-10",
      now,
      state: null,
      id: "test",
      message: "Compare les rencontres",
    },
    {
      sources: async () => [publication],
      matchData: async (_s, _d, _id, _at, _source, signal) => {
        assert.ok(signal);
        calls++;
        elapsed = 225000;
        throw new DOMException("Controlled cancellation", "TimeoutError");
      },
    },
    async () => {},
    {
      key: "test",
      model: "gpt-6-luna",
      clock: () => elapsed,
      deadline: 95000,
      fetcher: (async (_u, init) =>
        modelResponse(
          evaluateFixture(JSON.parse(String(init?.body))),
        )) as typeof fetch,
    },
  );
  await reader.query("2026-10-10", ["football"], "all", "teams");
  const overview = await reader.execute("evaluate_matches", {
    queryId: "q1",
    criteria: "forme",
    matchKeys: null,
    observationCount: 4,
    useProfileReadings: true,
    formScope: "domestic_championship",
  }) as any;
  const report = reader.evaluations.get(overview.evaluationId)!;
  const before = [...report.exploration!.selectedKeys];
  const timedOut = await reader.execute("read_match_data", {
    queryId: "q1",
    matchKey: "football:1",
  }) as any;
  assert.equal(timedOut.data, null);
  assert.ok(timedOut.limitation.includes("Budget"));
  const stopped = await reader.execute("read_match_data", {
    queryId: "q1",
    matchKey: "football:2",
  }) as any;
  assert.equal(stopped.data, null);
  assert.equal(calls, 1);
  assert.equal(report.budgetUsage!.deepenings[0].result, "timeout");
  assert.deepEqual(report.exploration!.selectedKeys, before);
});

Deno.test("hockey exploration keeps five chronological verified results from the match competition without inventing league points", async () => {
  const mixed = await mixedDay();
  const hockey = mixed.sources[1];
  const history = Array.from(
    { length: 5 },
    (_, i) => ({
      id: 900 + i,
      startsAt: `2026-09-${10 + i}T12:00:00Z`,
      outcome: "win",
      home: true,
    }),
  );
  obj(hockey.payload).competitions = [
    {
      id: "35",
      formPhaseVerified: true,
      tables: [{ rows: [{ team: { id: "2" }, formHistory: history }] }],
    },
    {
      id: "99",
      formPhaseVerified: true,
      tables: [{
        rows: [{
          team: { id: "2" },
          formHistory: [{
            id: 999,
            startsAt: "2026-10-01T12:00:00Z",
            outcome: "loss",
          }],
        }],
      }],
    },
  ];
  const reader = new ConversationReader({
    context: { ...mixed.context, view: "all" },
    date: "2026-10-10",
    state: null,
    now,
    id: "hockey",
    message: "forme",
  }, { sources: async () => [hockey] });
  const query = await reader.query("2026-10-10", ["hockey"], "all", "teams");
  query.matches = query.matches.filter((m) => m.id === "1");
  const criterion = explorationCriterion({
    query,
    request: "Forme hockey",
    criteria: "forme",
    observationCount: 1,
    useProfileReadings: false,
    formScope: "competition",
  });
  const fact = prepareMatchSheets(query, now, criterion)[0].facts.find((f) =>
    f.id.includes(":published_form:2")
  )!;
  assert.equal(fact.sample, 5);
  assert.deepEqual(fact.lineage!.matchIds, ["900", "901", "902", "903", "904"]);
  assert.ok(fact.text.includes("du plus ancien au plus récent"));
  assert.ok(fact.text.includes("Points hockey non calculés"));
  assert.ok(!fact.text.includes('"999"'));
});
