/** Bounded composition protocol, enabled only by the workshop handler.
 * Alternatives share ONE stake; they are proposals, not simultaneous tickets.
 * All ranks describe evidence and construction, never a probability. */
import {
  calendarDay,
  type Candidate,
  type Context,
  type Intent,
  type Target,
} from "./contracts.ts";
import { compatible, compositionKey, totals } from "./engine.ts";

const fixtureKey = (c: Candidate) => `${c.sport}:${c.matchId}`;
const selectionKey = (c: Candidate) =>
  JSON.stringify([
    c.sport,
    c.matchId,
    c.marketId,
    c.selection.normalize("NFKC").trim().toLowerCase().replace(/\s+/g, " "),
  ]);
export interface CandidateAssessment {
  directReferences: string[];
  vigilanceReferences: string[];
  contextReferences: string[];
  dataGroups: { group: string; references: string[] }[];
  redundantReferences: number;
  minimumSample: number;
  quoteAgeHours: number;
  sourceReferences: string[];
  independence: "unverified";
  contradictions: "not_published_per_market";
  history: "descriptive_only" | "not_available";
  warnings: string[];
  exclusions: string[];
}
/** Conservative proxy for lineage, pending publication of windows/match IDs.
 * Venue and form may reuse results. Radar/scenarios never add another group. */
