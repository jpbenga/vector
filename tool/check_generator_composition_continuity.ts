/** Offline integration on captured PUBLIC publications, with actual server pricing.
 * No network permission, no paid model call, no mutation of remote sessions.
 * deno run --allow-read --allow-write tool/check_generator_composition_continuity.ts <football capture> <hockey capture> <report>
 */
import assert from "node:assert/strict";
import { ConversationReader } from "../supabase/functions/_shared/generator/conversation_tools.ts";
import {
  type ConversationPlan,
  initialIntent,
  rememberTurn,
} from "../supabase/functions/_shared/generator/conversation_memory.ts";
import {
  type Context,
  obj,
  rows,
  type Sport,
  type State,
} from "../supabase/functions/_shared/generator/contracts.ts";
import { type Source } from "../supabase/functions/_shared/generator/catalog.ts";
import { analysisCandidates } from "../supabase/functions/_shared/generator/analysis.ts";
const [footballPath, hockeyPath, reportPath] = Deno.args;
if (!reportPath) throw Error("Three arguments required");
const captures = await Promise.all(
  [footballPath, hockeyPath].map(async (p) =>
    JSON.parse(await Deno.readTextFile(p))
  ),
);
const allSources = captures.flatMap((c) => c.page.sources) as Source[];
const day = captures[0].date;
assert.equal(day, captures[1].date);
const asOf = captures.map((c) => c.asOf).sort().at(-1)!;
const now = new Date(asOf);
const context: Context = {
  origin: "profile",
  scope: "discovery",
  configurationPolicy: "request",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {
    football: { competitions: [], readings: [], markets: [] },
    hockey: { competitions: [], readings: [], markets: [] },
  },
};
const sourceReads: { date: string; sports: Sport[] }[] = [];
const reads = {
  sources: async () => {
    throw Error("Saved pages must be used");
  },
  daySources: async (_c: Context, date: string, sports: Sport[]) => {
    sourceReads.push({ date, sports });
    const sources = allSources.filter((s) => sports.includes(s.sport));
    const count = captures.filter((c) => sports.includes(c.sport)).reduce(
      (n, c) => n + c.manifest.total,
      0,
    );
    return {
      sources,
      coverage: {
        expected: count,
        loaded: count,
        complete: true,
        pages: Math.ceil(count / 50),
        bytes: JSON.stringify(sources).length,
      },
    };
  },
};
const makeReader = (message: string, state: State | null = null) =>
  new ConversationReader({
    context,
    date: day,
    now,
    state,
    message,
    id: "offline-current-publications",
  }, reads);
