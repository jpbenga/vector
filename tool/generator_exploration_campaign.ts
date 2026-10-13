/** Validation-only campaign contracts. No account, provider or database access. */
import {
  ConversationReader,
  type ReadQuery,
} from "../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  type Context,
  obj,
  rows,
} from "../supabase/functions/_shared/generator/contracts.ts";
import { type Source } from "../supabase/functions/_shared/generator/catalog.ts";
import { explorationCriterion } from "../supabase/functions/_shared/generator/exploration.ts";
import {
  type DayEvaluation,
  evaluateMatches,
  prepareMatchSheets,
} from "../supabase/functions/_shared/generator/match_evaluation.ts";
import {
  ExplorationBudget,
  type ExplorationBudgetConfig,
} from "../supabase/functions/_shared/generator/exploration_budget.ts";
import {
  changedSheets,
  requireSnapshot,
  reusableRows,
} from "../supabase/functions/_shared/generator/exploration_continuity.ts";
import { type ModelOptions } from "../supabase/functions/_shared/generator/models.ts";

export const campaign1Sha256 =
  "8b8bb0042dc9084c4960128fb0bb3fddf53776521dcd2510f6d47bc5efe2de2c";
export const campaign1Profile = {
  id: "validation-published-readings-2026-10-10-v1",
  readings: [
    "form_advantage",
    "improving_form",
    "negative_streak",
    "winning_streak",
  ],
};
export async function sha256(bytes: Uint8Array) {
  return Array.from(
    new Uint8Array(
      await crypto.subtle.digest("SHA-256", new Uint8Array(bytes)),
    ),
  ).map((v) => v.toString(16).padStart(2, "0")).join("");
}
export async function prepareReadingsCampaign(bytes: Uint8Array) {
  const digest = await sha256(bytes);
  if (digest !== campaign1Sha256) {
    throw Error(
      "Le corpus figé a changé. Nouvelle validation du corpus requise.",
    );
  }
  const input = JSON.parse(new TextDecoder().decode(bytes)),
    sources = input.sources as Source[],
    now = new Date(input.asOf);
  const context: Context = {
    view: "all",
    origin: "profile",
    scope: "strict",
    timezone: "Europe/Paris",
    budget: 0,
    preferences: {
      football: {
        competitions: [],
        readings: [...campaign1Profile.readings],
        markets: [],
      },
    },
  };
  const request =
    "Examiner les lectures de forme publiées configurées. Les séries domestiques strictement vérifiables sont indisponibles et ne font pas partie du critère de cette campagne.";
  const reader = new ConversationReader({
    context,
    date: input.day,
    now,
    state: null,
    id: "campaign-1",
    message: request,
  }, { sources: async () => sources });
  const query = await reader.query(input.day, ["football"], "all", "teams");
  const criterion = explorationCriterion({
    request,
    criteria:
      "Lectures de forme publiées configurées ; séries domestiques non vérifiables, hors critère.",
    query,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  });
  const sheets = prepareMatchSheets(query, now, criterion);
  const documented = sheets.filter((s) => s.facts.length).length,
    verified =
      sheets.filter((s) =>
        s.form?.home.results.length && s.form?.away.results.length
      ).length;
  if (
    input.day !== "2026-10-10" || sheets.length !== 119 || documented !== 113 ||
    verified !== 0
  ) {
    throw Error(
      "La couverture ne correspond plus au corpus accepté 119 / 113 / 6 / 0.",
    );
  }
  return {
    query,
    criterion,
    sheets,
    now,
    preflight: {
      campaign: "published_readings",
      status: "awaiting-paid-authorization",
      sourceSha256: digest,
      day: input.day,
      dataAsOf: input.asOf,
      testProfile: campaign1Profile,
      criterion,
      coverage: {
        manifest: 119,
        documented: 113,
        insufficientEvidence: 6,
        verifiedDomesticSeries: 0,
      },
      limits: { maxCalls: 2 },
      paidCalls: 0,
      productionWrites: 0,
      providerCalls: 0,
      limitations: [
        "Aucune série domestique strictement vérifiable. Une lecture publiée ne valide pas cinq résultats domestiques.",
        "Le pilote valide la transmission et les lots ; la compréhension conversationnelle nécessite un run distinct autorisé.",
      ],
    },
  };
}
export type ReadingsCampaign = Awaited<
  ReturnType<typeof prepareReadingsCampaign>
