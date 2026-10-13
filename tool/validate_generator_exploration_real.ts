/** Campaign 1, initial two-call protocol pilot. Default is preparation only.
 * No dialogue/follow-up calls, Supabase, sports-provider access or deployment. */
import {
  pilotCoverage,
  pilotResumePlan,
  prepareReadingsCampaign,
  runTwoCallPilot,
  sportingReviewPacket,
} from "./generator_exploration_campaign.ts";
import { ValidationCallBudget } from "./generator_validation_budget.ts";
import { explorationBudgetConfig } from "../supabase/functions/_shared/generator/exploration_budget.ts";
import {
  explorationView,
  requireSnapshot,
} from "../supabase/functions/_shared/generator/exploration_continuity.ts";
import { type DayEvaluation } from "../supabase/functions/_shared/generator/match_evaluation.ts";
import { type ModelReceipt } from "../supabase/functions/_shared/generator/models.ts";
const args = new Map<string, string>();
for (let i = 0; i < Deno.args.length; i++) {
  const name = Deno.args[i];
  if (!name.startsWith("--") || args.has(name.slice(2))) {
    throw Error("Argument invalide ou dupliqué.");
  }
  args.set(
    name.slice(2),
    Deno.args[i + 1]?.startsWith("--") || !Deno.args[i + 1]
      ? "true"
      : Deno.args[++i],
  );
}
if (args.has("read-checkpoint")) {
  const report = JSON.parse(
    await Deno.readTextFile(args.get("read-checkpoint")!),
  ) as DayEvaluation;
  requireSnapshot(report);
  const frozen = await prepareReadingsCampaign(
    await Deno.readFile(
      args.get("source") ?? "test/fixtures/generator_published_day.json",
    ),
  );
  const resume = pilotResumePlan(report, frozen);
  console.log(
    JSON.stringify({
      evaluationId: report.id,
      status: "human-review-pending",
      coverage: pilotCoverage(report),
      paidReadCalls: 0,
      resume,
    }),
  );
  Deno.exit(0);
}
if (
  args.has("resume-checkpoint") || args.has("readings") || args.has("stage")
) {
  throw Error(
    "Ce pilote a un profil figé et ne lance aucune reprise ou campagne complète. Une autre autorisation sera nécessaire.",
  );
}
const prepared = await prepareReadingsCampaign(
  await Deno.readFile(
    args.get("source") ?? "test/fixtures/generator_published_day.json",
  ),
);
const config = explorationBudgetConfig(
  args.has("budgets") ? JSON.parse(args.get("budgets")!) : {},
);
const output = args.get("output") ?? "output/generator-exploration-pilot";
await Deno.mkdir(output, { recursive: true });
const proposal = {
  ...prepared.preflight,
  config,
  proposedLaunch: {
    model: "gpt-6-luna",
    maxCalls: 2,
    maxUsd: 0.05,
    serviceTier: "default",
    prices: {
      input: 0.10,
      output: 0.50,
      cachedInput: 0.01,
      cacheWrite: 0.125,
      unit: "USD per million tokens",
      verifiedAt: "2026-10-13",
      source: "https://developers.openai.com/api/docs/models/gpt-6-luna",
    },
  },
  authorization: {
    paid: false,
    required: "Nouvelle autorisation explicite du lancement payant",
  },
  protocolScope:
    "Deux appels d’évaluation du moteur workshop ; compréhension conversationnelle et classement global non validés par ce pilote.",
};
if (args.get("approved") !== "true") {
  await Deno.writeTextFile(
    `${output}/preflight.json`,
    JSON.stringify(proposal, null, 2),
  );
  console.log(JSON.stringify(proposal));
  Deno.exit(0);
}
const model = args.get("model"),
  maxCalls = Number(args.get("max-calls")),
  maxUsd = Number(args.get("max-usd"));
const inputPrice = Number(args.get("input-price")),
  outputPrice = Number(args.get("output-price")),
  pricingDate = args.get("pricing-date");
