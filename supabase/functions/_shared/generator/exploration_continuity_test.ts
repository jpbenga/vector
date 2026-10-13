import assert from "node:assert/strict";
import {
  evaluateFixture,
  explorationDay,
  modelResponse,
} from "./exploration_cases.ts";
import { type DayEvaluation, evaluateMatches } from "./match_evaluation.ts";
import {
  buildExplorationReport,
  explainExplorationChoice,
} from "./exploration.ts";
import {
  compareExploration,
  explorationView,
  requireSnapshot,
} from "./exploration_continuity.ts";
import { ConversationReader } from "./conversation_tools.ts";
import { now } from "./evaluation_cases.ts";
import { obj, rows } from "./contracts.ts";

Deno.test("durable 62/80: archived read, explanation, comparison, resume and targeted refresh across messages", async () => {
  const fixture = await explorationDay();
  const graded: string[] = [];
  let calls = 0, reads = 0, details = 0;
  const options = {
    model: "gpt-6-luna",
    key: "controlled",
    deadline: performance.now() + 110000,
    fetcher: (async (_u, init) => {
      calls++;
      const body = JSON.parse(String(init?.body));
      graded.push(
        ...JSON.parse(body.input).matches.map((m: any) =>
          `${m.home} / ${m.away}`
        ),
      );
      return modelResponse(evaluateFixture(body));
    }) as typeof fetch,
  };
  const initial = await evaluateMatches({
    id: crypto.randomUUID(),
    query: fixture.query,
    criteria: fixture.criterion.criteria,
    exploration: fixture.criterion,
    now,
    deadline: options.deadline,
  }, options);
  // Explicitly controlled partial archive. The sporting dossier is kept intact.
  initial.rows = initial.rows.slice(0, 62);
  initial.evaluated = 62;
  initial.complete = false;
  initial.failed = [{
    keys: initial.snapshot!.sheets.slice(62).map((s) => s.key),
    reason: "Interruption contrôlée après 62 rencontres.",
  }];
  initial.exploration = await buildExplorationReport(
    initial,
    initial.snapshot!.sheets,
    fixture.criterion,
    now,
  );
  const immutable = JSON.stringify(initial);
  const later = new Date(now.getTime() + 4 * 3600000);
  const view = explorationView(initial, later);
  const beforeCalls = calls;
  assert.equal(view.coverage!.evaluated, 62);
  assert.equal(view.stale, true);
  const keys = initial.exploration.selectedKeys.slice(0, 4);
  assert.equal(compareExploration(initial, keys).comparisons.length, 4);
  const excluded = initial.exploration.decisions.find((d) => !d.retained)!;
  assert.equal(
    explainExplorationChoice(initial, excluded.key).decision.retained,
    false,
  );
  assert.equal(calls, beforeCalls);
  let current = fixture.publication;
  let saved: DayEvaluation | undefined;
  const reader = () =>
    new ConversationReader(
      {
        context: fixture.context,
        date: "2026-10-10",
        state: null,
        now: later,
        id: "later",
        message: "Reprendre la préparation",
      },
      {
        sources: async () => {
          reads++;
          return [current];
        },
        evaluation: async (id) => id === initial.id ? initial : saved ?? null,
        matchData: async () => {
          details++;
          throw Error("Unexpected detailed read");
        },
      },
      async () => {},
      {
        ...options,
        deadline: performance.now() + 110000,
        onEvaluation: async (r) => {
          saved = structuredClone(r);
        },
      },
    );
  graded.length = 0;
  await reader().execute("continue_match_evaluation", {
    evaluationId: initial.id,
  });
  const resumed = saved!;
  assert.equal(resumed.evaluated, 80);
  assert.equal(resumed.reused, 62);
  assert.equal(graded.length, 18);
  assert.equal(new Set(graded).size, 18);
  assert.deepEqual(
    resumed.exploration!.criterion,
    initial.exploration.criterion,
  );
  assert.equal(resumed.snapshot!.asOf, initial.snapshot!.asOf);
  assert.equal(resumed.version!.parentId, initial.id);
  assert.equal(resumed.version!.mode, "resume");
  assert.equal(JSON.stringify(initial), immutable);
  assert.ok(
    explorationView(resumed, later).version!.selectedAddedKeys.length > 0,
  );
  // A new publication changes one pre-match result. Everything else stays equal.
  current = structuredClone(fixture.publication);
  current.id = crypto.randomUUID();
  current.capturedAt = later.toISOString();
  const history = rows(obj(current.payload.raw).recent_league_matches)[0];
  const changed = rows(history.matches)[0];
  changed.result = changed.result === "W" ? "L" : "W";
  changed.goals = changed.result === "W"
    ? { for: 2, against: 1 }
    : { for: 1, against: 2 };
  const baseCalls = calls;
  graded.length = 0;
  const conflict = await reader().execute("continue_match_evaluation", {
    evaluationId: initial.id,
  });
  assert.equal(obj(conflict).conflict, true);
  assert.equal(calls, baseCalls);
  await reader().execute("reevaluate_exploration", {
    evaluationId: initial.id,
  });
  const refreshed = saved!;
  assert.equal(refreshed.version!.changedKeys.length, 1);
  assert.equal(refreshed.version!.mode, "refresh");
  assert.equal(refreshed.reused, 61);
  assert.equal(graded.length, 19);
  assert.equal(JSON.stringify(initial), immutable);
  assert.equal(details, 0);
  const proofPermission = await Deno.permissions.query({
    name: "env",
    variable: "LECTOR_EXPLORATION_PROOF_DIR",
  });
  const directory = proofPermission.state === "granted"
    ? Deno.env.get("LECTOR_EXPLORATION_PROOF_DIR")
    : undefined;
  if (directory) {
    await Deno.mkdir(directory, { recursive: true });
    await Deno.writeTextFile(
      `${directory}/continuity.json`,
      JSON.stringify(
        {
          measurement:
            "controlled deterministic substitute; no provider or real model calls",
          initial: explorationView(initial, later),
          resumed: explorationView(resumed, later),
          refreshed: explorationView(refreshed, later),
          comparison: compareExploration(initial, keys),
          explanation: explainExplorationChoice(initial, excluded.key),
          instrumentation: {
            simulatedBatchCalls: calls,
            publicationReads: reads,
            detailedReads: details,
            realPaidCalls: 0,
            resumeNewlyEvaluated: 18,
            refreshNewlyEvaluated: 19,
            archiveBytes: new TextEncoder().encode(immutable).length,
            resumeBudget: resumed.budgetUsage,
            refreshBudget: refreshed.budgetUsage,
          },
        },
        null,
        2,
      ),
    );
  }
});