const search = (sports: Sport[]) => ({
  date: day,
  sports,
  view: "all",
  radarKind: "teams",
  query: null,
  offset: 0,
  limit: 60,
});
const makePlan = (
  sports: Sport[],
  marketIds: string[] = [],
  keys: string[] = [],
  stake: number | null = 30,
) => ({
  intent: {
    ...initialIntent(context, day),
    action: "generate",
    sports,
    view: "all",
    marketIds,
    tickets: [{
      stake,
      minimum: null,
      maximum: null,
      kind: "unspecified",
      minSelections: 2,
      maxSelections: 2,
    }],
    minSelections: 2,
    maxSelections: 2,
  },
  changedFields: [
    "view",
    "marketIds",
    "tickets",
    "minSelections",
    "maxSelections",
  ],
  newTask: false,
  focusMode: keys.length ? "choose" : "clear",
  focusKeys: keys,
} as ConversationPlan);
const cases: unknown[] = [];
for (const sport of ["hockey", "football"] as Sport[]) {
  const r = makeReader(
    `Depuis Tous en ${sport} aujourd’hui, prépare deux rencontres.`,
  );
  const q = obj(await r.execute("search_matches", search([sport])));
  const matches = rows(q.matches);
  assert.equal(
    matches.length,
    captures.find((c) => c.sport === sport).manifest.total,
  );
  const detailRows = [];
  for (let i = 0; i < matches.length; i += 8) {
    detailRows.push(
      ...rows(
        await r.execute("read_matches", {
          queryId: q.queryId,
          matchKeys: matches.slice(i, i + 8).map((m) => m.key),
        }),
      ),
    );
  }
  const scope = r.queries.get(String(q.queryId))!;
  const admissible = analysisCandidates(
    scope.catalog,
    initialIntent(context, day),
    now,
  );
  for (
    const market of sport === "hockey"
      ? ["result_regulation", "double_chance_regulation", "unrecognized_market"]
      : ["matchResult", "doubleChance"]
  ) {
    const eligible = admissible.filter((c) =>
      market === "unrecognized_market" || c.marketId === market
    );
    let keys = [
      ...new Set(
        eligible.map((c) =>
          `${c.sport}:${c.matchId.replace(/^api-fixture-/, "")}`
        ),
      ),
    ].slice(0, 2);
    if (market === "unrecognized_market") {
      keys = matches.slice(0, 2).map((m) => String(m.key));
    }
    const p = makePlan([sport], [market], keys);
    const started = performance.now();
    const projection = obj(
      await r.execute("read_composition_options", { plan: p }),
    );
    assert.deepEqual(obj(projection.intent).sports, [sport]);
    assert.equal(projection.queryId, q.queryId);
    assert.equal(r.queries.size, 1);
    const preview = r.previews.get(String(projection.projectionId))!;
    const tickets = preview.next.tickets;
    for (const ticket of tickets) {
      assert.equal(ticket.picks.length, 2);
      assert.ok(
        ticket.picks.every((c) => c.sport === sport && c.marketId === market),
      );
      assert.equal(
        ticket.totalOdds,
        Number(ticket.picks.reduce((n, c) => n * c.odds, 1).toFixed(2)),
      );
    }
    if (market === "unrecognized_market") assert.equal(tickets.length, 0);
    cases.push({
      sport,
      market,
      found: matches.length,
      examined: detailRows.length,
      admissibleMatches: new Set(eligible.map((c) => c.matchId)).size,
      queryId: q.queryId,
      projectionId: projection.projectionId,
      result: projection.result,
      tickets: tickets.map((t) => ({
        id: t.id,
        totalOdds: t.totalOdds,
        stake: t.stake,
        picks: t.picks.map((c) => ({
          matchId: c.matchId,
          marketId: c.marketId,
          scope: c.scope,
          selection: c.selection,
          odds: c.odds,
          oddsAt: c.oddsAt,
          sourceId: c.snapshotId,
        })),
      })),
      serverCalculationMs: Math.round(performance.now() - started),
    });
    if (tickets.length) {
      const focus = tickets[0].picks.map((c) => ({
        sport: c.sport,
        matchId: c.matchId,
        match: `${c.home} — ${c.away}`,
      }));
      rememberTurn(
        preview.next,
        null,
        preview.intent,
        focus,
        r.consultations(),
      );
      const next = makeReader(
        "Remplace uniquement la première sélection, garde les autres contraintes.",
        preview.next,
      );
      const adjustment = {
        ...makePlan([sport]),
        intent: {
          ...preview.intent,
          action: "replace",
          selectionIndex: 0,
          ticketIndex: 0,
          referenceTicketId: tickets[0].id,
        },
        changedFields: [],
        focusMode: "keep",
        focusKeys: [],
      } as ConversationPlan;
      delete adjustment.intent.fixtureFocus; // Derived server field, never model input.
      const changed = obj(
        await next.execute("read_composition_options", { plan: adjustment }),
      );
      assert.deepEqual(obj(changed.intent).sports, [sport]);
      assert.deepEqual(obj(changed.intent).tickets, preview.intent.tickets);
      const n = next.previews.get(String(changed.projectionId))!.next;
      for (const revised of n.pending ?? []) {
        assert.equal(revised.picks[1].id, tickets[0].picks[1].id);
        assert.equal(revised.stake, tickets[0].stake);
      }
      cases.push({
        sport,
        operation: "next-message targeted replacement",
        result: changed.result,
        changedTickets: n.pending?.length ?? 0,
        untouchedSelectionPreserved: true,
        sports: obj(changed.intent).sports,
      });
    }
  }
}
const mixed = makeReader("Compare football et hockey depuis Tous.");
const q = obj(
  await mixed.execute("search_matches", search(["football", "hockey"])),
);
assert.equal(q.total, captures.reduce((n, c) => n + c.manifest.total, 0));
const p = makePlan(["football", "hockey"]);
p.intent.requireEachSport = true;
p.changedFields.push("requireEachSport");
const projection = obj(
  await mixed.execute("read_composition_options", { plan: p }),
);
assert.deepEqual(obj(projection.intent).sports, ["football", "hockey"]);
for (
  const t of mixed.previews.get(String(projection.projectionId))!.next.tickets
) {
  assert.deepEqual([...new Set(t.picks.map((c) => c.sport))].sort(), [
    "football",
    "hockey",
  ]);
}
cases.push({
  operation: "explicit multisport",
  found: q.total,
  result: projection.result,
});
const report = {
  date: day,
  asOf,
  modelCalls: 0,
  providerCalls: 0,
  realPricesAndFacts: true,
  sourceReads,
  cases,
};
await Deno.writeTextFile(reportPath, JSON.stringify(report, null, 2));
console.log(
  JSON.stringify({
    cases: cases.length,
    modelCalls: 0,
    providerCalls: 0,
    report: reportPath,
  }),
);
