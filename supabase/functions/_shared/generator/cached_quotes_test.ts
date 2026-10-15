import assert from "node:assert/strict";
import { withCollectedQuotes } from "./cached_quotes.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import { obj, rows } from "./contracts.ts";
import { buildCatalog } from "./catalog.ts";

Deno.test("generator reads already refreshed cache prices without refreshing old sports facts or changing the publication", async () => {
  const s = source();
  s.capturedAt = "2026-10-01T00:00:00Z";
  const raw = obj(s.payload.raw);
  rows(raw.fixtures).forEach((f) => obj(f.league).season = 2026);
  rows(raw.odds).forEach((q) => q.update = "2026-10-01T00:00:00Z");
  const before = structuredClone(s);
  const update = "2026-10-08T11:00:00Z";
  const quote = structuredClone(rows(raw.odds)[0]);
  quote.update = update;
  rows(obj(rows(quote.bookmakers)[0]).bets).forEach((b) =>
    rows(b.values).forEach((v) => v.odd = "1.75")
  );
  const read = (p: URLSearchParams) => {
    assert.equal(p.get("query_params->>date"), `eq.${intent.date}`);
    assert.equal(p.get("query_params->>league"), "in.(61)");
    assert.equal(p.get("response_status"), "eq.200");
    assert.equal(p.get("fetched_at"), `lte.${now.toISOString()}`);
    return Promise.resolve([{
      endpoint: "/odds",
      query_hash: "cache-ref",
      query_params: { league: "61", season: "2026" },
      fetched_at: "2026-10-08T11:01:00Z",
      response_body: { errors: [], response: [quote] },
    }]);
  };
  const result = await withCollectedQuotes(
    [s],
    context,
    intent.date,
    now,
    read,
  );
  assert.deepEqual(s, before);
  assert.equal(result[0].id, s.id);
  assert.equal(result[0].capturedAt, s.capturedAt);
  const c = buildCatalog(result, context, intent.date, now).candidates.find(
    (c) => c.matchId === "api-fixture-1",
  )!;
  assert.equal(c.odds, 1.75);
  assert.equal(c.oddsAt, update);
  assert.equal(c.evidence[0].asOf, s.capturedAt);
  assert.equal(obj(result[0].payload.quoteRevision).analysisAsOf, s.capturedAt);
  assert.deepEqual(obj(result[0].payload.quoteRevision).cacheReferences, [{
    queryHash: "cache-ref",
    fetchedAt: "2026-10-08T11:01:00Z",
  }]);
});
Deno.test("cache unavailable or empty keeps published prices; historical queries never read later cache", async () => {
  const s = source();
  const old = structuredClone(s);
  const unavailable = await withCollectedQuotes(
    [s],
    context,
    intent.date,
    now,
    () => Promise.reject(Error("private error")),
  );
  assert.deepEqual(
    obj(unavailable[0].payload.raw).odds,
    obj(s.payload.raw).odds,
  );
  assert.match(
    String(obj(unavailable[0].payload.quoteRevision).limitation),
    /dernier relevé/,
  );
  assert.deepEqual(s, old);
  let reads = 0;
  const historic = await withCollectedQuotes(
    [s],
    context,
    "2026-10-07",
    now,
    () => {
      reads++;
      return Promise.resolve([]);
    },
  );
  assert.equal(reads, 0);
  assert.equal(historic[0], s);
  const empty = await withCollectedQuotes(
    [s],
    context,
    intent.date,
    now,
    () => Promise.resolve([]),
  );
  assert.deepEqual(obj(empty[0].payload.raw).odds, obj(s.payload.raw).odds);
});