>;
export function pilotResumePlan(
  previous: DayEvaluation,
  prepared: ReadingsCampaign,
) {
  requireSnapshot(previous);
  if (
    previous.expected !== 119 || previous.scope.date !== prepared.query.date ||
    previous.scope.view !== "all" || previous.model !== "gpt-6-luna" ||
    JSON.stringify(previous.exploration?.criterion) !==
      JSON.stringify(prepared.criterion)
  ) throw Error("Le checkpoint ne correspond pas à cette campagne figée.");
  const changes = changedSheets(previous, prepared.sheets);
  const reused = reusableRows(previous, prepared.sheets);
  const reusable = changes.changedKeys.length === 0 &&
    changes.addedKeys.length === 0 && changes.removedKeys.length === 0 &&
    reused.length === previous.evaluated;
  return {
    canResume: reusable && previous.evaluated < 119,
    reused: reused.length,
    pending: 119 - reused.length,
    pendingKeys: prepared.sheets.filter((s) =>
      !reused.some((r) => r.key === s.key)
    ).map((s) => s.key),
    changes,
    paidCalls: 0,
    requiresNewAuthorization: true,
  };
}

export function pilotCoverage(report: DayEvaluation) {
  const insufficient =
    report.rows.filter((r) => r.status === "insufficient").length;
  return {
    manifest: report.expected,
    evaluated: report.evaluated,
    supportedOrMixed: report.evaluated - insufficient,
    insufficient,
    notEvaluated: report.expected - report.evaluated,
    complete: report.complete,
    rankingScope: report.complete ? "full_manifest" : "evaluated_subset",
    failedBatches: report.failed,
  };
}
export function sportingReviewPacket(report: DayEvaluation) {
  const e = report.exploration;
  if (!e) throw Error("Dossier d’exploration absent.");
  const retained = e.selectedKeys,
    alternatives = e.rankedKeys.filter((k) => !retained.includes(k)).slice(
      0,
      5,
    );
  const describe = (key: string) => {
    const match = e.manifest.find((m) => m.key === key)!,
      evaluation = report.rows.find((r) => r.key === key)!;
    return {
      match,
      evaluation,
      rank: e.decisions.find((d) => d.key === key)?.rank,
      evidence: e.evidence[key] ?? [],
      review: {
        validity: null,
        relevance: null,
        construction: null,
        explanation: null,
        rankingJustification: null,
      },
    };
  };
  const boundary = retained.length
    ? report.rows.find((r) => r.key === retained.at(-1))
    : undefined;
  return {
    status: "human-review-pending",
    readyForTop10AndFiveAlternatives: report.complete &&
      retained.length === 10 && alternatives.length === 5,
    rankingScope: report.complete ? "full_manifest" : "evaluated_subset",
    coverage: pilotCoverage(report),
    retained: retained.map(describe),
    nearBoundaryAlternatives: alternatives.map((k) => ({
      ...describe(k),
      tiesWithBoundary:
        boundary?.fit === report.rows.find((r) => r.key === k)?.fit &&
        boundary?.status === report.rows.find((r) => r.key === k)?.status,
    })),
    limitations: [
      "L’adéquation 0–4 est un repère de classement du moteur, pas une probabilité de pari.",
      "Les égalités départagées par identifiant sont visibles ; leur pertinence sportive reste à examiner humainement.",
    ],
  };
}
export async function runTwoCallPilot(
  prepared: ReadingsCampaign,
  options: ModelOptions,
  config: ExplorationBudgetConfig,
  onCheckpoint: (r: DayEvaluation) => Promise<void>,
) {
  const budget = new ExplorationBudget(config, options.clock),
    clock = options.clock ?? (() => performance.now());
  return await evaluateMatches({
    id: crypto.randomUUID(),
    query: prepared.query,
    criteria: prepared.criterion.criteria,
    exploration: prepared.criterion,
    now: prepared.now,
    deadline: clock() + config.internalMs,
    budget,
    batchCallLimit: 2,
    preparedSheets: prepared.sheets,
    onCheckpoint,
  }, { ...options, evaluationConcurrency: 1 });
}
/** Campaign 2 is an independent data-readiness gate; no grading or remote fetch.
 * Completion must be explicit in the export, beyond the canonical engine contract. */
