/** Read-only audit and prospective batch plan. No real fetch, env or paid mode.
 * The original artifacts and all production algorithms are left unchanged. */
import {
  pilotResumePlan,
  prepareReadingsCampaign,
} from "./generator_exploration_campaign.ts";
import { ValidationCallBudget } from "./generator_validation_budget.ts";
import { buildExplorationReport } from "../supabase/functions/_shared/generator/exploration.ts";
import {
  type DayEvaluation,
  evaluateMatches,
  evaluationInstructions,
} from "../supabase/functions/_shared/generator/match_evaluation.ts";

const original = "output/generator-exploration-run-38462876424/files";
const output = "output/generator-exploration-review-38462876424";
const checkpointBytes = await Deno.readFile(`${original}/checkpoint.json`);
const report = JSON.parse(
  new TextDecoder().decode(checkpointBytes),
) as DayEvaluation;
const prepared = await prepareReadingsCampaign(
  await Deno.readFile("test/fixtures/generator_published_day.json"),
);
const resume = pilotResumePlan(report, prepared);
if (!resume.canResume || resume.reused !== 20 || resume.pending !== 99) {
  throw Error("Unexpected resume scope");
}
for (const filename of ["call-1.json", "call-2.json"]) {
  const originalRequest = JSON.parse(
    await Deno.readTextFile(`${original}/requests/${filename}`),
  );
  if (originalRequest.instructions !== evaluationInstructions) {
    throw Error(
      "Evaluation instructions changed: twenty grades are not reusable under the current contract",
    );
  }
}

const baseline = report.exploration!.rankedKeys;
const permutations = [
  {
    name: "reverse_rows",
    rows: [...report.rows].reverse(),
    sheets: prepared.sheets,
  },
  {
    name: "rotate_rows_7",
    rows: [...report.rows.slice(7), ...report.rows.slice(0, 7)],
    sheets: prepared.sheets,
  },
  {
    name: "reverse_rows_and_sheets",
    rows: [...report.rows].reverse(),
    sheets: [...prepared.sheets].reverse(),
  },
];
const orderChecks = [];
for (const permutation of permutations) {
  const ranked = await buildExplorationReport(
    { ...report, rows: permutation.rows },
    permutation.sheets,
    prepared.criterion,
    prepared.now,
  );
  orderChecks.push({
    name: permutation.name,
    identical: JSON.stringify(ranked.rankedKeys) === JSON.stringify(baseline),
  });
}
if (orderChecks.some((c) => !c.identical)) {
  throw Error("Ranking depends on row permutation");
}

const batches: {
  keys: string[];
  requestBytes: number;
  reservationUsd: number;
  maxOutputTokens: number;
}[] = [];
const admission = new ValidationCallBudget(0.10, 10, 0.10, 0.50);
const identity = (
  m: {
    sport: string;
    competition: string;
    home: string;
    away: string;
    kickoff: string;
  },
) => JSON.stringify([m.sport, m.competition, m.home, m.away, m.kickoff]);
const byIdentity = new Map(
  prepared.sheets.map((s) => [identity(s.match), s.key]),
);
if (byIdentity.size !== prepared.sheets.length) {
  throw Error("Ambiguous fixture identity in dry plan");
}
// Native request preparation is exercised through an injected rejecting fetcher.
// There is no native fetch call, API key access, response simulation or new grade.
const noNetwork: typeof fetch = async (_url, init) => {
  const body = String(init?.body);
  const payload = JSON.parse(body);
  const input = JSON.parse(payload.input);
  const keys = input.matches.map((m: Parameters<typeof identity>[0]) =>
    byIdentity.get(identity(m))
  );
  if (keys.some((k: string | undefined) => !k)) {
    throw Error("Unknown planned fixture");
  }
  batches.push({
    keys,
    requestBytes: new TextEncoder().encode(body).length,
    reservationUsd: admission.admit(body),
    maxOutputTokens: payload.max_output_tokens,
  });
  throw Error("Offline preparation only: no model called, no new evaluation");
};
await evaluateMatches({
  id: "offline-plan-only",
  query: prepared.query,
  criteria: prepared.criterion.criteria,
  exploration: prepared.criterion,
  now: prepared.now,
  deadline: performance.now() + 60000,
  preparedSheets: prepared.sheets,
  reusedRows: report.rows,
  snapshotAsOf: report.snapshot!.asOf,
}, {
  key: "offline-placeholder-never-sent",
  model: report.model,
  evaluationConcurrency: 1,
  fetcher: noNetwork,
});

const plannedKeys = batches.flatMap((b) => b.keys);
if (
  batches.length !== 10 || plannedKeys.length !== 99 ||
  new Set(plannedKeys).size !== 99 ||
  plannedKeys.some((k) => report.rows.some((r) => r.key === k))
) throw Error("Incorrect prospective batch partition");
if (
  JSON.stringify([...plannedKeys].sort()) !==
    JSON.stringify([...resume.pendingKeys].sort())
) throw Error("Pending manifest mismatch");
if (
  new TextDecoder().decode(checkpointBytes) !==
    await Deno.readTextFile(`${original}/checkpoint.json`)
) throw Error("Original checkpoint changed");

await Deno.mkdir(output, { recursive: true });
await Deno.writeTextFile(
  `${output}/offline-checks.json`,
  JSON.stringify(
    {
      status: "human-review-pending",
      realModelCalls: 0,
      networkPermissions: false,
      algorithmsModified: false,
      originalCheckpointUnchanged: true,
      evaluationInstructionsUnchanged: true,
      orderChecks,
      modelInputOrderEffect: "not_tested_without_new_model_calls",
      resume,
      proposedPilot: {
        authorized: false,
        mode: "progressive_checkpoint_resume",
        model: report.model,
        maxAdditionalCalls: 10,
        maxAdditionalUsd: 0.10,
        budgetsAcrossWindows:
          "one persisted global ledger; no automatic paid retry",
        evaluationWindowMs: 45000,
        maxCallsPerWindow: 2,
        windows: 5,
        plannedReservationUsd: admission.reservedUsd,
        batches,
        pricingStatus:
          "rates from the first pilot; reverify at any future launch",
        executionAvailable: false,
        requiredDevelopment:
          "validation-only resumable runner, global admission ledger and per-window checkpoint handling; existing two-call CLI rejects full-run/resume mode",
      },
    },
    null,
    2,
  ),
);
console.log(JSON.stringify({
  realModelCalls: 0,
  orderChecks,
  reused: resume.reused,
  pending: resume.pending,
  plannedBatchSizes: batches.map((b) => b.keys.length),
  plannedReservationUsd: admission.reservedUsd,
}));
