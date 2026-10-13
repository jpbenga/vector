import { type Context, obj } from "./contracts.ts";
import { buildCatalog } from "./catalog.ts";
import type { ReadQuery } from "./conversation_tools.ts";
import type {
  DayEvaluation,
  MatchEvaluation,
  MatchSheet,
} from "./match_evaluation.ts";
import { explainExplorationChoice } from "./exploration.ts";

export interface ExplorationSnapshot {
  version: 1;
  asOf: string;
  context: Context;
  sheets: MatchSheet[];
}
export interface ExplorationVersion {
  rootId: string;
  parentId: string | null;
  mode: "initial" | "resume" | "refresh";
  changedKeys: string[];
  addedKeys: string[];
  removedKeys: string[];
  reusedKeys: string[];
  previousSelectedKeys?: string[];
}
export function requireSnapshot(report: DayEvaluation) {
  const s = report.snapshot;
  if (
    !report.exploration || s?.version !== 1 || !Array.isArray(s.sheets) ||
    s.sheets.length !== report.expected ||
    new Set(s.sheets.map((m) => m.key)).size !== report.expected ||
    s.sheets.some((m) =>
      !report.exploration!.manifest.some((f) => f.key === m.key) ||
      m.candidates.length
    )
  ) {
    throw new Error(
      "Cette ancienne préparation reste consultable, mais ne possède pas le dossier nécessaire à une reprise. Demandez une nouvelle exploration.",
    );
  }
  return s;
}
export function frozenQuery(
  report: DayEvaluation,
  id: string,
  now: Date,
): ReadQuery {
  const s = requireSnapshot(report), context = structuredClone(s.context);
  return {
    id,
    date: report.scope.date,
    context,
    sports: report.scope.sports as ReadQuery["sports"],
    sources: report.scope.sources.map((r) => ({
      ...r,
      sport: s.sheets.find((m) => m.match.sourceId === r.id)?.match.sport ??
        "football",
      payload: {},
    })),
    matches: s.sheets.map((m) => structuredClone(m.match)),
    catalog: buildCatalog([], context, report.scope.date, now),
  };
}
/** Compare sporting content, independently of publication IDs, prices and receipt times. */
function signature(s: MatchSheet) {
  const form = s.form
    ? {
      ...s.form,
      home: { ...s.form.home, observedAt: undefined, sourcePath: undefined },
      away: { ...s.form.away, observedAt: undefined, sourcePath: undefined },
    }
    : null;
  return JSON.stringify({
    key: s.key,
    home: s.match.home,
    away: s.match.away,
    kickoff: s.match.kickoff,
    status: s.match.status,
    competition: s.match.competition,
    facts: s.facts.map(({ id: _id, asOf: _asOf, ...f }) => f).sort((a, b) =>
      JSON.stringify(a).localeCompare(JSON.stringify(b))
    ),
    form,
  });
}
export function changedSheets(previous: DayEvaluation, current: MatchSheet[]) {
  const old = new Map(requireSnapshot(previous).sheets.map((s) => [s.key, s]));
  const next = new Map(current.map((s) => [s.key, s]));
  return {
    changedKeys: current.filter((s) =>
      old.has(s.key) && signature(old.get(s.key)!) !== signature(s)
    ).map((s) => s.key),
    addedKeys: current.filter((s) => !old.has(s.key)).map((s) => s.key),
    removedKeys: [...old.keys()].filter((key) => !next.has(key)),
  };
}
export function reusableRows(
  previous: DayEvaluation,
  current: MatchSheet[],
): MatchEvaluation[] {
  const old = new Map(requireSnapshot(previous).sheets.map((s) => [s.key, s]));
  return current.flatMap((s) => {
    const before = old.get(s.key),
      row = previous.rows.find((r) => r.key === s.key);
    if (!before || !row || signature(before) !== signature(s)) return [];
    const ref = (id: string) => {
      const fact = before.facts.find((f) => f.id === id);
      if (!fact) throw new Error("Preuve archivée absente.");
      const { id: _id, asOf: _asOf, ...content } = fact;
      return s.facts.find(({ id: _i, asOf: _a, ...f }) =>
        JSON.stringify(f) === JSON.stringify(content)
      )?.id;
    };
    const refs = row.references.map(ref),
      vigilance = row.vigilanceReferences.map(ref);
    if (refs.some((r) => !r) || vigilance.some((r) => !r)) return [];
    return [{
      ...structuredClone(row),
      references: refs as string[],
      vigilanceReferences: vigilance as string[],
    }];
  });
}
export function explorationView(
  report: DayEvaluation,
  now: Date,
  offset = 0,
  limit = 40,
) {
  if (!report.exploration) {
    return {
      legacy: true,
      evaluationId: report.id,
      rows: report.rows.slice(offset, offset + limit),
    };
  }
  const e = report.exploration,
    keys = e.manifest.slice(offset, offset + limit).map((m) => m.key);
  const byKey = (key: string) => {
    const m = e.manifest.find((m) => m.key === key)!,
      row = report.rows.find((r) => r.key === key);
    const sheet = report.snapshot?.sheets.find((s) => s.key === key);
    return {
      ...m,
      rank: e.decisions.find((d) => d.key === key)?.rank ?? null,
      retained: e.selectedKeys.includes(key),
      decision: e.decisions.find((d) => d.key === key)?.reason,
      reason: row?.reason ?? "Cette rencontre n’a pas encore été évaluée.",
      supportingFactIndexes: (row?.references ?? []).map((id) =>
        (e.evidence[key] ?? []).findIndex((f) => f.id === id)
      ).filter((index) => index >= 0),
      contradictions: (row?.vigilanceReferences ?? []).map((id) =>
        e.evidence[key]?.find((f) => f.id === id)
      ).filter(Boolean),
      limitations: row?.limitations ?? [],
      evidence: e.evidence[key] ?? [],
      form: e.forms[key] ?? null,
      homeLogo: sheet?.match.homeLogo ?? m.homeLogo ?? null,
      awayLogo: sheet?.match.awayLogo ?? m.awayLogo ?? null,
    };
  };
  return {
    schemaVersion: 1,
    evaluationId: report.id,
    createdAt: report.createdAt ?? e.createdAt,
    dataAsOf: report.snapshot?.asOf ?? e.createdAt,
    criterion: e.criterion,
    coverage: e.coverage,
    version: {
      ...(report.version ?? {
        rootId: report.id,
        parentId: null,
        mode: "initial" as const,
        changedKeys: [],
        addedKeys: [],
        removedKeys: [],
        reusedKeys: [],
      }),
      selectedAddedKeys: report.version?.previousSelectedKeys
        ? e.selectedKeys.filter((key) =>
          !report.version!.previousSelectedKeys!.includes(key)
        )
        : [],
      selectedRemovedKeys: report.version?.previousSelectedKeys
        ? report.version.previousSelectedKeys.filter((key) =>
          !e.selectedKeys.includes(key)
        )
        : [],
    },
    stale: now.getTime() - Date.parse(report.snapshot?.asOf ?? e.createdAt) >
        300000 ||
      e.manifest.some((m) => Date.parse(m.kickoff) <= now.getTime()),
    observations: e.selectedKeys.map(byKey),
    rows: keys.map(byKey),
    limitations: e.limitations,
    total: e.manifest.length,
    nextOffset: offset + limit < e.manifest.length ? offset + limit : null,
    budgetUsage: report.budgetUsage ?? null,
  };
}
/** Differences are computed against the owned parent archive, never against
 * today’s feed. A new ranking is not presented as changed sporting data. */
