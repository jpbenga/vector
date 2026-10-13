import assert from "node:assert/strict";
import { explorationDay } from "./exploration_cases.ts";
import { buildExplorationReport } from "./exploration.ts";
import { type DayEvaluation, prepareMatchSheets } from "./match_evaluation.ts";
import {
  changedSheets,
  explorationChanges,
  explorationView,
} from "./exploration_continuity.ts";
import { now } from "./evaluation_cases.ts";
Deno.test("version differences separate scope, changed sporting publications and ranking membership; price/receipt changes are not sporting changes", async () => {
  const f = await explorationDay(12),
    sheets = prepareMatchSheets(f.query, now, f.criterion);
  const parent: DayEvaluation = {
    id: "parent",
    queryId: f.query.id,
    scope: {
      date: f.query.date,
      view: "all",
      sports: ["football"],
      sources: [],
    },
    criteria: f.criterion.criteria,
    model: "test",
    expected: 12,
    prepared: 12,
    evaluated: 12,
    complete: true,
    elapsedMs: 0,
    inputBytes: 0,
    batches: 0,
    failed: [],
    rows: sheets.map((s, i) => ({
      key: s.key,
      fit: i === 0 ? 4 : 3,
      status: "supported",
      candidateId: null,
      references: [s.facts[0].id],
      vigilanceReferences: [],
      reason: s.facts[0].text,
      limitations: [],
    })),
    snapshot: {
      version: 1,
      asOf: now.toISOString(),
      context: f.context,
      sheets,
    },
  };
  parent.exploration = await buildExplorationReport(
    parent,
    sheets,
    f.criterion,
    now,
  );
  const unchanged = structuredClone(sheets);
  unchanged[0].match.capturedAt = "2026-10-09T12:00:00Z";
  unchanged[0].match.sourceId = "different";
  for (const fact of unchanged[0].facts) {
    fact.asOf = "2026-10-09T12:00:00Z";
    fact.id = "changed-" + fact.id;
  }
  assert.equal(changedSheets(parent, unchanged).changedKeys.length, 0);
  const next = structuredClone(parent), changed = next.snapshot!.sheets[0];
  changed.facts[0].text = "Modification contrôlée du fait publié.";
  changed.match.status = "FT";
  next.snapshot!.sheets.pop();
  next.rows.pop();
  next.rows[0].fit = 0;
  next.rows[0].status = "insufficient";
  next.rows[0].references = [];
  next.id = "child";
  next.expected--;
  next.prepared--;
  next.evaluated--;
  next.exploration = await buildExplorationReport(
    next,
    next.snapshot!.sheets,
    f.criterion,
    now,
  );
  next.version = {
    rootId: parent.id,
    parentId: parent.id,
    mode: "refresh",
    ...changedSheets(parent, next.snapshot!.sheets),
    reusedKeys: [],
    previousSelectedKeys: parent.exploration.selectedKeys,
  };
  const delta = explorationChanges(next, parent);
  assert.equal(delta.scope.removed.length, 1);
  assert.equal(delta.scope.added.length, 0);
  assert.equal(delta.publications.length, 1);
  assert.equal(delta.publications[0].match?.key, changed.key);
  assert.ok(
    delta.publications[0].fields.some((v) =>
      v.field === "status" && v.after === "FT"
    ),
  );
  assert.equal(delta.publications[0].addedFacts[0].text, changed.facts[0].text);
  assert.equal(
    delta.publications[0].removedFacts[0].text,
    parent.snapshot!.sheets[0].facts[0].text,
  );
  assert.ok(delta.selection.exited.some((m) => m?.key === changed.key));
  const view = explorationView(parent, now);
  assert.equal(view.observations![0].supportingFactIndexes.length, 1);
  assert.throws(() =>
    explorationChanges(next, { ...parent, id: "another-owner-report" })
  );
});
