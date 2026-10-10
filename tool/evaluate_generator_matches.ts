// Two paid 500-match requests against synthetic publications. No Supabase reads,
// no provider requests, no customer impersonation and no automatic paid retry.
import assert from "node:assert/strict";
import { converse } from "../supabase/functions/_shared/generator/conversation.ts";
import { mixedDay } from "../supabase/functions/_shared/generator/match_evaluation_cases.ts";
import type { DayEvaluation } from "../supabase/functions/_shared/generator/match_evaluation.ts";
import {
  context,
  now,
} from "../supabase/functions/_shared/generator/evaluation_cases.ts";
import {
  comparisonModels,
  type ModelReceipt,
} from "../supabase/functions/_shared/generator/models.ts";
const key = Deno.env.get("OPENAI_API_KEY");
if (!key || Deno.env.get("GITHUB_ACTIONS") !== "true") {
  throw new Error(
    "Use the repository OpenAI secret in GitHub Actions; no keychain fallback.",
  );
}
const reports: unknown[] = [];
let failed = false;
for (const model of comparisonModels) {
  const { sources, context } = await mixedDay(),
    receipts: ModelReceipt[] = [],
    evaluations: DayEvaluation[] = [],
    started = performance.now();
  let last = "",
    answer: Awaited<ReturnType<typeof converse>> | undefined,
    error: string | null = null;
  try {
    answer = await converse({
      message:
        "Aujourd’hui de travail est le samedi 10 octobre 2026. Analyse individuellement TOUTES les 500 rencontres de football ET hockey dans Pour moi, puis propose les six rencontres dont l’écart de forme récent sur cinq matchs est le plus conséquent (nombre de victoires finales, pour comparer les deux sports). Compare l’ensemble, ne présélectionne pas la première page. Je ne demande pas encore un ticket ni un objectif de cote. Donne les marchés étayés et les réserves.",
      date: "2026-10-10",
      today: "2026-10-08",
      context,
      state: null,
      now,
      id: "33333333-3333-4333-8333-333333333333",
    }, {
      key,
      model,
      reads: { sources: async () => sources },
      onReceipt: (r) => receipts.push(r),
      onEvaluation: async (r) => {
        evaluations.push(r);
        console.log(JSON.stringify({
          model,
          expected: r.expected,
          evaluated: r.evaluated,
          complete: r.complete,
          failedReasons: [...new Set(r.failed.map((b) => b.reason))],
        }));
      },
      onProgress: async (p) => {
        if (p.phase === "evaluate" && p.detail !== last) {
          last = p.detail ?? "";
          console.log(
            JSON.stringify({
              model,
              progress: last,
              elapsedMs: Math.round(performance.now() - started),
            }),
          );
        }
      },
    });
    assert.ok(
      answer.evaluations.length > 0,
      "The agent must use the complete individual evaluation capability.",
    );
    // A conversational agent may repair a failed evaluation within its two
    // bounded attempts. Require the final full scope; count every paid attempt.
    const evaluation = answer.evaluations.at(-1)!;
    assert.equal(evaluation.expected, 500);
    assert.equal(evaluation.evaluated, 500);
    assert.equal(evaluation.complete, true);
    const analysis = answer.next.messages.at(-1)?.analysis;
    assert.ok(analysis);
    assert.equal(analysis.selections.length, 6);
    const chosen = analysis.selections.map((s) =>
      `${s.candidate.sport}:${s.candidate.matchId.replace("api-fixture-", "")}`
    ).sort();
    assert.deepEqual(
      chosen,
      [
        "football:248",
        "football:249",
        "football:250",
        "hockey:248",
        "hockey:249",
        "hockey:250",
      ],
      "The greatest documented gaps are at the end of both sports, not the first page.",
    );
    assert.equal(analysis.context.evaluation?.evaluated, 500);
  } catch (e) {
    failed = true;
    error = e instanceof Error ? e.message : String(e);
  }
  const metric = {
    model,
    status: error ? "failed" : "passed",
    error,
    elapsedMs: Math.round(performance.now() - started),
    modelCalls: receipts.length,
    inputTokens: receipts.reduce((n, r) => n + (r.inputTokens ?? 0), 0),
    outputTokens: receipts.reduce((n, r) => n + (r.outputTokens ?? 0), 0),
    estimatedUsd: {
      minimum: receipts.reduce((n, r) => n + (r.estimatedUsd?.minimum ?? 0), 0),
      maximum: receipts.reduce((n, r) => n + (r.estimatedUsd?.maximum ?? 0), 0),
    },
    coverage: evaluations.map((r) => ({
      expected: r.expected,
      evaluated: r.evaluated,
      complete: r.complete,
      failedBatches: r.failed.length,
    })),
    evaluations,
    receipts,
    analysis: answer?.next.messages.at(-1)?.analysis,
  };
  reports.push(metric);
  await Deno.writeTextFile(
    "/tmp/lector-generator-matches.json",
    JSON.stringify({ synthetic: true, reports }, null, 2),
  );
  console.log(
    JSON.stringify({
      ...metric,
      receipts: undefined,
      evaluations: undefined,
      analysis: undefined,
    }),
  );
}
if (failed) {
  throw new Error(
    "500-match model evaluation failed; deployment remains blocked. Receipts retained.",
  );
}