Deno.test("an interruption retains a valid checkpoint and does not submit an automatic retry", async () => {
  const { query, criterion } = await explorationDay(12);
  let checkpoint: DayEvaluation | undefined;
  let calls = 0;
  await assert.rejects(
    () =>
      evaluateMatches({
        id: crypto.randomUUID(),
        query,
        criteria: criterion.criteria,
        exploration: criterion,
        now,
        deadline: performance.now() + 110000,
        onCheckpoint: async (r) => {
          checkpoint = r;
        },
        onProgress: async (n) => {
          if (n > 0) throw Error("cancelled");
        },
      }, {
        model: "gpt-6-luna",
        key: "controlled",
        evaluationConcurrency: 1,
        fetcher: (async (_u, init) => {
          calls++;
          return modelResponse(evaluateFixture(JSON.parse(String(init?.body))));
        }) as typeof fetch,
      }),
    /cancelled/,
  );
  assert.ok(checkpoint!.evaluated > 0);
  assert.ok(checkpoint!.snapshot);
  assert.ok(calls < 4);
  assert.equal(
    checkpoint!.exploration!.coverage.evaluated,
    checkpoint!.rows.length,
  );
});
Deno.test("old reports remain readable but cannot silently invent a resumable dossier", () => {
  const old = {
    id: "legacy",
    rows: [],
    expected: 0,
  } as unknown as DayEvaluation;
  assert.equal(explorationView(old, now).legacy, true);
  assert.throws(() => requireSnapshot(old), /ancienne préparation/);
});

