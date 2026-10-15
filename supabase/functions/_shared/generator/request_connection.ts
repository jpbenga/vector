/** Send JSON whitespace only after authentication and reservation. It keeps the
 * hosted HTTP connection active while the single original request is running.
 * The final JSON, persisted turn, ownership and cancellation remain unchanged. */
export function reservedKeepAlive(
  createHandler: (
    reserved: (headers: Response) => void,
  ) => (request: Request) => Promise<Response>,
  waitUntil?: (task: Promise<unknown>) => void,
) {
  return async (request: Request): Promise<Response> => {
    let announce!: (response: Response) => void;
    const reserved = new Promise<Response>((resolve) => announce = resolve);
    const result = createHandler(announce)(request);
    const first = await Promise.race([
      result.then((response) => ({ reserved: false, response })),
      reserved.then((response) => ({ reserved: true, response })),
    ]);
    if (!first.reserved) return first.response;
    const encoder = new TextEncoder();
    let connected = true, heartbeat: ReturnType<typeof setInterval>;
    const stream = new ReadableStream<Uint8Array>({
      start(controller) {
        const write = (bytes: Uint8Array) => {
          if (connected) controller.enqueue(bytes);
        };
        write(encoder.encode("\n"));
        heartbeat = setInterval(() => write(encoder.encode("\n")), 10000);
        const finish = result.then(async (response) => {
          write(new Uint8Array(await response.arrayBuffer()));
        }).catch(() => {
          write(encoder.encode(JSON.stringify({
            error:
              "La réponse n’a pas pu être transmise. Rechargez la conversation pour retrouver son résultat.",
          })));
        }).finally(() => {
          clearInterval(heartbeat);
          if (connected) controller.close();
          connected = false;
        });
        waitUntil?.(finish);
      },
      cancel() {
        connected = false;
        clearInterval(heartbeat);
      },
    });
    const headers = new Headers(first.response.headers);
    headers.set("cache-control", "no-store");
    headers.delete("content-length");
    return new Response(stream, { headers });
  };
}
