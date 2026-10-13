/** Offline visual corpus and publication audit. No model/provider requests. */
import { ConversationReader } from "../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  type Context,
  obj,
  rows,
} from "../supabase/functions/_shared/generator/contracts.ts";
import {
  buildExplorationReport,
  explorationCriterion,
} from "../supabase/functions/_shared/generator/exploration.ts";
import {
  type DayEvaluation,
  prepareMatchSheets,
} from "../supabase/functions/_shared/generator/match_evaluation.ts";
import {
  compareExploration,
  explorationChanges,
  explorationView,
} from "../supabase/functions/_shared/generator/exploration_continuity.ts";
import type { Source } from "../supabase/functions/_shared/generator/catalog.ts";
const output = "output/generator-exploration-review";
await Deno.mkdir(output, { recursive: true });
async function prepare(path: string) {
  const input = JSON.parse(await Deno.readTextFile(path)),
    sources = input.sources as Source[];
  const now = new Date(input.asOf);
  const readingIds = [
    ...new Set(
      sources.flatMap((s) =>
        rows(obj(s.payload.computed).fixtures).flatMap((f) =>
          rows(f.readings).map((r) => String(r.id))
        )
      ),
    ),
  ];
  const context: Context = {
    view: "all",
    origin: "profile",
    scope: "strict",
    timezone: "Europe/Paris",
    budget: 0,
    preferences: {
      football: {
        competitions: [],
        readings: path.includes("_ui_")
          ? [
            "form_advantage",
            "improving_form",
            "negative_streak",
            "winning_streak",
          ]
          : readingIds,
        markets: [],
      },
    },
  };
  const reader = new ConversationReader({
    context,
    date: input.day,
    now,
    state: null,
    id: "offline-review",
    message: "Dix rencontres selon les lectures publiées et la forme",
  }, { sources: async () => sources });
  const query = await reader.query(input.day, ["football"], "all", "teams");
  const criterion = explorationCriterion({
    request: "Dix rencontres selon les lectures publiées et la forme",
    criteria: "Lectures publiées et forme",
    query,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  });
  const sheets = prepareMatchSheets(query, now, criterion);
  return { input, context, query, criterion, sheets, now };
}
const ui = await prepare("test/fixtures/generator_published_ui_sources.json");
// Mechanical grading for visual inspection only. Each argument is an exact
// published fact. The scores do not establish real sporting relevance.
function report(id: string): DayEvaluation {
  const r: DayEvaluation = {
    id,
    queryId: ui.query.id,
    scope: {
      date: ui.input.day,
      view: "all",
      sports: ["football"],
      sources: ui.query.sources.map((s) => ({
        id: s.id,
        capturedAt: s.capturedAt,
      })),
    },
    criteria: ui.criterion.criteria,
    model: "offline-ui-grading",
    expected: ui.sheets.length,
    prepared: ui.sheets.length,
    evaluated: ui.sheets.length,
    complete: true,
    elapsedMs: 0,
    inputBytes: 0,
    batches: 0,
    failed: [],
    rows: [],
    snapshot: {
      version: 1,
      asOf: ui.input.asOf,
      context: ui.context,
      sheets: structuredClone(ui.sheets),
    },
    version: {
      rootId: id,
      parentId: null,
      mode: "initial",
      changedKeys: [],
      addedKeys: [],
      removedKeys: [],
      reusedKeys: [],
    },
  };
  r.rows = r.snapshot!.sheets.map((s) => {
    const formFacts = s.facts.filter((f) =>
      f.family === "form" && f.source === "scenario"
    );
    const proof = formFacts[0] ?? s.facts.find((f) => f.source === "reading") ??
      s.facts[0];
    const pair = s.form?.home.results.length && s.form?.away.results.length
      ? ["home", "away"].map((side) => {
        const f = s.form![side as "home" | "away"],
          points = f.results.reduce(
            (n, r) => n + (r.result === "W" ? 3 : r.result === "D" ? 1 : 0),
            0,
          );
        return `${s.match[side as "home" | "away"]} : ${points}/${
          f.results.length * 3
        } points`;
      }).join(" · ")
      : null;
    return {
      key: s.key,
      fit: proof
        ? (s.form?.home.results.length && s.form?.away.results.length ? 3 : 2)
        : 0,
      status: proof ? "supported" : "insufficient",
      candidateId: null,
      references: formFacts.length
        ? formFacts.map((f) => f.id)
        : proof
        ? [proof.id]
        : [],
      vigilanceReferences: [],
      reason: proof
        ? pair ?? proof.text.slice(0, 180)
        : "Aucun argument publié pour ce critère.",
      limitations: [
        ...(s.form?.home.limitations ?? []),
        ...(s.form?.away.limitations ?? []),
      ],
    };
  });
  return r;
}
const initial = report("11111111-1111-4111-8111-111111111111");
initial.exploration = await buildExplorationReport(
  initial,
  initial.snapshot!.sheets,
  ui.criterion,
  ui.now,
);
const refreshed = structuredClone(initial);
refreshed.id = "22222222-2222-4222-8222-222222222222";
// Controlled version difference: remove one real publication from the scope.
// No changed sporting statistic or imaginary result is introduced.
const gone = initial.exploration.selectedKeys[0];
refreshed.snapshot!.sheets = refreshed.snapshot!.sheets.filter((s) =>
  s.key !== gone
);
refreshed.rows = refreshed.rows.filter((s) => s.key !== gone);
refreshed.expected--;
refreshed.prepared--;
refreshed.evaluated--;
refreshed.version = {
  rootId: initial.id,
  parentId: initial.id,
  mode: "refresh",
  changedKeys: [],
  addedKeys: [],
  removedKeys: [gone],
  reusedKeys: refreshed.rows.map((r) => r.key),
  previousSelectedKeys: initial.exploration.selectedKeys,
};
refreshed.exploration = await buildExplorationReport(
  refreshed,
  refreshed.snapshot!.sheets,
  ui.criterion,
  ui.now,
);
const keys = initial.exploration.selectedKeys;
const fixture = {
  sourceNote: ui.input.sourceNote,
  initial: explorationView(initial, ui.now),
  resumed: explorationView(initial, ui.now),
  refreshed: explorationView(refreshed, ui.now),
  comparison: compareExploration(initial, keys.slice(0, 4)),
  comparisonTwo: compareExploration(initial, keys.slice(0, 2)),
  changes: explorationChanges(refreshed, initial),
};
await Deno.writeTextFile(
  "test/fixtures/generator_exploration_published_review.json",
  JSON.stringify(fixture, null, 2),
);
const big = await prepare("test/fixtures/generator_published_day.json");
const audit = {
  schemaVersion: 1,
  mode: "offline-publication-audit",
  day: big.input.day,
  asOf: big.input.asOf,
  sourceSha256: big.input.originalSha256,
  sourceCount: big.query.sources.length,
  fixtures: big.query.matches.length,
  withFacts: big.sheets.filter((s) => s.facts.length).length,
  withVerifiedDomesticForm:
    big.sheets.filter((s) =>
      s.form?.home.results.length && s.form?.away.results.length
    ).length,
  withPublishedReadings:
    big.sheets.filter((s) => s.facts.some((f) => f.source === "reading"))
      .length,
  modelCalls: 0,
  providerCalls: 0,
  context: big.context,
  criterion: big.criterion,
  limitations: [
    ...new Set(
      big.sheets.flatMap(
        (s) => [
          ...(s.form?.home.limitations ?? []),
          ...(s.form?.away.limitations ?? []),
        ],
      ),
    ),
  ],
  uiFixtures: ui.query.matches.length,
  uiRetained: keys.length,
  uiFormVerified:
    ui.sheets.filter((s) =>
      s.form?.home.results.length && s.form?.away.results.length
    ).length,
};
await Deno.writeTextFile(
  `${output}/publication-audit.json`,
  JSON.stringify(audit, null, 2),
);
console.log(
  JSON.stringify({ ...audit, context: undefined, criterion: undefined }),
);
