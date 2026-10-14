import assert from "node:assert/strict";
import capture from "../../test/fixtures/generator_catalogue_parity_20261014.json" with {
  type: "json",
};
import {
  capturedPort,
  catalogueParity,
} from "../check_generator_catalogue_parity.ts";
import { loadDaySources } from "../../supabase/functions/_shared/generator/day_sources.ts";
import {
  type Context,
  obj,
  rows,
} from "../../supabase/functions/_shared/generator/contracts.ts";
import { ConversationReader } from "../../supabase/functions/_shared/generator/conversation_tools.ts";

const context: Context = {
  origin: "profile",
  scope: "discovery",
  view: "all",
  configurationPolicy: "request",
  timezone: "Europe/Paris",
  budget: 100,
  preferences: {},
};

Deno.test("French Champions League search returns the nine English-labelled published fixtures", async () => {
  const port = capturedPort(capture.sports.football);
  const reader = new ConversationReader({
    context,
    date: capture.day,
    now: new Date(capture.asOf),
    state: null,
    id: "localized-parity",
    message: "",
  }, {
    sources: async () => {
      throw Error("Use the day reader");
    },
    daySources: (c, d, s, p) => loadDaySources(c, d, s, port, p),
  });
  const result = obj(
    await reader.execute("search_matches", {
      date: capture.day,
      sports: ["football"],
      view: "all",
      radarKind: "teams",
      query: "Ligue des champions",
      offset: 0,
      limit: 20,
    }),
  );
  assert.equal(result.total, 9);
  assert.ok(rows(result.matches).every((m) => m.competitionId === "2"));
});
Deno.test("missing source, publication change, partial page and network errors never establish an empty-calendar result", async () => {
  for (const kind of ["missing", "changed", "partial", "network"]) {
    const port = capturedPort(capture.sports.football);
    await assert.rejects(() =>
      loadDaySources(context, capture.day, ["football"], {
        ...port,
        page: async (p) => {
          if (kind === "network") throw Error("Network unavailable");
          const page = obj(await port.page(p)), sources = rows(page.sources);
          if (kind === "missing") page.sources = [];
          if (kind === "changed") {
            sources[0].capturedAt = "2026-10-14T09:00:00Z";
          }
          if (kind === "partial") {
            obj(obj(sources[0].payload).raw).fixtures = rows(
              obj(obj(sources[0].payload).raw).fixtures,
            ).slice(1);
          }
          return page;
        },
      })
    );
  }
});
Deno.test("parity fails if catalogue IDs, competition, season or publication do not match the visible app", async () => {
  for (const field of ["key", "competitionId", "season", "capturedAt"]) {
    const copy = structuredClone(capture.sports.football);
    (copy.visible[0] as Record<string, unknown>)[field] = field === "capturedAt"
      ? "2026-10-14T09:00:00Z"
      : "wrong";
    await assert.rejects(
      () => catalogueParity(copy, capture.day, capture.asOf, "football"),
      /divergence|mismatch/,
    );
  }
});
