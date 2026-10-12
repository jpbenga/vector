import assert from "node:assert/strict";
import {
  footballDetailColumns,
  projectFootballMatch,
} from "./conversation_data.ts";
import { now, source } from "./evaluation_cases.ts";

Deno.test("football detail pins its source and match, scopes histories and never exposes provider envelopes or unrelated teams", () => {
  const publication = source(), raw = publication.payload.raw as any;
  const row = {
    id: publication.id,
    captured_at: now.toISOString(),
    fixtures: raw.fixtures,
    computed: (publication.payload.computed as any).fixtures,
    standings: [{ league: { id: 61, standings: [] } }, { league: { id: 999 } }],
    team_statistics: [{
      league: { id: 61 },
      team: { id: 2 },
      goals: { for: 10 },
    }, { league: { id: 61 }, team: { id: 900 } }],
    recent_league_matches: [{
      league: { id: 61 },
      team: { id: 2 },
      matches: [{
        fixture: { id: 44 },
        goals: { home: 2, away: 1 },
        events: [{ privateProviderEnvelope: true }],
      }],
    }, { league: { id: 61 }, team: { id: 900 } }],
    head_to_head: [{
      fixture: { id: 1 },
      matches: [{
        fixture: { id: 55 },
        goals: { home: 1, away: 0 },
        provider: { key: "never-sent" },
      }],
    }, { fixture: { id: 2 }, matches: [] }],
    userSettings: { forbidden: true },
  };
  const detail = projectFootballMatch(
    row,
    publication.id,
    now.toISOString(),
    "1",
  )!;
  assert.equal(detail.items.length, 1);
  assert.equal(
    detail.items[0].fixture.fixture &&
      (detail.items[0].fixture.fixture as any).id,
    1,
  );
  assert.equal(detail.items[0].standings.length, 1);
  assert.equal(detail.items[0].teamStatistics.length, 1);
  assert.equal(detail.items[0].recentForm.length, 1);
  assert.equal(detail.items[0].headToHead.length, 1);
  assert.ok(!JSON.stringify(detail).includes("never-sent"));
  assert.ok(!JSON.stringify(detail).includes("privateProviderEnvelope"));
  assert.ok(!JSON.stringify(detail).includes("forbidden"));
  assert.ok(!footballDetailColumns.includes("player_statistics"));
  assert.equal(
    projectFootballMatch(row, "another-publication", now.toISOString(), "1"),
    null,
  );
  assert.equal(
    projectFootballMatch(row, publication.id, "2026-10-07T12:00:00Z", "1"),
    null,
  );
  assert.equal(
    projectFootballMatch(row, publication.id, now.toISOString(), "999"),
    null,
  );
});
Deno.test("European detail gives the generator the pinned structured dossier and excludes generic current standings", () => {
  const date = "2026-10-13T19:00:00Z", capturedAt = "2026-10-12T09:00:00Z";
  const dossier = {
    schemaVersion: 1,
    fixtureId: 10,
    kickoffAt: date,
    home: { teamId: 1 },
    away: { teamId: 2 },
    dataQuality: { state: "partial" },
  };
  const detail = projectFootballMatch(
    {
      id: "p",
      captured_at: capturedAt,
      fixtures: [{
        fixture: { id: 10, date },
        league: { id: 2 },
        teams: { home: { id: 1 }, away: { id: 2 } },
      }],
      european_comparisons: [dossier, { fixtureId: 20 }],
      standings: [{ league: { id: 2 } }],
    },
    "p",
    capturedAt,
    "10",
  )!;
  assert.deepEqual(detail.items[0].europeanComparison, dossier);
  assert.deepEqual(detail.items[0].standings, []);
  assert.equal(
    projectFootballMatch(
      { id: "p", captured_at: capturedAt, fixtures: [] },
      "p",
      capturedAt,
      "10",
    ),
    null,
  );
});
