import assert from "node:assert/strict";
import { assertCatalogueAnswer, toolAudit } from "./tool_audit.ts";

Deno.test("tool audit preserves scope, IDs, pagination, versions and errors without secrets or provider bodies", () => {
  const e = toolAudit("search_matches", {
    date: "2026-10-14",
    query: "Champions",
    password: "private",
    authorization: "Bearer sensitive",
  }, {
    queryId: "q2",
    total: 14,
    hasMore: true,
    nextOffset: 7,
    coverage: { complete: true, loaded: 14, expected: 14 },
    matches: [{
      key: "football:1635674",
      sourceId: "published",
      capturedAt: "2026-10-13T00:21:03Z",
      marketAvailability: {
        prematchEligible: false,
        reasons: [{ code: "publication_stale" }],
      },
    }],
    providerBody: "should never be copied",
  }, 12.5);
  assert.equal(e.parameters.query, "Champions");
  assert.equal(e.result.total, 14);
  assert.equal(e.result.nextOffset, 7);
  assert.equal(e.result.matches[0].sourceId, "published");
  assert.ok(!JSON.stringify(e).includes("private"));
  assert.ok(!JSON.stringify(e).includes("sensitive"));
  assert.ok(!JSON.stringify(e).includes("should never"));
  assert.equal(
    toolAudit("search_matches", {}, { error: "Network unavailable" }, 10).result
      .error,
    "Network unavailable",
  );
});

Deno.test("a tool error or positive targeted search cannot become an empty-calendar claim", () => {
  const failed = toolAudit("search_matches", { query: "Champions" }, {
    error: "Network unavailable",
  }, 10);
  assert.throws(() =>
    assertCatalogueAnswer(
      "Je ne trouve pas de rencontre de Ligue des champions.",
      [failed],
    )
  );
  assert.doesNotThrow(() =>
    assertCatalogueAnswer(
      "La recherche est temporairement indisponible, je ne peux pas confirmer le calendrier.",
      [failed],
    )
  );
  const found = toolAudit("search_matches", { query: "Champions" }, {
    total: 9,
  }, 10);
  assert.throws(() =>
    assertCatalogueAnswer("Aucune rencontre trouvée.", [found])
  );
  assert.doesNotThrow(() =>
    assertCatalogueAnswer(
      "Neuf rencontres trouvées, mais aucune sélection admissible au combiné.",
      [found],
    )
  );
  assert.doesNotThrow(() =>
    assertCatalogueAnswer("Aucun match trouvé.", [
      toolAudit("search_matches", {}, { total: 0 }, 10),
    ])
  );
});
