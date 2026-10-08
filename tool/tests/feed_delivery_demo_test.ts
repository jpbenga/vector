import assert from "node:assert/strict";
import { buildDemoDelivery } from "../build_feed_delivery_demo.ts";
import football from "../../test/fixtures/football_calendar_14_days_compact.json" with {
  type: "json",
};
import hockey from "../../test/fixtures/sports/nhl_compact.json" with {
  type: "json",
};

Deno.test("static demo publishes frozen past days with complete detail references and no unused full archives", async () => {
  const root = await Deno.makeTempDir();
  try {
    const past = structuredClone(football) as unknown as Record<string, any>;
    past.window_start = "2026-10-05";
    past.window_end = "2026-10-18";
    past.captured_at = "2026-10-05T03:00:00Z";
    past.raw.fixtures[0].fixture.date = "2026-10-05T18:00:00Z";
    past.raw.fixtures.push({
      ...structuredClone(past.raw.fixtures[0]),
      fixture: {
        ...past.raw.fixtures[0].fixture,
        id: 999,
        date: "2026-10-10T18:00:00Z",
      },
    });
    const current = structuredClone(past);
    current.captured_at = "2026-10-08T03:00:00Z";
    current.computed.fixtures[0].readings = [{ id: "future-only-reading" }];
    const rows = [
      {
        id: "current",
        scope_key: "league:61",
        as_of: current.captured_at,
        captured_at: current.captured_at,
        window_start: "2026-10-05",
        window_end: "2026-10-18",
        payload: current,
      },
      {
        id: "archive",
        scope_key: "league:61",
        as_of: past.captured_at,
        captured_at: past.captured_at,
        window_start: "2026-10-05",
        window_end: "2026-10-18",
        payload: past,
      },
    ];
    // Exercise the disk index used by actual exports, not just in-memory input.
    for (const row of rows) {
      await Deno.writeTextFile(`${root}/${row.id}.json`, JSON.stringify(row));
    }
    await Deno.writeTextFile(
      `${root}/index.json`,
      JSON.stringify({
        schemaVersion: 2,
        today: "2026-10-08",
        rows: rows.map(({ payload: _, ...row }) => ({
          ...row,
          sourceFile: `${root}/${row.id}.json`,
        })),
      }),
    );
    await Deno.writeTextFile(`${root}/hockey.json`, JSON.stringify(hockey));
    await buildDemoDelivery(
      `${root}/index.json`,
      `${root}/hockey.json`,
      root,
      "2026-10-08",
    );
    const manifest = JSON.parse(
      await Deno.readTextFile(
        `${root}/delivery/football/2026-10-05/manifest.json`,
      ),
    );
    assert.deepEqual(manifest.sourceIds, ["archive"]);
    const day = JSON.parse(await Deno.readTextFile(`${root}/${manifest.path}`));
    assert.equal(day.raw.fixtures.length, 1);
    assert.deepEqual(
      day.computed.fixtures[0].readings,
      past.computed.fixtures[0].readings,
    );
    assert.equal(day.captured_at, past.captured_at);
    const references = [
      ...Object.values(day.delivery.detailPaths).flatMap((
        r: any,
      ) => [r.path, r.context]),
      ...day.delivery.radarPaths,
    ];
    for (const path of references) {
      assert.ok((await Deno.stat(`${root}/${path}`)).isFile);
    }
    assert.equal(
      (await Deno.readTextFile(
        `${root}/delivery/football/archive/match-1.json`,
      )).includes("future-only-reading"),
      false,
    );
    await assert.rejects(() =>
      Deno.stat(`${root}/delivery/football/archive/full.json`)
    );
    await assert.rejects(() =>
      Deno.stat(`${root}/delivery/football/archive/match-999.json`)
    );
  } finally {
    await Deno.remove(root, { recursive: true });
  }
});
