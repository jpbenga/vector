import { strict as assert } from "node:assert";
import {
  assessVictorySeries,
  footballSeriesHistory,
} from "./victory_series_policy.ts";
Deno.test("series starts at three, continues past five and shows a lower bound without a breaker", () => {
  for (const n of [2, 3, 4, 5, 8]) {
    const games = Array.from({ length: n }, () => ({ won: true, home: true }));
    assert.deepEqual(assessVictorySeries(games), {
      count: n,
      sample: n,
      exact: false,
      detected: n >= 3,
    });
    assert.equal(
      assessVictorySeries([...games, { won: false, home: false }]).exact,
      true,
    );
    assert.equal(assessVictorySeries(games, "overall", true).exact, true);
  }
});
Deno.test("venue series ignores losses in the other venue and stops at missing proof", () => {
  const games = [
    { won: true, home: true },
    { won: false, home: false },
    { won: true, home: true },
    { won: false, home: false },
    { won: true, home: true },
  ];
  assert.equal(assessVictorySeries(games).count, 1);
  assert.equal(assessVictorySeries(games, "home").count, 3);
  assert.equal(assessVictorySeries(games, "away").count, 0);
  assert.equal(
    assessVictorySeries([{ won: true, home: true }, { won: null, home: true }, {
      won: true,
      home: true,
    }], "home").count,
    1,
  );
  assert.equal(
    assessVictorySeries([{ won: true, home: true }, { won: true, home: null }, {
      won: true,
      home: true,
    }], "home").count,
    1,
  );
});
Deno.test("provider adapter deduplicates, sorts and rejects future or partly dated history", () => {
  const game = (id: number, date: string, result = "W", venue = "away") => ({
    fixture: { id, date },
    result,
    venue,
  });
  const cutoff = new Date("2026-10-06T10:00:00Z");
  const rows = [
    game(2, "2026-10-03"),
    game(1, "2026-10-02"),
    game(3, "2026-10-04"),
    game(3, "2026-10-04"),
    game(4, "2026-10-07", "L"),
  ];
  const series = assessVictorySeries(
    footballSeriesHistory(rows, cutoff, 9),
    "away",
  );
  assert.equal(series.count, 3);
  assert.equal(series.exact, false);
  assert.deepEqual(
    footballSeriesHistory([...rows, game(3, "2026-10-04", "L")], cutoff, 9),
    [],
  );
  assert.deepEqual(
    footballSeriesHistory([...rows, { result: "W", venue: "home" }], cutoff, 9),
    [],
  );
});
