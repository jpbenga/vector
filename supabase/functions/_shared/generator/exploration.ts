/** Additive read contract on existing DayEvaluation; no parallel service/table. */
import { type Context, type Evidence, obj, rows } from "./contracts.ts";
import type { ReadQuery } from "./conversation_tools.ts";
import type { DayEvaluation, MatchSheet } from "./match_evaluation.ts";
import { publishedReadingIds } from "./catalog.ts";

export interface ExplorationCriterionV1 {
  schemaVersion: 1;
  originalRequest: string;
  criteria: string;
  date: string;
  timezone: string;
  view: string;
  sports: string[];
  observationCount: number;
  useProfileReadings: boolean;
  readingIds: Record<string, string[]>;
  competitions: { sport: string; id: string; name: string }[];
  formScope: "domestic_championship" | "competition";
  formWindow: 5;
  rankingPolicy: "documented-fit-reservations-stable-id-v1";
}
export function explorationCriterion(input: {
  request: string;
  criteria: string;
  query: ReadQuery;
  observationCount: number;
  useProfileReadings: boolean;
  formScope: ExplorationCriterionV1["formScope"];
}): ExplorationCriterionV1 {
  if (
    !input.request.trim() || input.request.length > 2000 ||
    !input.criteria.trim() || input.criteria.length > 1200 ||
    !Number.isInteger(input.observationCount) || input.observationCount < 1 ||
    input.observationCount > 20 ||
    typeof input.useProfileReadings !== "boolean" ||
    !["domestic_championship", "competition"].includes(input.formScope)
  ) {
    throw new Error("Critère d’exploration invalide.");
  }
  const competitions = new Map<
    string,
    { sport: string; id: string; name: string }
  >();
  for (const match of input.query.matches) {
    const source = input.query.sources.find((s) => s.id === match.sourceId);
    const fixture = rows(
      match.sport === "football"
        ? obj(source?.payload.raw).fixtures
        : source?.payload.items,
    )
      .find((f) =>
        String(match.sport === "football" ? obj(f.fixture).id : f.id) ===
          match.id
      );
    const id = fixture
      ? String(
        match.sport === "football"
          ? obj(fixture.league).id
          : fixture.competitionId,
      )
      : null;
    if (id && /^\d{1,12}$/.test(id)) {
      competitions.set(`${match.sport}:${id}`, {
        sport: match.sport,
        id,
        name: match.competition,
      });
    }
  }
  return {
    schemaVersion: 1,
    originalRequest: input.request,
    criteria: input.criteria.trim(),
    competitions: [...competitions.entries()].sort(([a], [b]) =>
      a < b ? -1 : a > b ? 1 : 0
    ).map(([, c]) => c),
    date: input.query.date,
    timezone: input.query.context.timezone,
    view: input.query.context.view ?? "profile",
    sports: [...input.query.sports].sort(),
    observationCount: input.observationCount,
    useProfileReadings: input.useProfileReadings,
    readingIds: Object.fromEntries(
      [...input.query.sports].sort().map((
        sport,
      ) => [
        sport,
        publishedReadingIds(
          input.query.context.preferences[sport]?.readings ?? [],
        ).sort(),
      ]),
    ),
    formScope: input.formScope,
    formWindow: 5,
    rankingPolicy: "documented-fit-reservations-stable-id-v1",
  };
}
export function explorationFacts(
  facts: Evidence[],
  _context: Context,
  sport: "football" | "hockey",
  criterion: ExplorationCriterionV1,
): Evidence[] {
  if (!criterion.useProfileReadings) return facts;
  const ids = criterion.readingIds[sport] ?? [];
  return facts.filter((f) =>
    f.source !== "reading" ||
    ids.some((id) => f.id.includes(`:${id}:`))
  );
}
export interface ExplorationReportV1 {
  schemaVersion: 1;
  evaluationId: string;
  criterion: ExplorationCriterionV1;
  createdAt: string;
  criterionHash: string;
  coverage: {
    expected: number;
    evaluated: number;
    insufficient: number;
    failed: number;
    reused: number;
    complete: boolean;
  };
  manifest: ReadQuery["matches"];
  rankedKeys: string[];
  selectedKeys: string[];
  decisions: {
    key: string;
    retained: boolean;
    reason:
      | "selected"
      | "insufficient_data"
      | "no_documented_fit"
      | "not_evaluated"
      | "below_requested_count"
      | "documented_reservations"
      | "stable_tie_break";
    rank: number | null;
  }[];
  evidence: Record<string, Evidence[]>;
  forms: Record<string, NonNullable<MatchSheet["form"]>>;
  limitations: string[];
}
const compareId = (a: string, b: string) => a < b ? -1 : a > b ? 1 : 0;
export async function buildExplorationReport(
  report: DayEvaluation,
  sheets: MatchSheet[],
  criterion: ExplorationCriterionV1,
  now: Date,
): Promise<ExplorationReportV1> {
  const keys = new Set(sheets.map((s) => s.key));
  if (
    keys.size !== sheets.length || sheets.length !== report.expected ||
    report.evaluated !== report.rows.length ||
    new Set(report.rows.map((r) => r.key)).size !== report.rows.length ||
    report.rows.some((r) =>
      !keys.has(r.key) || !Number.isInteger(r.fit) || r.fit < 0 || r.fit > 4 ||
      !["supported", "mixed", "insufficient"].includes(r.status)
    ) ||
    report.complete !==
      (report.evaluated === report.expected && report.failed.length === 0)
  ) {
    throw new Error("Couverture d’exploration incohérente.");
  }
  const failedKeys = report.failed.flatMap((f) => f.keys);
  if (
    report.criteria !== criterion.criteria ||
    new Set(failedKeys).size !== failedKeys.length ||
    failedKeys.some((key) =>
      !keys.has(key) || report.rows.some((r) => r.key === key)
    ) ||
    failedKeys.length + report.evaluated !== report.expected
  ) {
    throw new Error("Manifeste d’exploration incomplet ou critère modifié.");
  }
  const rows = new Map(report.rows.map((r) => [r.key, r]));
  for (const sheet of sheets) {
    const row = rows.get(sheet.key);
    if (row?.status === "mixed" && !row.vigilanceReferences.length) {
      throw new Error("Contradiction d’exploration sans preuve publiée.");
    }
    if (
      row &&
      (row.references.some((id) => !sheet.facts.some((f) => f.id === id)) ||
        row.vigilanceReferences.some((id) =>
          !sheet.facts.some((f) => f.id === id)
        ))
    ) {
      throw new Error("Preuve d’exploration étrangère à la rencontre.");
    }
  }
  const ranked = report.rows.filter((r) =>
    r.status !== "insufficient" &&
    r.fit > 0 && r.references.length
  ).sort((a, b) =>
    b.fit - a.fit ||
    Number(a.status === "mixed") - Number(b.status === "mixed") ||
    compareId(a.key, b.key)
  );
  const selected = ranked.slice(0, criterion.observationCount);
  const ranks = new Map(ranked.map((r, i) => [r.key, i + 1]));
  const chosen = new Set(selected.map((r) => r.key));
  const boundary = selected.at(-1);
  const limitations = new Set(report.rows.flatMap((r) => r.limitations));
  const forms = sheets.filter((s) => s.form).map((s) =>
    [s.key, s.form!] as const
  );
  const unavailableForms = forms.flatMap(([, f]) => [f.home, f.away]).filter((
    f,
  ) => f.state === "unverified" || f.state === "absent");
  if (unavailableForms.length) {
    limitations.add(
      `Forme ${
        criterion.formScope === "domestic_championship"
          ? "en championnat"
          : "dans la compétition"
      } non disponible ou non vérifiable pour ${unavailableForms.length} contextes d’équipe ; ne pas inventer les résultats.`,
    );
  }
  if (!report.complete) {
    limitations.add(
      `Évaluation partielle : ${report.evaluated}/${report.expected} rencontres ; classement parmi les seules rencontres évaluées.`,
    );
  }
  if (selected.length < criterion.observationCount) {
    limitations.add(
      `${selected.length}/${criterion.observationCount} observations étayées ; aucun complément artificiel.`,
    );
  }
  if (
    criterion.useProfileReadings &&
    !Object.values(criterion.readingIds).some((ids) => ids.length)
  ) {
    limitations.add(
      "Aucune lecture configurée dans le périmètre ; le critère demandé n’est pas entièrement documenté.",
    );
  }
  return {
    schemaVersion: 1,
    evaluationId: report.id,
    criterion: structuredClone(criterion),
    criterionHash: await hashCriterion(criterion),
    createdAt: now.toISOString(),
    coverage: {
      expected: report.expected,
      evaluated: report.evaluated,
      insufficient:
        report.rows.filter((r) => r.status === "insufficient").length,
      failed: report.expected - report.evaluated,
      reused: report.reused ?? 0,
      complete: report.complete,
    },
    manifest: sheets.map((s) => structuredClone(s.match)).sort((a, b) =>
      compareId(a.key, b.key)
    ),
    rankedKeys: ranked.map((r) => r.key),
    selectedKeys: selected.map((r) => r.key),
    decisions: [...keys].sort(compareId).map((key) => {
      const row = rows.get(key);
      return {
        key,
        retained: chosen.has(key),
        rank: ranks.get(key) ?? null,
        reason: !row
          ? "not_evaluated"
          : chosen.has(key)
          ? "selected"
          : row.status === "insufficient"
          ? "insufficient_data"
          : row.fit === 0 || !row.references.length
          ? "no_documented_fit"
          : row.fit === boundary?.fit && row.status === boundary?.status
          ? "stable_tie_break"
          : row.fit === boundary?.fit && row.status === "mixed"
          ? "documented_reservations"
          : "below_requested_count",
      };
    }),
    forms: Object.fromEntries(
      forms.map(([key, form]) => [key, structuredClone(form)]),
    ),
    evidence: Object.fromEntries(sheets.map((s) => {
      const row = rows.get(s.key),
        refs = new Set([
          ...(row?.references ?? []),
          ...(row?.vigilanceReferences ?? []),
        ]);
      return [
        s.key,
        s.facts.filter((f) => refs.has(f.id)).map((f) => structuredClone(f)),
      ];
    })),
    limitations: [...limitations],
  };
}
/** Pure explanation of the retained audit; never re-evaluate or consult current facts. */
export function explainExplorationChoice(report: DayEvaluation, key: string) {
  const exploration = report.exploration;
  if (!exploration) {
    throw new Error(
      "Cette évaluation ancienne n’a pas de dossier d’exploration versionné.",
    );
  }
  const match = exploration.manifest.find((m) => m.key === key);
  const decision = exploration.decisions.find((d) => d.key === key);
  if (!match || !decision) throw new Error("Rencontre hors exploration.");
  return structuredClone({
    evaluationId: report.id,
    criterion: exploration.criterion,
    match,
    decision,
    evaluation: report.rows.find((r) => r.key === key) ?? null,
    evidence: exploration.evidence[key] ?? [],
    form: exploration.forms[key] ?? null,
    semantics:
      "Explication du snapshot initial, sans actualisation ni nouvel appel d’évaluation.",
  });
}

export async function hashCriterion(criterion: ExplorationCriterionV1) {
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(JSON.stringify({
      ...criterion,
      originalRequest: undefined,
      observationCount: undefined,
    })),
  );
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