export function domesticCampaignReadiness(
  query: ReadQuery,
  now: Date,
  maxPublicationAgeHours = 24,
) {
  if (!Number.isFinite(maxPublicationAgeHours) || maxPublicationAgeHours <= 0) {
    throw Error("Limite de fraîcheur invalide.");
  }
  const criterion = explorationCriterion({
    request: "Lectures et cinq résultats domestiques vérifiés",
    criteria: "Lectures configurées et forme domestique vérifiée",
    query,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  });
  const sheets = prepareMatchSheets(query, now, criterion);
  const matches = sheets.map((s) => {
    const source = query.sources.find((p) => p.id === s.match.sourceId),
      raw = obj(source?.payload.raw);
    const dossier = rows(raw.european_comparisons).find((d) =>
      String(d.fixtureId) === s.match.id
    );
    const projection = rows(raw.generator_domestic_forms).find((d) =>
      String(d.fixtureId) === s.match.id
    );
    const sides = ["home", "away"].map((side) => {
      const f = s.form?.[side as "home" | "away"];
      const problems: string[] = [];
      const publicationAge = now.getTime() -
        Date.parse(source?.capturedAt ?? "");
      if (
        !Number.isFinite(publicationAge) || publicationAge < 0 ||
        publicationAge > maxPublicationAgeHours * 3600000
      ) {
        problems.push(
          `Publication absente, future ou plus ancienne que ${maxPublicationAgeHours} h.`,
        );
      }
      if (!f || f.state !== "available" || f.results.length !== 5) {
        problems.push("Cinq résultats vérifiés indisponibles.");
      }
      if (!f?.competitionId || !f.season || !f.sourcePath || !f.observedAt) {
        problems.push("Compétition, saison ou provenance manquante.");
      }
      if (
        f?.observedAt &&
        Date.parse(f.observedAt) >
          Math.min(now.getTime(), Date.parse(s.match.kickoff))
      ) problems.push("Observation postérieure à la borne pré-match.");
      const canonical = rows(obj(dossier?.[side]).domesticRecentMatches).concat(
        rows(obj(projection?.[side]).results),
      );
      const legacy = rows(raw.recent_league_matches).filter((h) =>
        String(obj(h.team).id) === f?.teamId
      ).flatMap((h) => rows(h.matches));
      const histories = canonical.length ? canonical : legacy;
      for (const r of f?.results ?? []) {
        const rawMatch = histories.find((h) =>
          String(h.fixtureId ?? obj(h.fixture).id) === r.fixtureId
        );
        const status = String(
          obj(obj(rawMatch?.fixture).status).short ?? rawMatch?.status ?? "",
        );
        if (!["FT", "AET", "PEN", "AWD"].includes(status)) {
          problems.push(`Statut terminé non explicite pour ${r.fixtureId}.`);
        }
        if (
          r.competitionId !== f?.competitionId || r.season !== f?.season ||
          Date.parse(r.playedAt) >= Date.parse(s.match.kickoff) ||
          Date.parse(r.playedAt) > now.getTime()
        ) problems.push(`Contexte ou date invalide pour ${r.fixtureId}.`);
      }
      return {
        side,
        teamId: f?.teamId,
        competitionId: f?.competitionId,
        season: f?.season,
        sourcePath: f?.sourcePath,
        observedAt: f?.observedAt,
        resultCount: f?.results.length ?? 0,
        ready: problems.length === 0,
        problems: [...new Set(problems)],
      };
    });
    return { match: s.match, sides, ready: sides.every((t) => t.ready) };
  });
  return {
    campaign: "verified_domestic_form",
    status: matches.length && matches.every((m) => m.ready)
      ? "data-ready-awaiting-authorization"
      : "awaiting-verified-publications",
    maxPublicationAgeHours,
    fixtureCount: matches.length,
    fullyVerified: matches.filter((m) => m.ready).length,
    matches,
    paidCalls: 0,
    productionWrites: 0,
    criterion,
  };
}
