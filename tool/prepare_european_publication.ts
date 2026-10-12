/** Runner-only projection from private sporting archives/cache; no network calls. */
import {
  buildEuropeanComparisons,
  type CachedContextSource,
  resolveEuropeanDomesticContexts,
} from "../supabase/functions/_shared/european_fixture_comparison.ts";
const obj = (v: unknown): Record<string, unknown> =>
  v && typeof v === "object" ? v as Record<string, unknown> : {};
const rows = (v: unknown): Record<string, unknown>[] =>
  Array.isArray(v) ? v.map(obj) : [];
if (import.meta.main) {
  const [input, output] = Deno.args;
  const data = JSON.parse(await Deno.readTextFile(input));
  const payload = data.payload, raw = obj(payload.raw);
  const cached = data.cached as CachedContextSource[];
  const originals = data.sources as Record<string, unknown>[];
  const allSources = [
    ...originals,
    ...cached.map((r) => ({
      endpoint: r.endpoint,
      query_params: r.query_params,
      fetched_at: r.fetched_at,
      as_of: r.as_of,
    })),
  ];
  const observed = (endpoint: string, league: number, season: number) =>
    originals.filter((s) =>
      s.endpoint === endpoint &&
      Number(obj(s.query_params).league) === league &&
      Number(obj(s.query_params).season) === season
    ).map((s) => String(s.fetched_at)).sort().at(-1) ?? payload.captured_at;
  raw.standings = rows(raw.standings).map((r) => ({
    ...r,
    observed_at: r.observed_at ??
      observed(
        "/standings",
        Number(obj(r.league).id),
        Number(obj(r.league).season),
      ),
  }));
  raw.league_fixtures = rows(raw.league_fixtures).map((r) => ({
    ...r,
    observed_at: r.observed_at ??
      observed(
        "/fixtures",
        Number(obj(r.league).id),
        Number(obj(r.league).season),
      ),
  }));
  // Only whole-season schedules enter this pool. Dated/recent queries cannot
  // overwrite a complete schedule or certify an empty European phase.
  const full = cached.filter((c) =>
    c.endpoint === "/fixtures" && c.query_params.league !== undefined &&
    c.query_params.season !== undefined &&
    Object.keys(c.query_params).every((k) =>
      ["league", "season", "timezone"].includes(k)
    )
  );
  const pool = new Map(
    rows(raw.league_fixtures).map((f) => [Number(obj(f.fixture).id), f]),
  );
  for (
    const c of [...full].sort((a, b) =>
      a.fetched_at.localeCompare(b.fetched_at)
    )
  ) {
    for (const f of rows(obj(c.response_body).response)) {
      pool.set(Number(obj(f.fixture).id), { ...f, observed_at: c.fetched_at });
    }
  }
  raw.league_fixtures = [...pool.values()];
  raw.fixtures = rows(raw.fixtures).map((f) =>
    pool.get(Number(obj(f.fixture).id)) ?? f
  );
  const domestic = resolveEuropeanDomesticContexts(
    rows(raw.fixtures),
    cached.filter((c) => c.endpoint === "/standings"),
    cached.filter((c) => c.endpoint === "/leagues"),
  );
  raw.domestic_team_contexts = domestic.contexts;
  raw.standings = [...rows(raw.standings), ...domestic.standings];
  raw.context_sources = allSources;
  // Source observation timestamps stay on every standing/history. Publication
  // time identifies a new build; it never authorizes a post-kickoff statistic.
  payload.raw = raw;
  payload.captured_at = data.builtAt;
  payload.as_of = data.builtAt;
  const dossiers = buildEuropeanComparisons(payload);
  await Deno.writeTextFile(
    output,
    JSON.stringify({
      payload,
      coverage: {
        fixtures: dossiers.length,
        domestic: domestic.contexts.length,
      },
      sourceMetadata: allSources,
    }),
  );
}
