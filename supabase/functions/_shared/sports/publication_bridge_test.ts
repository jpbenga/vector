import assert from "node:assert/strict";
import { publicationHandler } from "./publication_bridge.ts";
Deno.test("Publication write is server-only, rejects stale/raw data, and reports the stored version", async () => {
  let calls = 0;
  const handler = publicationHandler({
    secret: () => "test",
    publish: async (p) => {
      calls++;
      return { id: "server", capturedAt: p.capturedAt };
    },
  });
  const request = (value: any, secret = "test") =>
    handler(
      new Request("http://test", {
        method: "POST",
        headers: { authorization: `Bearer ${secret}` },
        body: JSON.stringify(value),
      }),
    );
  const value = {
    sport: "hockey",
    provider: "api-hockey",
    schemaVersion: 1,
    capturedAt: new Date(Date.now() - 60000).toISOString(),
    readingRulesVersion: "native",
    items: [],
    competitions: [],
  };
  assert.equal((await request(value, "browser")).status, 401);
  assert.equal(
    (await request({ ...value, raw: { secret: "never-upload" } })).status,
    400,
  );
  assert.equal(
    (await request({ ...value, baseCapturedAt: "2020-01-01" })).status,
    422,
  );
  assert.equal((await request({ ...value, sport: "football" })).status, 400);
  const result = await request(value);
  assert.equal(result.status, 200);
  assert.equal((await result.json()).publication.capturedAt, value.capturedAt);
  assert.equal(calls, 1);
});