export function assessCandidate(c: Candidate, now: Date): CandidateAssessment {
  const direct = c.evidence.filter((e) =>
    e.source === "reading" && e.supportsMarket !== false
  );
  const groups = new Map<string, string[]>();
  for (const e of direct) {
    const group = ["form", "venue"].includes(e.family)
      ? "recent_results"
      : e.family;
    groups.set(group, [...(groups.get(group) ?? []), e.id]);
  }
  const exclusions: string[] = [];
  const age = (value: string) => (now.getTime() - Date.parse(value)) / 3600000;
  const quoteAgeHours = age(c.oddsAt);
  if (!direct.length) exclusions.push("missing_direct_market_support");
  if (direct.some((e) => !Number.isFinite(e.sample) || e.sample < 3)) {
    exclusions.push("insufficient_sample");
  }
  if (
    direct.some((e) =>
      !Number.isFinite(age(e.asOf)) || age(e.asOf) < -1 / 60 || age(e.asOf) > 36
    )
  ) {
    exclusions.push("stale_or_invalid_evidence");
  }
  if (
    !Number.isFinite(quoteAgeHours) || quoteAgeHours < -1 / 60 ||
    quoteAgeHours > 48
  ) {
    exclusions.push("stale_or_invalid_quote");
  }
  if (!Number.isFinite(c.odds) || c.odds <= 1 || c.odds > 100) {
    exclusions.push("invalid_odds");
  }
  if (
    !Number.isFinite(Date.parse(c.kickoff)) ||
    Date.parse(c.kickoff) <= now.getTime()
  ) {
    exclusions.push("not_prematch");
  }
  return {
    directReferences: direct.map((e) => e.id),
    vigilanceReferences: c.evidence.filter((e) => e.role === "vigilance").map((
      e,
    ) => e.id),
    contextReferences: c.evidence.filter((e) => !direct.includes(e)).map((e) =>
      e.id
    ),
    dataGroups: [...groups].map(([group, references]) => ({
      group,
      references,
    })),
    redundantReferences: direct.length - groups.size,
    minimumSample: direct.length ? Math.min(...direct.map((e) => e.sample)) : 0,
    quoteAgeHours,
    sourceReferences: [c.snapshotId],
    independence: "unverified",
    contradictions: "not_published_per_market",
    history: c.warnings.some((w) => w.startsWith("Bilan descriptif"))
      ? "descriptive_only"
      : "not_available",
    warnings: [...c.warnings],
    exclusions,
  };
}
export function compareCompositions(before: Candidate[], after: Candidate[]) {
  const old = new Map(before.map((c) => [fixtureKey(c), c]));
  const next = new Map(after.map((c) => [fixtureKey(c), c]));
  const kept: string[] = [], removed: string[] = [], added: string[] = [];
  const replaced: { fixture: string; before: string; after: string }[] = [];
  for (const [fixture, c] of old) {
    const other = next.get(fixture);
    if (!other) removed.push(c.id);
    else if (selectionKey(c) === selectionKey(other)) kept.push(c.id);
    else replaced.push({ fixture, before: c.id, after: other.id });
  }
  for (const [fixture, c] of next) if (!old.has(fixture)) added.push(c.id);
  const changes = added.length + removed.length + replaced.length;
  return {
    kept,
    removed,
    added,
    replaced,
    sharedFixtures: [...old.keys()].filter((k) => next.has(k)).length,
    sharedSelections: kept.length,
    significant: changes > 0 && (before.length !== after.length ||
      changes >=
        Math.max(1, Math.ceil(Math.max(before.length, after.length) / 3))),
  };
}
export interface CompositionMetrics {
  conditions: number;
  meanDataGroups: number;
  meanVigilanceSignals: number;
  minimumSample: number;
  redundantReferences: number;
  maximumQuoteAgeHours: number;
  targetDistance: number;
  largestOddsContribution: number;
}
export interface CompositionProposal {
  approach:
    | "balanced"
    | "fewer_matches"
    | "other_markets"
    | "different_matches";
  fingerprint: string;
  picks: Candidate[];
  stake: number;
  totalOdds: number;
  returnTotal: number;
  netProfit: number;
  metrics: CompositionMetrics;
  assessments: CandidateAssessment[];
  comparison: ReturnType<typeof compareCompositions> | null;
}
export interface WorkshopOptions {
  now: Date;
  targetIndex?: number;
  reference?: Candidate[];
  excludedCompositions?: string[];
  /** A changed stake/constraint may legitimately reuse a composition as a new version. */
  allowSameComposition?: boolean;
  maxFixtures?: number;
  maxBookmakers?: number;
  beamWidth?: number;
  maxExpansions?: number;
  maxAlternatives?: number;
  /** Keep every reference fixture, while reconsidering its market/selection. */
  preserveFixtures?: boolean;
  requiredFixtureKeys?: string[];
  /** Retained selections for a targeted substitution. */
  fixed?: Candidate[];
  maxComputeMs?: number;
}
type Item = { candidate: Candidate; assessment: CandidateAssessment };
type Node = {
  picks: Candidate[];
  assessments: CandidateAssessment[];
  product: number;
  last: number;
  key: string;
  metrics: CompositionMetrics;
};
export function targetBounds(intent: Intent, target: Target) {
  if (intent.targetOdds != null && target.stake != null) {
    const goal = intent.targetOdds * target.stake -
      (target.kind === "net" ? target.stake : 0);
    return {
      minimum: Math.round(goal * .9 * 100) / 100,
      maximum: Math.round(goal * 1.1 * 100) / 100,
    };
  }
  if (
    intent.goalMode === "around" && target.minimum !== null &&
    target.maximum === null
  ) {
    return {
      minimum: Math.round(target.minimum * .9 * 100) / 100,
      maximum: Math.round(target.minimum * 1.1 * 100) / 100,
    };
  }
  return { minimum: target.minimum, maximum: target.maximum };
}
const targetValue = (product: number, target: Target) =>
  product * target.stake! - (target.kind === "net" ? target.stake! : 0);
