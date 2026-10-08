// Paired evaluations use frozen SYNTHETIC data. No account lookup or ticket commit.
import { interpret } from "../supabase/functions/_shared/generator/openai.ts";
import {
  comparisonModels,
  type ModelReceipt,
} from "../supabase/functions/_shared/generator/models.ts";
import {
  context,
  intent,
  now,
  source,
} from "../supabase/functions/_shared/generator/evaluation_cases.ts";
import {
  applyIntent,
  resolveIntent,
} from "../supabase/functions/_shared/generator/service.ts";
import {
  type Intent,
  type State,
} from "../supabase/functions/_shared/generator/contracts.ts";
import {
  buildReviewBrief,
  reviewCompositions,
} from "../supabase/functions/_shared/generator/review.ts";

const key = Deno.env.get("OPENAI_API_KEY");
if (Deno.env.get("GITHUB_ACTIONS") !== "true" || !key) {
  throw new Error(
    "Run the paid model comparison in GitHub Actions with the repository secret.",
  );
}
const state = applyIntent({
  state: null,
  context,
  intent,
  sources: [source()],
  message:
    "50 euros, samedi, retour total autour de 300 euros, six matchs maximum",
  now,
  id: "00000000-0000-4000-8000-000000000001",
  workshop: true,
});
type Evaluation = {
  name: string;
  message: string;
  state: State | null;
  accepts: (i: Intent) => boolean;
};
const cases: Evaluation[] = [
  {
    name: "around_total",
    message:
      "Pour samedi 10 octobre, 50 euros de mise et retour total autour de 300 euros, six matchs maximum, football.",
    state: null,
    accepts: (i) =>
      i.action === "generate" && i.date === "2026-10-10" &&
      i.maxSelections === 6 && i.tickets[0]?.stake === 50 &&
      i.tickets[0]?.kind === "total" && i.goalMode === "around",
  },
  {
    name: "explicit_minimum",
    message:
      "Samedi 10 octobre, football, mise 50 euros, retour total d’au moins 300 euros, quatre matchs maximum.",
    state: null,
    accepts: (i) =>
      i.action === "generate" && i.goalMode === "minimum" &&
      i.tickets[0]?.minimum === 300 && i.maxSelections === 4,
  },
  {
    name: "missing_stake",
    message:
      "Samedi 10 octobre, propose-moi un ticket de football pour un retour total autour de 300 euros.",
    state: null,
    accepts: (i) => i.tickets.every((t) => t.stake === null),
  },
  {
    name: "ambiguous_return",
    message:
      "Samedi, football, 50 euros pour gagner 300 euros, six matchs maximum.",
    state: null,
    accepts: (i) => i.tickets[0]?.kind === "unspecified",
  },
  {
    name: "clarification",
    message: "Retour total",
    state: {
      ...state,
      tickets: [],
      drafts: [],
      intent: null,
      pendingIntent: {
        ...intent,
        tickets: [{ ...intent.tickets[0], kind: "unspecified" }],
      },
      messages: [{
        role: "user",
        text:
          "Samedi 10 octobre, 50 euros pour environ 300 euros, six matchs maximum, football.",
      }, { role: "assistant", text: "Retour total ou bénéfice net ?" }],
    },
    accepts: (i) =>
      i.action === "generate" && i.date === intent.date &&
      i.tickets[0]?.stake === 50 && i.tickets[0]?.kind === "total" &&
      i.maxSelections === 6,
  },
  {
    name: "another_ticket",
    message: "Propose-moi un autre ticket avec les mêmes contraintes.",
    state,
    accepts: (i) => {
      const r = resolveIntent(i, state);
      return i.action === "alternative" && r.tickets[0]?.stake === 50 &&
        r.maxSelections === 6;
    },
  },
  {
    name: "same_matches_new_markets",
    message:
      "Propose une autre composition avec exactement les mêmes rencontres, mais d’autres marchés autorisés.",
    state,
    accepts: (i) => i.action === "alternative" && i.preserveFixtures === true,
  },
  {
    name: "fewer_matches",
    message:
      "Propose-moi une autre composition avec trois matchs maximum, la même mise et le même objectif.",
    state,
    accepts: (i) =>
      i.action === "alternative" && i.preserveConstraints === false &&
      i.maxSelections === 3 && i.tickets[0]?.stake === 50,
  },
];
const receipts: ModelReceipt[] = [], outcomes: Record<string, unknown>[] = [];
const failed = new Set<string>();
for (const evaluation of cases) {
  // Each pair receives the same serialized inputs; neither mutates shared state.
  const results = await Promise.allSettled(
    comparisonModels.map(async (model) => {
      const result = await interpret({
        message: evaluation.message,
        context: structuredClone(context),
        date: intent.date,
        today: "2026-10-08",
        state: structuredClone(evaluation.state),
      }, { key, model, onReceipt: (r) => receipts.push(r) });
      return {
        model,
        passed: evaluation.accepts(result.intent),
        intent: result.intent,
      };
    }),
  );
  results.forEach((r, i) => {
    const outcome = r.status === "fulfilled" ? r.value : {
      model: comparisonModels[i],
      passed: false,
      error: r.reason instanceof Error ? r.reason.message : "model_failure",
    };
    if (!outcome.passed) failed.add(outcome.model);
    outcomes.push({ case: evaluation.name, ...outcome });
    console.log(
      JSON.stringify({
        case: evaluation.name,
        model: outcome.model,
        passed: outcome.passed,
      }),
    );
  });
}
const brief = buildReviewBrief(state.proposals ?? state.tickets, now);
const reviews = await Promise.allSettled(
  comparisonModels.map((model) =>
    reviewCompositions(brief, {
      key,
      model,
      onReceipt: (r) => receipts.push(r),
    })
  ),
);
reviews.forEach((r, i) => {
  if (r.status === "rejected") failed.add(comparisonModels[i]);
  outcomes.push({
    case: "composition_review",
    model: comparisonModels[i],
    passed: r.status === "fulfilled",
    ...(r.status === "fulfilled" ? { review: r.value.review } : {
      error: r.reason instanceof Error ? r.reason.message : "model_failure",
    }),
  });
});
// Select only within the user-authorized pair after objective contract gates.
// This is an initial demo default, not a final quality/cost verdict.
const selected = comparisonModels.find((m) => !failed.has(m)) ?? null;
const report = {
  protocol: "lector-model-comparison-v1",
  createdAt: new Date().toISOString(),
  inputs: "frozen_synthetic",
  engine: "workshop",
  reasoning: "low",
  paidCallsAttempted: receipts.length,
  selected,
  outcomes,
  receipts,
  reviewFacts: brief.facts,
};
await Deno.writeTextFile(
  "/tmp/lector-generator-comparison.json",
  JSON.stringify(report, null, 2),
);
console.log(JSON.stringify({
  selected,
  paidCallsAttempted: receipts.length,
  models: comparisonModels.map((model) => ({
    model,
    passed: !failed.has(model),
    estimatedUsd: receipts.filter((r) => r.requestedModel === model).reduce(
      (s, r) => ({
        minimum: s.minimum + (r.estimatedUsd?.minimum ?? 0),
        maximum: s.maximum + (r.estimatedUsd?.maximum ?? 0),
      }),
      { minimum: 0, maximum: 0 },
    ),
  })),
}));
if (!selected) {
  throw new Error(
    "Neither selected model passed the contract gates. No activation.",
  );
}
await Deno.writeTextFile("/tmp/lector-generator-model.txt", selected);