if (
  model !== "gpt-6-luna" || maxCalls !== 2 || !Number.isFinite(maxUsd) ||
  maxUsd <= 0 || !Number.isFinite(inputPrice) || inputPrice <= 0 ||
  !Number.isFinite(outputPrice) || outputPrice <= 0 ||
  !pricingDate?.match(/^\d{4}-\d{2}-\d{2}$/) ||
  new Date(pricingDate).toISOString().slice(0, 10) !== pricingDate
) {
  throw Error(
    "Le pilote exige Luna, max-calls=2, un plafond USD explicite et des tarifs input/output vérifiés et datés.",
  );
}
if (Deno.env.get("GITHUB_ACTIONS") !== "true") {
  throw Error(
    "Utiliser uniquement la clé du dépôt dans GitHub Actions ; aucun accès au trousseau.",
  );
}
const key = Deno.env.get("OPENAI_API_KEY");
if (!key) throw Error("Clé OpenAI du dépôt indisponible.");
// createNew prevents rerunning into an existing paid ledger.
await Deno.writeTextFile(
  `${output}/authorization.json`,
  JSON.stringify({
    approved: true,
    at: new Date().toISOString(),
    campaign: "published_readings",
    model,
    maxCalls,
    maxUsd,
    inputPrice,
    outputPrice,
    pricingDate,
    sourceSha256: prepared.preflight.sourceSha256,
    testProfile: prepared.preflight.testProfile,
  }),
  { createNew: true },
);
await Deno.writeTextFile(
  `${output}/preflight.json`,
  JSON.stringify(
    {
      ...proposal,
      authorization: { paid: true },
      actualLaunch: {
        model,
        maxCalls,
        maxUsd,
        inputPrice,
        outputPrice,
        pricingDate,
      },
    },
    null,
    2,
  ),
);
const budget = new ValidationCallBudget(
    maxUsd,
    maxCalls,
    inputPrice,
    outputPrice,
  ),
  receipts: (ModelReceipt & { wasDispatched: boolean })[] = [],
  events: unknown[] = [];
const checkpointPaths: string[] = [];
let dispatchedCalls = 0;
let checkpoint: DayEvaluation | undefined,
  report: DayEvaluation | undefined,
  error: string | null = null;