const distance = (product: number, target: Target) => {
  if (target.minimum === null && target.maximum === null) return 0;
  const goal = target.minimum !== null && target.maximum !== null
    ? (target.minimum + target.maximum) / 2
    : target.minimum ?? target.maximum!;
  return Math.abs(targetValue(product, target) - goal) / Math.max(1, goal);
};
function metrics(
  picks: Candidate[],
  assessments: CandidateAssessment[],
  product: number,
  target: Target,
): CompositionMetrics {
  const logarithm = Math.log(product);
  return {
    conditions: picks.length,
    meanDataGroups: assessments.length
      ? assessments.reduce((n, a) => n + a.dataGroups.length, 0) /
        assessments.length
      : 0,
    meanVigilanceSignals: assessments.length
      ? assessments.reduce(
        (n, a) => n + new Set(a.vigilanceReferences).size,
        0,
      ) / assessments.length
      : 0,
    minimumSample: assessments.length
      ? Math.min(...assessments.map((a) => a.minimumSample))
      : 0,
    redundantReferences: assessments.reduce(
      (n, a) => n + a.redundantReferences,
      0,
    ),
    maximumQuoteAgeHours: assessments.length
      ? Math.max(...assessments.map((a) => a.quoteAgeHours))
      : 0,
    targetDistance: distance(product, target),
    largestOddsContribution: picks.length && logarithm > 0
      ? Math.max(...picks.map((p) => Math.log(p.odds) / logarithm))
      : 0,
  };
}
export function measureComposition(
  picks: Candidate[],
  target: Target,
  now: Date,
) {
  return metrics(
    picks,
    picks.map((p) => assessCandidate(p, now)),
    picks.reduce((n, p) => n * p.odds, 1),
    target,
  );
}
/** Explicit ordinal heuristics. A sample is not a calibrated confidence. */
function order(a: Node, b: Node, lane = 0): number {
  const x = a.metrics, y = b.metrics;
  const quality = () =>
    y.meanDataGroups - x.meanDataGroups ||
    x.meanVigilanceSignals - y.meanVigilanceSignals ||
    Math.min(20, y.minimumSample) - Math.min(20, x.minimumSample) ||
    x.redundantReferences - y.redundantReferences;
  return (lane === 1
    ? x.targetDistance - y.targetDistance || quality()
    : lane === 2
    ? x.conditions - y.conditions || quality() ||
      x.targetDistance - y.targetDistance
    : lane === 3
    ? x.largestOddsContribution - y.largestOddsContribution || quality() ||
      x.targetDistance - y.targetDistance
    : quality() || x.targetDistance - y.targetDistance ||
      x.conditions - y.conditions) || a.key.localeCompare(b.key);
}
function retain(nodes: Node[], limit: number): Node[] {
  const selected = new Map<string, Node>();
  const perLane = Math.max(1, Math.floor(limit / 6));
  for (let lane = 0; lane < 4; lane++) {
    for (
      const node of [...nodes].sort((a, b) => order(a, b, lane)).slice(
        0,
        perLane,
      )
    ) selected.set(node.key, node);
  }
  // Preserve lower/upper quote structures as well as the strongest current rank.
  const buckets = new Set<number>();
  for (const node of [...nodes].sort((a, b) => order(a, b))) {
    const bucket = Math.floor(Math.log(node.product) / .2);
    if (!buckets.has(bucket)) {
      selected.set(node.key, node);
      buckets.add(bucket);
    }
    if (selected.size >= limit) break;
  }
  for (const node of [...nodes].sort((a, b) => order(a, b))) {
    if (selected.size >= limit) break;
    selected.set(node.key, node);
  }
  return [...selected.values()].slice(0, limit);
}
function dominates(a: Node, b: Node): boolean {
  const x = a.metrics, y = b.metrics;
  const comparisons = [
    x.conditions <= y.conditions,
    x.meanDataGroups >= y.meanDataGroups,
    x.meanVigilanceSignals <= y.meanVigilanceSignals,
    x.minimumSample >= y.minimumSample,
    x.redundantReferences <= y.redundantReferences,
    x.targetDistance <= y.targetDistance,
    x.largestOddsContribution <= y.largestOddsContribution,
    x.maximumQuoteAgeHours <= y.maximumQuoteAgeHours,
  ];
  return comparisons.every(Boolean) && JSON.stringify(x) !== JSON.stringify(y);
}

