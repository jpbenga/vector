import assert from "node:assert/strict";
import { reservedKeepAlive } from "./request_connection.ts";

Deno.test("rejected requests retain their HTTP status and never enter keep-alive", async () => {
  let registered = 0;
  const handle = reservedKeepAlive(
    () => async () => Response.json({ error: "Unauthorized" }, { status: 401 }),
    () => registered++,
  );
  const response = await handle(new Request("https://example.test"));
  assert.equal(response.status, 401);
  assert.deepEqual(await response.json(), { error: "Unauthorized" });
  assert.equal(registered, 0);
});

Deno.test("a reserved long request sends whitespace then one final JSON with its audit headers", async () => {
  let finish!: (response: Response) => void, calls = 0;
  const pending = new Promise<Response>((resolve) => finish = resolve);
  let background: Promise<unknown> | undefined;
  const handle = reservedKeepAlive((announce) => async () => {
    calls++;
    announce(Response.json({}, {
      headers: {
        "x-lector-request-id": "owned-turn",
        "x-lector-release-revision": "reviewed",
      },
    }));
    return await pending;
  }, (task) => background = task);
  const response = await handle(new Request("https://example.test"));
  assert.equal(response.headers.get("x-lector-request-id"), "owned-turn");
  assert.equal(response.headers.get("x-lector-release-revision"), "reviewed");
  const reader = response.body!.getReader(), first = await reader.read();
  assert.equal(new TextDecoder().decode(first.value), "\n");
  finish(Response.json({ state: { revision: 4 } }));
  const rest = await new Response(
    new ReadableStream({
      async pull(controller) {
        const next = await reader.read();
        if (next.done) controller.close();
        else controller.enqueue(next.value);
      },
    }),
  ).json();
  await background;
  assert.deepEqual(rest, { state: { revision: 4 } });
  assert.equal(calls, 1);
});

Deno.test("client disconnection does not replay or discard the original reserved task", async () => {
  let finish!: (response: Response) => void, committed = false, calls = 0;
  const pending = new Promise<Response>((resolve) => finish = resolve);
  let background: Promise<unknown> | undefined;
  const handle = reservedKeepAlive((announce) => async () => {
    calls++;
    announce(Response.json({}));
    const response = await pending;
    committed = true;
    return response;
  }, (task) => background = task);
  const response = await handle(new Request("https://example.test"));
  await response.body!.cancel();
  finish(Response.json({ state: { revision: 4 } }));
  await background;
  assert.equal(committed, true);
  assert.equal(calls, 1);
});