Deno.test("an explicit later-message resume reaches native analysis without repeating the requested evaluation", async () => {
  const { converse } = await import("./conversation.ts");
  const { initialIntent } = await import("./conversation_memory.ts");
  const fixture = await explorationDay(8);
  const later = new Date(now.getTime() + 3600000);
  let saved: DayEvaluation;
  let evaluations = 0, dialogue = 0;
  const initial = await evaluateMatches({
    id: crypto.randomUUID(),
    query: fixture.query,
    criteria: fixture.criterion.criteria,
    exploration: fixture.criterion,
    now,
    deadline: performance.now() + 110000,
  }, {
    model: "gpt-6-luna",
    key: "controlled",
    fetcher: (async (_u, i) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(i?.body))),
      )) as typeof fetch,
  });
  initial.rows = initial.rows.slice(0, 6);
  initial.evaluated = 6;
  initial.complete = false;
  initial.failed = [{
    keys: initial.snapshot!.sheets.slice(6).map((s) => s.key),
    reason: "Controlled interruption",
  }];
  initial.exploration = await buildExplorationReport(
    initial,
    initial.snapshot!.sheets,
    fixture.criterion,
    now,
  );
  const response = await converse({
    message: "Reprends uniquement les manques.",
    date: "2026-10-10",
    today: "2026-10-08",
    context: fixture.context,
    state: null,
    now: later,
    id: crypto.randomUUID(),
    explorationAction: { evaluationId: initial.id, mode: "resume" },
  }, {
    model: "gpt-6-luna",
    key: "controlled",
    reads: {
      sources: async () => [fixture.publication],
      evaluation: async () => initial,
    },
    onEvaluation: async (r) => {
      saved = r;
    },
    fetcher: (async (_u, i) => {
      const body = JSON.parse(String(i?.body));
      if (body.text?.format?.name === "lector_match_evaluations") {
        evaluations++;
        return modelResponse(evaluateFixture(body));
      }
      dialogue++;
      const input = JSON.parse(body.input[0].content);
      assert.ok(input.requestedExploration);
      assert.equal(input.requestedExploration.version.mode, "resume");
      assert.match(input.requestedExplorationPolicy, /déjà été exécutée/);
      return modelResponse({
        plan: {
          intent: {
            ...initialIntent(fixture.context, "2026-10-10"),
            action: "analyze",
            sports: ["football"],
            view: "all",
          },
          changedFields: [],
          newTask: false,
          focusMode: "keep",
          focusKeys: [],
        },
        text:
          "Les deux rencontres manquantes ont été évaluées ; la préparation initiale reste intacte.",
        queryId: "q1",
        projectionId: null,
        analysis: {
          text: "Préparation reprise.",
          selections: [],
          observations: saved.exploration!.selectedKeys.map((key) => ({
            matchId: key,
            reason: "Fait archivé correspondant au critère.",
            references: saved.exploration!.evidence[key].map((f) => f.id),
          })),
          comparedMatchIds: [`evaluation:${saved.id}`],
          limitations: [],
        },
      });
    }) as typeof fetch,
  });
  assert.equal(evaluations, 1);
  assert.equal(dialogue, 1);
  assert.equal(
    response.next.messages.at(-1)!.analysis!.exploration!.coverage.evaluated,
    8,
  );
  assert.equal(
    obj(response.next.messages.at(-1)!.analysis!.exploration!.version).parentId,
    initial.id,
  );
  const { archiveWork, compactModelMemory } = await import("./work_storage.ts");
  const archived = archiveWork(response.next);
  const compact = {
    ...response.next,
    messages: archived.messages.map(({ analysis: _analysis, ...m }) => m),
  };
  assert.equal(
    compactModelMemory(compact).explorations![0].evaluationId,
    saved!.id,
  );
  assert.ok(JSON.stringify(compactModelMemory(compact)).length < 12000);
});

Deno.test("an archived Shortlist preparation refreshes its original dates and IDs after Shortlist expiry without adding other matches", async () => {
  const f = await explorationDay(3);
  const second = rows(obj(f.publication.payload.raw).fixtures)[1];
  obj(second.fixture).date = "2026-10-11T18:00:00Z";
  f.query.matches[1].kickoff = "2026-10-11T18:00:00Z";
  // Only the original two fixtures belong to this preparation. A third match
  // remains available in Tous and must never enter the archived Shortlist.
  f.query.matches = f.query.matches.slice(0, 2);
  f.query.context = {
    ...f.context,
    view: "shortlist",
    shortlist: {
      sessionId: crypto.randomUUID(),
      revision: 1,
      expiresAt: new Date(now.getTime() + 60000).toISOString(),
      keys: f.query.matches.map((m) => m.key),
      items: f.query.matches.map((m) => ({
        key: m.key,
        sport: m.sport,
        fixtureId: m.id,
        date: m.kickoff.slice(0, 10),
      })),
    },
  };
  f.criterion.view = "shortlist";
  const initial = await evaluateMatches({
    id: crypto.randomUUID(),
    query: f.query,
    criteria: f.criterion.criteria,
    exploration: f.criterion,
    now,
    deadline: performance.now() + 110000,
  }, {
    model: "gpt-6-luna",
    key: "controlled",
    fetcher: (async (_u, i) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(i?.body))),
      )) as typeof fetch,
  });
  const dates: string[] = [];
  let saved: DayEvaluation | undefined;
  let grades = 0;
  const reader = new ConversationReader(
    {
      context: f.context,
      date: "2026-10-13",
      state: null,
      now: new Date(now.getTime() + 4 * 3600000),
      id: "new-message",
      message: "Actualise cette préparation",
    },
    {
      sources: async (_c, date) => {
        dates.push(date);
        return [f.publication];
      },
      evaluation: async () => initial,
    },
    async () => {},
    {
      model: "gpt-6-luna",
      key: "controlled",
      deadline: performance.now() + 110000,
      onEvaluation: async (r) => {
        saved = r;
      },
      fetcher: (async (_u, i) => {
        grades++;
        return modelResponse(evaluateFixture(JSON.parse(String(i?.body))));
      }) as typeof fetch,
    },
  );
  await reader.execute("reevaluate_exploration", { evaluationId: initial.id });
  assert.deepEqual(dates.sort(), ["2026-10-10", "2026-10-11"]);
  assert.deepEqual(
    saved!.snapshot!.sheets.map((s) => s.key),
    initial.snapshot!.sheets.map((s) => s.key),
  );
  assert.equal(saved!.scope.date, "2026-10-10");
  assert.equal(saved!.scope.view, "shortlist");
  assert.equal(saved!.expected, 2);
  assert.equal(saved!.reused, 2);
  assert.equal(grades, 0);
});

