import assert from "node:assert/strict";
import {
  projectDomesticForms,
  publishedFixtureForm,
} from "./published_form.ts";
import capture from "../../../../test/fixtures/generator_domestic_form_capture.json" with {
  type: "json",
};
const stamp = "2026-10-08T10:00:00Z";
const fixture = {
  fixture: { id: 1, date: "2026-10-10T18:00:00Z" },
  league: { id: 61, season: 2026, type: "League" },
  teams: { home: { id: 2 }, away: { id: 3 } },
};
function history() {
  return {
    team: { id: 2 },
    league: { id: 61, season: 2026, type: "League" },
    matches: Array.from({ length: 7 }, (_, i) => ({
      fixture: {
        id: 100 + i,
        date: `2026-10-0${i + 1}T10:00:00Z`,
        status: { short: "FT" },
      },
      league: { id: 61, season: 2026 },
      result: "W",
      venue: "home",
      goals: { for: 2, against: 1 },
    })),
  };
}
Deno.test("published domestic form checks dates, season, status and duplicates; five real results in chronological order", () => {
  const row = history();
  row.matches.push(row.matches[6]);
  row.matches.push({
    ...row.matches[0],
    fixture: { id: 500, date: "2026-10-09T10:00:00Z", status: { short: "FT" } },
  });
  row.matches.push({ ...row.matches[0], league: { id: 61, season: 2025 } });
  row.matches.push({
    ...row.matches[0],
    fixture: { id: 600, date: "2026-10-07T10:00:00Z", status: { short: "NS" } },
  });
  const form = publishedFixtureForm(
    { recent_league_matches: [row] },
    fixture,
    stamp,
  );
  assert.equal(form.home.state, "available");
  assert.equal(form.home.results.length, 5);
  assert.deepEqual(form.home.results.map((r) => r.fixtureId), [
    "102",
    "103",
    "104",
    "105",
    "106",
  ]);
  assert.equal(form.away.state, "absent");
  assert.equal(form.away.results.length, 0);
  assert.equal(
    form.home.results.some((r) =>
      r.fixtureId === "500" || r.fixtureId === "600"
    ),
    false,
  );
});
Deno.test("old histories without a season, type or completed status are not silently presented as verified domestic form", () => {
  const row = history();
  const legacy = {
    ...row,
    league: { id: 61 },
    matches: row.matches.map((m) => ({
      fixture: { id: m.fixture.id, date: m.fixture.date },
      result: m.result,
    })),
  };
  const form = publishedFixtureForm({ recent_league_matches: [legacy] }, {
    ...fixture,
    league: { id: 61 },
  }, stamp);
  assert.equal(form.home.state, "unverified");
  assert.equal(form.home.results.length, 0);
  const cup = publishedFixtureForm({ recent_league_matches: [row] }, {
    ...fixture,
    league: { id: 2, season: 2026, type: "Cup" },
  }, stamp);
  assert.equal(cup.home.state, "unverified");
  assert.equal(cup.home.results.length, 0);
});
Deno.test("archived real European dossier supplies five domestic results per club with season and provenance, without European mixing", () => {
  const raw = capture.raw as unknown as Record<string, unknown>;
  // Explicit scope and controlled time; this fixture is archived public data, not a provider call.
  const verified = publishedFixtureForm(
    raw,
    (raw.fixtures as any[])[0],
    capture.capturedAt,
    "domestic_championship",
    new Date("2026-10-13T10:00:00Z"),
  );
  assert.equal(verified.home.state, "available");
  assert.equal(verified.away.state, "available");
  assert.equal(verified.home.competitionId, "39");
  assert.equal(
    verified.home.competitionName,
    capture.raw.european_comparisons[0].home.domesticCompetition.name,
  );
  assert.equal(verified.away.competitionId, "61");
  assert.equal(verified.home.season, 2026);
  assert.equal(verified.home.results.length, 5);
  assert.equal(verified.away.results.length, 5);
  assert.equal(
    verified.home.results.some((r) => r.competitionId === "2"),
    false,
  );
  assert.ok(verified.home.sourcePath.includes("domesticRecentMatches"));
  const projected = projectDomesticForms(raw, capture.capturedAt);
  const roundTrip = publishedFixtureForm(
    { generator_domestic_forms: projected },
    (raw.fixtures as any[])[0],
    capture.capturedAt,
  );
  assert.deepEqual(roundTrip.home.results, projected[0].home.results);
});