/** Input must come from the server buildCatalog, never from client/LLM picks. */
export function exploreCompositions(
  candidates: Candidate[],
  intent: Intent,
  context: Context,
  options: WorkshopOptions,
) {
  const started = performance.now();
  const target = intent.tickets[options.targetIndex ?? 0];
  const metricsTarget =
    target && intent.targetOdds != null && target.stake != null
      ? {
        ...target,
        kind: "total" as const,
        minimum: intent.targetOdds * target.stake,
        maximum: null,
      }
      : target;
  const bounds = target
    ? targetBounds(intent, target)
    : { minimum: null, maximum: null };
  const maxSelections = intent.maxSelections ?? 6;
  const maxFixtures = Math.max(1, options.maxFixtures ?? 48);
  const maxBookmakers = Math.max(1, options.maxBookmakers ?? 4);
  const beamWidth = Math.max(6, options.beamWidth ?? 48);
  const maxExpansions = Math.max(1, options.maxExpansions ?? 500000);
  const excluded = new Set(options.excludedCompositions ?? []);
  if (options.reference && !options.allowSameComposition) {
    excluded.add(compositionKey(options.reference));
  }
  const exclusions: { candidateId: string; reasons: string[] }[] = [];
  const requiredFixtures = options.preserveFixtures
    ? new Set(
      options.requiredFixtureKeys ?? (options.reference ?? []).map(fixtureKey),
    )
    : null;
  const report = {
    inputCandidates: candidates.length,
    eligibleCandidates: 0,
    retainedCandidates: 0,
    eligibleFixtures: 0,
    retainedFixtures: 0,
    bookmakersExamined: 0,
    exploredStates: 0,
    feasibleObserved: 0,
    paretoCount: 0,
    limited: {
      fixtures: false,
      bookmakers: false,
      states: false,
      beam: false,
      time: false,
    },
    elapsedMs: 0,
    exclusions,
  };
  const alternatives: CompositionProposal[] = [];
  const finish = () => {
    report.elapsedMs = Math.round((performance.now() - started) * 100) / 100;
    return {
      protocol: "lector-workshop-v1" as const,
      alternatives,
      report,
      status: alternatives.length
        ? "compositions_found"
        : "none_found_in_bounded_search",
      limitations: [
        "Heuristiques de comparaison non calibrées ; aucune probabilité de réussite.",
        "Indépendance statistique non établie : groupes de données estimés conservativement.",
        "Contradictions par marché et cohortes historiques comparables non publiées.",
      ],
    };
  };
  if (
    !target || target.stake === null || target.stake <= 0 ||
    target.stake > context.budget ||
    (target.kind === "unspecified" &&
      (target.minimum !== null || target.maximum !== null)) ||
    (requiredFixtures !== null &&
      (!requiredFixtures.size || requiredFixtures.size > maxSelections))
  ) return finish();
  const all: Item[] = candidates.flatMap((candidate) => {
    const assessment = assessCandidate(candidate, options.now);
    const pref = context.preferences[candidate.sport];
    const reasons = [...assessment.exclusions];
    if (requiredFixtures && !requiredFixtures.has(fixtureKey(candidate))) {
      reasons.push("outside_preserved_fixtures");
    }
    if (
      Number.isFinite(Date.parse(candidate.kickoff)) &&
      calendarDay(candidate.kickoff, context.timezone) !== intent.date
    ) reasons.push("outside_requested_day");
    if (
      !intent.sports.includes(candidate.sport) ||
      !pref?.markets.includes(candidate.marketId) ||
      (intent.marketIds.length &&
        !intent.marketIds.includes(candidate.marketId))
    ) reasons.push("outside_authorized_markets_or_sports");
    if (
      context.scope === "strict" &&
      !pref?.competitions.includes(candidate.competitionId)
    ) reasons.push("outside_competitions");
    if (reasons.length) {
      exclusions.push({ candidateId: candidate.id, reasons });
      return [];
    }
    return [{ candidate, assessment }];
  });
  report.eligibleCandidates = all.length;
  const byFixture = new Map<string, Item[]>();
  for (const item of all) {
    const key = fixtureKey(item.candidate);
    byFixture.set(key, [...(byFixture.get(key) ?? []), item]);
  }
  report.eligibleFixtures = byFixture.size;
  // Round robin across sports/competitions; the cap is not the first 48 by kickoff.
  const competitions = new Map<string, string[]>();
  for (const [key, items] of byFixture) {
    const c = items[0].candidate, group = `${c.sport}:${c.competitionId}`;
    competitions.set(group, [...(competitions.get(group) ?? []), key]);
  }
  for (const keys of competitions.values()) {
    keys.sort((a, b) => {
      const best = (id: string) =>
        Math.max(
          ...byFixture.get(id)!.map((x) => x.assessment.dataGroups.length),
        );
      return best(b) - best(a) || a.localeCompare(b);
    });
  }
  const fixturePool: string[] = [];
  for (let i = 0; fixturePool.length < maxFixtures; i++) {
    let progress = false;
    for (const group of [...competitions.keys()].sort()) {
      const key = competitions.get(group)![i];
      if (key && fixturePool.length < maxFixtures) {
        fixturePool.push(key);
        progress = true;
      }
    }
    if (!progress) break;
  }
  report.retainedFixtures = fixturePool.length;
  report.limited.fixtures = byFixture.size > fixturePool.length;
  const pool = fixturePool.flatMap((key) => byFixture.get(key)!);
  const bookmakers = [...new Set(pool.map((x) => x.candidate.bookmaker))].sort((
    a,
    b,
  ) =>
    new Set(
        pool.filter((x) => x.candidate.bookmaker === b).map((x) =>
          fixtureKey(x.candidate)
        ),
      ).size -
      new Set(
        pool.filter((x) => x.candidate.bookmaker === a).map((x) =>
          fixtureKey(x.candidate)
        ),
      ).size || a.localeCompare(b)
  );
  report.limited.bookmakers = bookmakers.length > maxBookmakers;
  const archive = new Map<string, Node>();
  const fixed = options.fixed ?? [];
  if (
    fixed.some((p, i) =>
      !all.some((x) => x.candidate.id === p.id) ||
      !compatible(fixed.slice(0, i), p)
    ) || fixed.length > maxSelections
  ) return finish();
  const selectedBookmakers = fixed.length
    ? [fixed[0].bookmaker]
    : bookmakers.slice(0, maxBookmakers);
  for (const bookmaker of selectedBookmakers) {
    if (report.limited.time) break;
    if (fixed.some((p) => p.bookmaker !== bookmaker)) continue;
    report.bookmakersExamined++;
    // One row per business selection/bookmaker; new prices do not create variants.
    const unique = new Map<string, Item>();
    for (
      const item of pool.filter((x) => x.candidate.bookmaker === bookmaker)
    ) {
      const key = selectionKey(item.candidate), prior = unique.get(key);
      if (!prior || prior.candidate.oddsAt < item.candidate.oddsAt) {
        unique.set(key, item);
      }
    }
    const bookPool = [...unique.values()].filter((x) =>
      compatible(fixed, x.candidate)
    )
      .sort((a, b) =>
        fixtureKey(a.candidate).localeCompare(fixtureKey(b.candidate)) ||
        selectionKey(a.candidate).localeCompare(selectionKey(b.candidate))
      );
    report.retainedCandidates += bookPool.length;
    const fixedAssessments = fixed.map((p) => assessCandidate(p, options.now));
    const fixedProduct = fixed.reduce((n, p) => n * p.odds, 1);
    let beam: Node[] = [{
      picks: fixed,
      assessments: fixedAssessments,
      product: fixedProduct,
      last: -1,
      key: JSON.stringify(fixed.map(selectionKey).sort()),
      metrics: metrics(fixed, fixedAssessments, fixedProduct, metricsTarget),
    }];
    const bookLimit = Math.min(
      maxExpansions,
      report.exploredStates +
        Math.floor(maxExpansions / selectedBookmakers.length),
    );
    for (
      let depth = fixed.length + 1;
      depth <= maxSelections && beam.length;
      depth++
    ) {
      const expanded: Node[] = [];
      for (const node of beam) {
        for (let i = node.last + 1; i < bookPool.length; i++) {
          if (
            options.maxComputeMs !== undefined &&
            report.exploredStates % 256 === 0 &&
            performance.now() - started >= options.maxComputeMs
          ) {
            report.limited.time = true;
            break;
          }
          if (report.exploredStates >= bookLimit) {
            report.limited.states = true;
            break;
          }
          report.exploredStates++;
          const { candidate, assessment } = bookPool[i];
          if (!compatible(node.picks, candidate)) continue;
          const product = node.product * candidate.odds;
          const value = targetValue(product, target);
          if (
            bounds.maximum !== null && value > bounds.maximum + .005
          ) continue;
          const picks = [...node.picks, candidate],
            assessments = [...node.assessments, assessment];
          const next: Node = {
            picks,
            assessments,
            product,
            last: i,
            key: JSON.stringify(picks.map(selectionKey).sort()),
            metrics: metrics(picks, assessments, product, metricsTarget),
          };
          expanded.push(next);
          if (
            (bounds.minimum === null || value >= bounds.minimum - .005) &&
            (!intent.requireEachSport ||
              intent.sports.every((sport) =>
                picks.some((p) => p.sport === sport)
              )) &&
            (!requiredFixtures ||
              [...requiredFixtures].every((fixture) =>
                picks.some((p) => fixtureKey(p) === fixture)
              ))
          ) {
            const money = totals(picks, target.stake);
            const exact = money.returnTotal -
              (target.kind === "net" ? target.stake : 0);
            if (
              (bounds.minimum !== null && exact < bounds.minimum - .005) ||
              (bounds.maximum !== null && exact > bounds.maximum + .005)
            ) continue;
            if (excluded.has(compositionKey(picks))) continue;
            report.feasibleObserved++;
            const prior = archive.get(next.key);
            if (!prior || order(next, prior) < 0) archive.set(next.key, next);
            if (archive.size > 256) {
              const keep = retain([...archive.values()], 128);
              archive.clear();
              for (const value of keep) archive.set(value.key, value);
            }
          }
        }
        if (report.exploredStates >= bookLimit || report.limited.time) break;
      }
      if (expanded.length > beamWidth) report.limited.beam = true;
      beam = retain(expanded, beamWidth);
      if (report.exploredStates >= bookLimit || report.limited.time) break;
    }
  }
  const archived = [...archive.values()];
  const pareto = archived.filter((n) =>
    !archived.some((other) => dominates(other, n))
  );
  report.paretoCount = pareto.length;
  const selected: Node[] = [];
  const different = (before: Candidate[], after: Candidate[]) =>
    options.fixed || options.preserveFixtures
      ? compositionKey(before) !== compositionKey(after)
      : compareCompositions(before, after).significant;
  const add = (nodes: Node[], approach: CompositionProposal["approach"]) => {
    const chosen = nodes.find((node) =>
      selected.every((old) => different(old.picks, node.picks)) &&
      (!options.reference || options.allowSameComposition ||
        different(options.reference, node.picks))
    );
    if (!chosen || alternatives.length >= (options.maxAlternatives ?? 3)) {
      return;
    }
    selected.push(chosen);
    alternatives.push({
      approach,
      fingerprint: compositionKey(chosen.picks),
      picks: chosen.picks,
      stake: target.stake!,
      ...totals(chosen.picks, target.stake!),
      metrics: chosen.metrics,
      assessments: chosen.assessments,
      comparison: options.reference || selected.length > 1
        ? compareCompositions(
          options.reference ?? selected[0].picks,
          chosen.picks,
        )
        : null,
    });
  };
  add([...pareto].sort((a, b) => order(a, b)), "balanced");
  if (selected.length) {
    add(
      pareto.filter((n) => n.picks.length < selected[0].picks.length).sort((
        a,
        b,
      ) => order(a, b, 2)),
      "fewer_matches",
    );
    add(
      pareto.filter((n) =>
        compareCompositions(selected[0].picks, n.picks).replaced.length > 0
      )
        .sort((a, b) => order(a, b)),
      "other_markets",
    );
    add(
      [...pareto].sort((a, b) =>
        compareCompositions(selected[0].picks, a.picks).sharedFixtures -
          compareCompositions(selected[0].picks, b.picks).sharedFixtures ||
        order(a, b)
      ),
      "different_matches",
    );
  }
  return finish();
}