export function explorationChanges(
  current: DayEvaluation,
  parent: DayEvaluation,
) {
  if (
    !current.exploration || !parent.exploration ||
    current.version?.parentId !== parent.id
  ) {
    throw new Error(
      "La version précédente de cette préparation est inaccessible.",
    );
  }
  const old = parent.snapshot?.sheets ?? [],
    next = current.snapshot?.sheets ?? [];
  const match = (key: string) =>
    current.exploration!.manifest.find((m) => m.key === key) ??
      parent.exploration!.manifest.find((m) => m.key === key);
  const contents = (f: MatchSheet["facts"][number]) => {
    const { id: _id, asOf: _asOf, ...value } = f;
    return JSON.stringify(value);
  };
  return {
    evaluationId: current.id,
    parentId: parent.id,
    scope: {
      added: current.version.addedKeys.map(match),
      removed: current.version.removedKeys.map(match),
    },
    publications: current.version.changedKeys.map((key) => {
      const before = old.find((s) => s.key === key),
        after = next.find((s) => s.key === key);
      return {
        match: match(key),
        available: Boolean(before && after),
        beforeAsOf: before?.match.capturedAt ?? null,
        afterAsOf: after?.match.capturedAt ?? null,
        fields: ["status", "kickoff", "competition", "home", "away"].flatMap(
          (field) => {
            const b = obj(before?.match)[field], a = obj(after?.match)[field];
            return before && after && b !== a
              ? [{ field, before: b, after: a }]
              : [];
          },
        ),
        removedFacts: before && after
          ? before.facts.filter((f) =>
            !after.facts.some((a) => contents(a) === contents(f))
          )
          : [],
        addedFacts: before && after
          ? after.facts.filter((f) =>
            !before.facts.some((b) => contents(b) === contents(f))
          )
          : [],
        beforeForm: before?.form ?? null,
        afterForm: after?.form ?? null,
      };
    }),
    selection: {
      entered: current.exploration.selectedKeys.filter((key) =>
        !parent.exploration!.selectedKeys.includes(key)
      ).map(match),
      exited: parent.exploration.selectedKeys.filter((key) =>
        !current.exploration!.selectedKeys.includes(key)
      ).map(match),
    },
  };
}
export function compareExploration(report: DayEvaluation, keys: string[]) {
  if (
    !report.exploration || keys.length < 2 || keys.length > 10 ||
    new Set(keys).size !== keys.length
  ) {
    throw new Error(
      "Choisissez de deux à dix rencontres distinctes de cette préparation.",
    );
  }
  return {
    evaluationId: report.id,
    criterion: report.exploration.criterion,
    mode: "historical",
    comparisons: keys.map((key) => {
      const item = explainExplorationChoice(report, key);
      return {
        ...item,
        favorable: item.evidence.filter((f) =>
          item.evaluation?.references.includes(f.id)
        ),
        contradictions: item.evidence.filter((f) =>
          item.evaluation?.vigilanceReferences.includes(f.id)
        ),
        missing: [
          ...new Set([
            ...(item.evaluation?.limitations ?? ["Rencontre non évaluée."]),
            ...(item.form?.home.limitations ?? []),
            ...(item.form?.away.limitations ?? []),
          ]),
        ],
        conclusion: item.decision.retained
          ? "Retenue pour le critère archivé."
          : item.decision.reason === "stable_tie_break"
          ? "Équivalence départagée par l’ordre stable des identifiants."
          : item.evaluation?.reason ??
            "Données non évaluées ; aucune conclusion comparative.",
      };
    }),
    semantics:
      "Comparaison des faits archivés, sans actualisation ni appel IA.",
  };
}
