/** Offline replay of a PUBLIC demo publication. Never reads accounts or keys.
 * deno run --allow-read --allow-write tool/audit_generator_workshop.ts
 *   <football-day.json> <output-directory> [asOf] [day] */
import { buildCatalog } from "../supabase/functions/_shared/generator/catalog.ts";
import {
  type Context,
  type Intent,
  obj,
  rows,
} from "../supabase/functions/_shared/generator/contracts.ts";
import {
  compose,
  rankCandidates,
} from "../supabase/functions/_shared/generator/engine.ts";
import {
  assessCandidate,
  exploreCompositions,
} from "../supabase/functions/_shared/generator/workshop.ts";
const [path, output, asOf = "2026-10-08T12:00:00Z", day = "2026-10-10"] =
  Deno.args;
if (!path || !output) {
  throw new Error("Provide a public football day JSON and output directory");
}
const payload = obj(JSON.parse(await Deno.readTextFile(path)));
const now = new Date(asOf);
const fixtures = rows(obj(payload.raw).fixtures);
const readings = rows(obj(payload.computed).fixtures).flatMap((f) =>
  rows(f.readings)
);
const context: Context = {
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {
    football: {
      competitions: [...new Set(fixtures.map((f) => String(obj(f.league).id)))],
      readings: [...new Set(readings.map((r) => String(r.id)))],
      markets: ["matchResult", "doubleChance", "goalsTotal", "bothTeamsScore"],
    },
  },
};
const start = performance.now();
const catalog = buildCatalog(
  [{
    id: "public-demo-replay-2026-10-08",
    sport: "football",
    capturedAt: String(payload.captured_at),
    payload,
  }],
  context,
  day,
  now,
);
const catalogMs = Math.round((performance.now() - start) * 100) / 100;
const base: Intent = {
  action: "generate",
  date: day,
  sports: ["football"],
  tickets: [{ stake: 50, minimum: 300, maximum: null, kind: "total" }],
  diversify: false,
  requireEachSport: false,
  maxSelections: 6,
  ticketIndex: null,
  selectionIndex: null,
  marketIds: [],
  message: "",
};
const cases = [300, 500].map((goal) => {
  const intent = { ...base, tickets: [{ ...base.tickets[0], minimum: goal }] };
  const traces: unknown[] = [];
  const time = performance.now();
  const previous = compose(catalog.candidates, intent, context, {
    onSearch: (trace) => traces.push(trace),
  });
  const legacyMs = Math.round((performance.now() - time) * 100) / 100;
  const next = exploreCompositions(catalog.candidates, intent, context, {
    now,
  });
  const describe = (
    p: {
      home: string;
      away: string;
      selection: string;
      market: string;
      odds: number;
      bookmaker: string;
    },
  ) =>
    `${p.home} — ${p.away} · ${p.market} · ${p.selection} @ ${p.odds} (${p.bookmaker})`;
  return {
    goal,
    stake: 50,
    maxSelections: 6,
    legacyMs,
    legacyTraces: traces,
    legacy: previous.map((t) => ({
      conditions: t.picks.length,
      totalOdds: t.totalOdds,
      returnTotal: t.returnTotal,
      picks: t.picks.map(describe),
    })),
    workshop: next,
  };
});
const record = {
  auditVersion: 1,
  generatedFrom: path,
  day,
  asOf,
  profile:
    "Profil de test : toutes les compétitions/lectures de cette publication, quatre marchés. Ce n’est pas le profil personnel d’un utilisateur.",
  rawFixtureCount: fixtures.length,
  catalogMs,
  admissibleMatches: catalog.matchCount,
  candidates: catalog.candidates.length,
  businessSelections: new Set(
    catalog.candidates.map((c) =>
      JSON.stringify([c.sport, c.matchId, c.marketId, c.selection])
    ),
  ).size,
  candidateMatches: new Set(catalog.candidates.map((c) => c.matchId)).size,
  bookmakers: [...new Set(catalog.candidates.map((c) => c.bookmaker))],
  sources: catalog.sources,
  missing: catalog.missing,
  paidCalls: 0,
  providerSportCalls: 0,
  cases,
};
await Deno.mkdir(output, { recursive: true });
await Deno.writeTextFile(
  `${output}/workshop-replay.json`,
  JSON.stringify(record, null, 2),
);
const csv = (v: unknown) => '"' + String(v ?? "").replaceAll('"', '""') + '"';
const columns = [
  "Rang moteur actuel",
  "ID",
  "Rencontre",
  "Compétition",
  "Marché",
  "Sélection",
  "Cote",
  "Bookmaker",
  "Lectures directes",
  "Lectures de contexte",
  "Groupes de données",
  "Références redondantes",
  "Échantillon minimal",
  "Indépendance vérifiée",
];
const ranked = rankCandidates(catalog.candidates, base);
const lines = ranked.map((c, i) => {
  const a = assessCandidate(c, now);
  return [
    i + 1,
    c.id,
    `${c.home} — ${c.away}`,
    c.competition,
    c.market,
    c.selection,
    c.odds,
    c.bookmaker,
    a.directReferences.length,
    a.contextReferences.length,
    a.dataGroups.map((g) => g.group).join(" | "),
    a.redundantReferences,
    a.minimumSample,
    "Non",
  ]
    .map(csv).join(";");
});
await Deno.writeTextFile(
  `${output}/candidates.csv`,
  "\ufeff" + [columns.map(csv).join(";"), ...lines].join("\n") + "\n",
);
const md = [
  "# Rejeu du Générateur — publication publique",
  "",
  `Date examinée : **${day}**. Observation figée au **${asOf}**.`,
  "",
  record.profile,
  "",
  `**${fixtures.length} rencontres dans la publication**, ${catalog.matchCount} pertinentes pour ce profil de test, **${catalog.candidates.length} lignes de cotes admissibles**, ${record.businessSelections} sélections métier pour ${record.candidateMatches} rencontres.`,
  `Construction du catalogue : ${catalogMs} ms. Aucun appel IA ou API sportive.`,
  "",
  "Les variantes sont des possibilités pour la même mise de 50 €. Elles ne doivent pas être additionnées comme des mises simultanées. Les cotes sont celles de l’archive, pas une vérification actuelle.",
  "",
  "La recherche est bornée : les variantes non dominées concernent les compositions explorées/conservées, sans preuve d’optimalité globale. Groupes de données et échantillons ne sont pas des probabilités.",
  "",
];
for (const c of cases) {
  const r = c.workshop.report;
  md.push(
    `## Retour total visé : ${c.goal} €`,
    "",
    `Moteur actuel : ${c.legacyMs} ms ; traces ${
      JSON.stringify(c.legacyTraces)
    }.`,
    `Prototype : **${r.elapsedMs} ms**, **${r.exploredStates} états examinés**, ${r.feasibleObserved} compositions admissibles rencontrées avant déduplication ; ${r.paretoCount} non dominées dans l’archive conservée.`,
    `Limites : ${JSON.stringify(r.limited)}.`,
    "",
  );
  for (const old of c.legacy) {
    md.push(
      `### Première solution du moteur actuel · ${old.conditions} sélections`,
      "",
      `Cote ${old.totalOdds} · retour ${old.returnTotal} €.`,
      "",
      ...old.picks.map((p) => `- ${p}`),
      "",
    );
  }
  for (const a of c.workshop.alternatives) {
    md.push(
      `### Prototype · ${a.approach} · ${a.picks.length} sélections`,
      "",
      `Cote ${a.totalOdds} · retour ${a.returnTotal} €.`,
      "",
      ...a.picks.map((p) =>
        `- ${p.home} — ${p.away} · ${p.selection} @ ${p.odds} (${p.bookmaker})`
      ),
      "",
      `Repères : ${JSON.stringify(a.metrics)}.`,
      ...(a.comparison
        ? [
          `Différences : ${a.comparison.kept.length} conservées, ${a.comparison.removed.length} retirées, ${a.comparison.added.length} ajoutées, ${a.comparison.replaced.length} marchés/sélections remplacés.`,
        ]
        : []),
      "",
    );
  }
}
md.push(
  "## Liste brute",
  "",
  "[Toutes les lignes dans l’ordre actuel](candidates.csv) · [Rapport et références complets](workshop-replay.json).",
  "",
);
await Deno.writeTextFile(`${output}/replay.md`, md.join("\n"));
console.log(JSON.stringify(
  {
    ...record,
    cases: cases.map((c) => ({
      goal: c.goal,
      legacyMs: c.legacyMs,
      legacy: c.legacy.map((t) => ({
        conditions: t.conditions,
        totalOdds: t.totalOdds,
      })),
      workshopReport: c.workshop.report,
      alternatives: c.workshop.alternatives.map((a) => ({
        approach: a.approach,
        conditions: a.picks.length,
        totalOdds: a.totalOdds,
      })),
    })),
  },
  null,
  2,
));