const started = performance.now();
async function atomicJson(path: string, value: unknown) {
  await Deno.writeTextFile(`${path}.tmp`, JSON.stringify(value, null, 2));
  await Deno.rename(`${path}.tmp`, path);
}
async function measures() {
  const actualReceipts = receipts.filter((r) => r.wasDispatched);
  const usageKnown = actualReceipts.length === dispatchedCalls &&
    actualReceipts.every((r) =>
      r.inputTokens !== null && r.outputTokens !== null
    );
  const baseEstimate = usageKnown
    ? actualReceipts.reduce(
      (n, r) =>
        n +
        ((r.inputTokens ?? 0) * inputPrice +
            (r.outputTokens ?? 0) * outputPrice) / 1e6,
      0,
    )
    : null;
  await atomicJson(`${output}/measurements.json`, {
    campaign: "published_readings",
    status: "human-review-pending",
    protocolVerdict: error || report?.failed.some((f) =>
        !f.reason.includes("Budget d’évaluation atteint")
      )
      ? "failed"
      : report?.evaluated
      ? "partial-report-ready"
      : checkpoint?.evaluated
      ? "checkpoint-recovered"
      : "no-accepted-batch",
    error,
    model,
    pricingDate,
    providedPrices: { inputPrice, outputPrice },
    limits: { maxCalls, maxUsd },
    admittedCalls: budget.calls,
    dispatchedCalls,
    validationErrors: (report?.failed ?? []).filter((f) =>
      !f.reason.includes("Budget d’évaluation atteint")
    ),
    reservedUsd: budget.reservedUsd,
    receipts,
    events,
    coverage: report
      ? pilotCoverage(report)
      : checkpoint
      ? pilotCoverage(checkpoint)
      : null,
    elapsedMs: Math.round(performance.now() - started),
    usageEstimateUsd: dispatchedCalls === 0 ? 0 : baseEstimate,
    cacheAdjustment:
      "Non appliqué au montant de base ; vérifier les écritures et lectures de cache dans la facture.",
    estimateSemantics:
      "Estimation aux tarifs fournis sans réduction de cache, distincte de la réservation et de la facture. Usage inconnu conservé comme inconnu.",
    invoiceUsd: null,
    checkpointPaths,
    productionWrites: 0,
    providerCalls: 0,
  });
}
const fetcher: typeof fetch = async (url, init) => {
  if (String(url) !== "https://api.openai.com/v1/responses") {
    throw Error("Destination non autorisée.");
  }
  const payload = JSON.parse(String(init?.body));
  if (
    payload.model !== model ||
    payload.text?.format?.name !== "lector_match_evaluations" ||
    payload.service_tier !== "default"
  ) {
    throw Error(
      "Le pilote autorise uniquement les lots d’évaluation structurés du modèle choisi.",
    );
  }
  const reservation = budget.admit(String(init?.body));
  await Deno.mkdir(`${output}/requests`, { recursive: true });
  await atomicJson(`${output}/requests/call-${budget.calls}.json`, payload);
  events.push({
    phase: "paid-admission",
    call: budget.calls,
    reservationUsd: reservation,
    elapsedMs: Math.round(performance.now() - started),
  });
  await measures();
  dispatchedCalls++;
  return await fetch(url, init);
};
try {
  report = await runTwoCallPilot(
    prepared,
    {
      key,
      model,
      fetcher,
      onReceipt: (r) => {
        receipts.push({
          ...r,
          wasDispatched: dispatchedCalls > receipts.filter((r) =>
            r.wasDispatched
          ).length,
        });
      },
    },
    config,
    async (r) => {
      checkpoint = structuredClone(r);
      const path = `${output}/checkpoint-${r.id}-${r.evaluated}.json`;
      if (!checkpointPaths.includes(path)) {
        await atomicJson(path, r);
        checkpointPaths.push(path);
      }
      await atomicJson(`${output}/checkpoint.json`, r);
      await measures();
    },
  );
  await atomicJson(`${output}/checkpoint.json`, report);
  checkpoint = report;
} catch (e) {
  error = e instanceof Error ? e.message : String(e);
}
const archived = report ?? checkpoint;
if (archived) {
  await atomicJson(
    `${output}/exploration.json`,
    explorationView(archived, prepared.now),
  );
  await atomicJson(
    `${output}/sporting-review.json`,
    sportingReviewPacket(archived),
  );
  const readBack = JSON.parse(
    await Deno.readTextFile(`${output}/checkpoint.json`),
  ) as DayEvaluation;
  requireSnapshot(readBack);
  const coverage = pilotCoverage(readBack);
  await atomicJson(`${output}/recovery.json`, {
    evaluationId: readBack.id,
    identical: JSON.stringify(readBack) === JSON.stringify(archived),
    coverage,
    paidRecoveryCalls: 0,
    resume: pilotResumePlan(readBack, prepared),
    resumptionRequiresNewAuthorization: true,
  });
  await atomicJson(`${output}/mechanical-checks.json`, {
    manifestPreserved: archived.expected === 119 &&
      archived.snapshot?.sheets.length === 119,
    uniqueEvaluations: new Set(archived.rows.map((r) =>
      r.key
    )).size === archived.evaluated,
    partitionSumsToManifest: coverage.supportedOrMixed + coverage.insufficient +
        coverage.notEvaluated === 119,
    validReferences: archived.rows.every((r) =>
      [...r.references, ...r.vigilanceReferences].every((id) =>
        archived.snapshot!.sheets.find((s) => s.key === r.key)?.facts.some(
          (f) => f.id === id,
        )
      )
    ),
    boundedCalls: budget.calls <= 2,
    partialHonesty: !archived.complete,
    domesticSeriesVerified: false,
    globalRankingValidated: false,
    humanReview: "pending",
  });
}
await measures();
console.log(
  JSON.stringify({
    status: "human-review-pending",
    admittedCalls: budget.calls,
    coverage: archived ? pilotCoverage(archived) : null,
    error,
  }),
);
if (
  error || !archived?.evaluated ||
  archived.failed.some((f) => !f.reason.includes("Budget d’évaluation atteint"))
) Deno.exit(1);