Deno.test("Radar refresh uses the latest publication with original membership and remaps proof IDs without regrading unchanged sport facts", async () => {
  const f = await explorationDay(3),
    raw = obj(f.publication.payload.raw),
    fixture = rows(raw.fixtures)[0];
  const teamId = String(obj(obj(fixture.teams).home).id);
  const context = {
    ...f.context,
    view: "radar" as const,
    radarKind: "teams" as const,
    radar: {
      football: {
        version: 1 as const,
        mode: "teams" as const,
        category: "club" as const,
        capturedAt: f.publication.capturedAt,
        sourceIds: [f.publication.id],
        includeWomen: false,
        includeYouth: false,
        competitionId: null,
        teams: [{
          id: teamId,
          teamId,
          rank: 1,
          matchIds: rows(
            rows(raw.recent_league_matches).find((r) =>
              String(obj(r.team).id) === teamId
            )!.matches,
          ).map((m) => String(obj(m.fixture).id)),
        }],
        players: [],
      },
    },
  };
  const reader = new ConversationReader({
    context,
    date: "2026-10-10",
    state: null,
    now,
    id: "original",
    message: "Explorer le Radar",
  }, { sources: async () => [f.publication] });
  const query = await reader.query(
    "2026-10-10",
    ["football"],
    "radar",
    "teams",
  );
  assert.equal(query.matches.length, 1);
  const criterion = { ...f.criterion, view: "radar" as const };
  const initial = await evaluateMatches({
    id: crypto.randomUUID(),
    query,
    criteria: criterion.criteria,
    exploration: criterion,
    now,
    deadline: performance.now() + 110000,
  }, {
    model: "gpt-6-luna",
    key: "controlled",
    fetcher: (async (_u, i) =>
      modelResponse(
        evaluateFixture(JSON.parse(String(i?.body))),
      )) as typeof fetch,
  });
  const later = new Date(now.getTime() + 4 * 3600000),
    current = structuredClone(f.publication);
  current.id = crypto.randomUUID();
  current.capturedAt = later.toISOString();
  let grades = 0, saved: DayEvaluation | undefined;
  const next = new ConversationReader(
    {
      context,
      date: "2026-10-10",
      state: null,
      now: later,
      id: "later",
      message: "Actualise cette préparation Radar",
    },
    { sources: async () => [current], evaluation: async () => initial },
    async () => {},
    {
      model: "gpt-6-luna",
      key: "controlled",
      deadline: performance.now() + 110000,
      onEvaluation: async (r) => {
        saved = r;
      },
      fetcher: (async (_u, i) => {
        grades++;
        return modelResponse(evaluateFixture(JSON.parse(String(i?.body))));
      }) as typeof fetch,
    },
  );
  await next.execute("reevaluate_exploration", { evaluationId: initial.id });
  assert.equal(saved!.expected, 1);
  assert.equal(saved!.reused, 1);
  assert.equal(grades, 0);
  assert.equal(saved!.scope.sources[0].id, current.id);
  assert.ok(saved!.rows[0].references.every((r) => r.startsWith(current.id)));
  assert.deepEqual(saved!.version!.changedKeys, []);
});
