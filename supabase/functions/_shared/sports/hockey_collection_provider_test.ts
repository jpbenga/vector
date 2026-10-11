import assert from "node:assert/strict";
import {
  hockeyCollectionProvider,
  validCollectionRequest,
} from "./hockey_collection_provider.ts";
Deno.test("collection bridge restricts leagues, paths, parameters and origin-related input", () => {
  assert(
    validCollectionRequest("games", {
      league: "57",
      season: "2026",
      timezone: "Europe/Paris",
    }),
  );
  assert(validCollectionRequest("games/events", { game: "123" }));
  assert(validCollectionRequest("games/h2h", { h2h: "10-20" }));
  for (
    const [path, params] of [
      ["https://attacker.invalid", { id: "57" }],
      ["leagues", { id: "999" }],
      ["games", { league: "57", season: "2026", timezone: "UTC" }],
      ["leagues", { id: "57", host: "other" }],
      ["games/events", { game: "../1" }],
      ["games/events", { game: 1 }],
    ]
  ) assert(!validCollectionRequest(path, params));
});
Deno.test("anonymous and invalid requests cannot consume the provider quota", async () => {
  let reserved = 0, fetched = 0;
  const handler = hockeyCollectionProvider({
    secret: () => "server",
    reserve: async () => {
      reserved++;
      return true;
    },
    request: async () => {
      fetched++;
      return Response.json({ response: [] });
    },
  });
  assert.equal(
    (await handler(
      new Request("https://project.invalid", { method: "POST", body: "{}" }),
    )).status,
    401,
  );
  assert.equal(
    (await handler(
      new Request("https://project.invalid", {
        method: "POST",
        headers: { authorization: "Bearer server" },
        body: "{}",
      }),
    )).status,
    400,
  );
  assert.equal(reserved, 0);
  assert.equal(fetched, 0);
});
Deno.test("each allowed call reserves once and exhausted quota blocks upstream", async () => {
  let reserved = 0, fetched = 0, allowed = true;
  const handler = hockeyCollectionProvider({
    secret: () => "server",
    reserve: async () => {
      reserved++;
      return allowed;
    },
    request: async () => {
      fetched++;
      return Response.json({ response: [{ id: 57 }] });
    },
  });
  const req = () =>
    new Request("https://project.invalid", {
      method: "POST",
      headers: { authorization: "Bearer server" },
      body: JSON.stringify({ path: "leagues", parameters: { id: "57" } }),
    });
  assert.equal((await handler(req())).status, 200);
  allowed = false;
  assert.equal((await handler(req())).status, 429);
  assert.equal(reserved, 2);
  assert.equal(fetched, 1);
});
Deno.test("provider failures do not expose upstream error bodies", async () => {
  const handler = hockeyCollectionProvider({
    secret: () => "server",
    reserve: async () => true,
    request: async () =>
      new Response("sensitive upstream diagnostic", { status: 500 }),
  });
  const response = await handler(
    new Request("https://project.invalid", {
      method: "POST",
      headers: { authorization: "Bearer server" },
      body: JSON.stringify({ path: "leagues", parameters: { id: "57" } }),
    }),
  );
  assert.equal(response.status, 502);
  assert(!(await response.text()).includes("sensitive"));
});
