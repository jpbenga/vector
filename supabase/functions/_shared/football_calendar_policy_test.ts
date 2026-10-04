import { strict as assert } from "node:assert";
import {
  calendarEnd,
  collectOddsPages,
  fixtureBodyForDate,
  fixturesEligibleForAnnouncements,
  localCalendarDate,
  oddsDatesForFixtures,
  selectCachedOddsPages,
} from "./football_calendar_policy.ts";
const fixture = (id: number, date: string) => ({ fixture: { id, date } });
Deno.test("calendar includes 14 local days across a month, year and DST change", () => {
  assert.equal(calendarEnd("2026-10-04"), "2026-10-17");
  assert.equal(calendarEnd("2026-12-25"), "2027-01-07");
  assert.equal(calendarEnd("2026-10-20"), "2026-11-02");
  assert.equal(
    localCalendarDate("2026-10-17T22:30:00Z", "Europe/Paris"),
    "2026-10-18",
  );
  const season = {
    response: [
      fixture(1, "2026-10-17T20:30:00Z"),
      fixture(2, "2026-10-17T22:30:00Z"),
    ],
  };
  assert.deepEqual(
    fixtureBodyForDate(
      season,
      undefined,
      "2026-10-17",
      "2026-10-04",
      "Europe/Paris",
    ).response as unknown[],
    [season.response[0]],
  );
});
Deno.test("daily roll replaces the old dated calendar and preserves authoritative empty responses", () => {
  const season = { response: [fixture(1, "2026-10-08T18:00:00Z")] };
  const empty = { response: [] };
  // Far dates use the season; the next day enters the fresh four-day window.
  assert.deepEqual(
    fixtureBodyForDate(
      season,
      empty,
      "2026-10-08",
      "2026-10-04",
      "Europe/Paris",
    ).response,
    season.response,
  );
  assert.deepEqual(
    fixtureBodyForDate(
      season,
      empty,
      "2026-10-08",
      "2026-10-05",
      "Europe/Paris",
    ).response,
    [],
  );
  assert.equal(calendarEnd("2026-10-05"), "2026-10-18");
});
Deno.test("distant calendar does not freeze immutable readings prematurely", () => {
  const fixtures = [
    fixture(1, "2026-10-04T18:00:00Z"),
    fixture(2, "2026-10-07T18:00:00Z"),
    fixture(3, "2026-10-08T18:00:00Z"),
    fixture(4, "2026-10-17T18:00:00Z"),
  ];
  assert.deepEqual(
    fixturesEligibleForAnnouncements(
      fixtures,
      new Date("2026-10-04T04:00:00Z"),
      "Europe/Paris",
    ),
    fixtures.slice(0, 2),
  );
  assert.deepEqual(
    fixturesEligibleForAnnouncements(
      fixtures,
      new Date("2026-10-05T04:00:00Z"),
      "Europe/Paris",
    ),
    fixtures.slice(1, 3),
  );
});
Deno.test("all odds pages are collected, including a fixture absent from page one", async () => {
  const calls: number[] = [];
  const pages = await collectOddsPages((page) => {
    calls.push(page);
    return Promise.resolve({
      body: { paging: { total: 3 }, response: [fixture(page, "2026-10-17")] },
    });
  });
  assert.deepEqual(calls, [1, 2, 3]);
  assert.equal(pages.length, 3);
});
Deno.test("cached odds omit surplus old pages and other bookmakers; missing pages fail publication", () => {
  const filters = { league: "61", season: "2026", date: "2026-10-17" };
  const row = (page: number, total: number, extra = {}) => ({
    query_params: {
      ...filters,
      ...extra,
      ...(page === 1 ? {} : { page: String(page) }),
    },
    response_body: { paging: { total }, response: [] },
  });
  assert.equal(
    selectCachedOddsPages([
      row(1, 1),
      row(2, 3),
      row(1, 1, { bookmaker: "16" }),
    ], filters).length,
    1,
  );
  assert.throws(
    () => selectCachedOddsPages([row(1, 2)], filters),
    /Missing cached odds page/,
  );
  assert.equal(selectCachedOddsPages([row(1, 1)], filters).length, 1); // no odds is valid
});

Deno.test("local calendar at midnight retrieves odds using the provider UTC date", () => {
  const fixture = { fixture: { date: "2026-10-17T00:30:00+02:00" } };
  assert.equal(
    localCalendarDate(fixture.fixture.date, "Europe/Paris"),
    "2026-10-17",
  );
  assert.deepEqual(oddsDatesForFixtures([fixture, fixture]), ["2026-10-16"]);
});

Deno.test("an empty odds response with zero pages is a valid absence of prices", async () => {
  let requests = 0;
  const pages = await collectOddsPages(() => {
    requests++;
    return Promise.resolve({ body: { response: [], paging: { total: 0 } } });
  });
  assert.equal(requests, 1);
  assert.deepEqual(pages[0].body.response, []);
});
