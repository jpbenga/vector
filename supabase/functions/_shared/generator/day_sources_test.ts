import assert from "node:assert/strict";
import { type Context } from "./contracts.ts";
import {
  type DayMatchRef,
  type DaySourcePort,
  loadDaySources,
} from "./day_sources.ts";

const day = "2026-10-10", capturedAt = "2026-10-10T09:00:00Z";
const source = {
  id: "11111111-1111-4111-8111-111111111111",
  sport: "hockey" as const,
  capturedAt,
};
const context: Context = {
  origin: "profile",
  scope: "discovery",
  view: "all",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {},
};
const matches: DayMatchRef[] = Array.from(
  { length: 10 },
  (_, i) => ({ ...source, matchId: String(i + 1), key: `hockey:${i + 1}` }),
);
const port: DaySourcePort = {
  manifest: async () => ({
    version: 1,
    date: day,
    timezone: context.timezone,
    total: 10,
    sources: [source],
    matches,
  }),
  page: async (p) => ({
    sources: [{
      ...source,
      payload: {
        items: (p.p_matches as DayMatchRef[]).map((r) => ({
          id: r.matchId,
          startsAt: `${day}T17:00:00Z`,
        })),
      },
    }],
  }),
};

Deno.test("large pages are split without dropping matches or restarting the pinned manifest", async () => {
  const sizes: number[] = [];
  let manifests = 0;
  const result = await loadDaySources(context, day, ["hockey"], {
    manifest: (p) => {
      manifests++;
      return port.manifest(p);
    },
    page: async (p) => {
      const count = (p.p_matches as unknown[]).length;
      sizes.push(count);
      return {
        ...await port.page(p) as object,
        ...(count > 5 ? { padding: "x".repeat(1500000) } : {}),
      };
    },
  });
  assert.deepEqual(sizes, [10, 5, 5]);
  assert.equal(manifests, 1);
  assert.equal(result.coverage.loaded, 10);
  assert.equal(result.coverage.pages, 2);
  assert.equal(result.coverage.complete, true);
});

Deno.test("a changed publication, an unexpected match, a duplicate or a wrong day never completes a read", async () => {
  for (const kind of ["publication", "unexpected", "duplicate", "day"]) {
    await assert.rejects(loadDaySources(context, day, ["hockey"], {
      ...port,
      page: async (p) => {
        const result = await port.page(p) as any;
        if (kind === "publication") {
          result.sources[0].capturedAt = "2026-10-10T10:00:00Z";
        }
        if (kind === "unexpected") {
          result.sources[0].payload.items[0].id = "9999";
        }
        if (kind === "duplicate") {
          result.sources[0].payload.items.push(
            result.sources[0].payload.items[0],
          );
        }
        if (kind === "day") {
          result.sources[0].payload.items[0].startsAt = "2026-10-09T17:00:00Z";
        }
        return result;
      },
    }));
  }
});
