/** Trusted collectors publish public compacts. Browsers cannot supply readings. */
export function publicationHandler(ports: {
  secret: () => string | undefined;
  publish: (payload: Record<string, unknown>) => Promise<unknown>;
}) {
  return async (request: Request): Promise<Response> => {
    const secret = ports.secret();
    if (
      !secret || request.headers.get("authorization") !== `Bearer ${secret}`
    ) {
      return new Response("Unauthorized", { status: 401 });
    }
    if (request.method !== "POST") {
      return new Response("Method not allowed", { status: 405 });
    }
    try {
      // Public compact only, no raw provider envelopes, credentials or accounts.
      const text = await request.text();
      if (new TextEncoder().encode(text).length > 24_000_000) {
        return Response.json({ error: "Publication too large" }, {
          status: 413,
        });
      }
      const payload = JSON.parse(text);
      const permitted = new Set([
        "schemaVersion",
        "sport",
        "provider",
        "competitionId",
        "season",
        "capturedAt",
        "baseCapturedAt",
        "windowStart",
        "windowEnd",
        "timezone",
        "collectionId",
        "items",
        "competitions",
        "playerRadar",
        "readingRulesVersion",
      ]);
      if (
        payload.sport !== "hockey" || payload.provider !== "api-hockey" ||
        payload.schemaVersion !== 1 ||
        !Array.isArray(payload.items) || !Array.isArray(payload.competitions) ||
        typeof payload.readingRulesVersion !== "string" ||
        Object.keys(payload).some((key) => !permitted.has(key))
      ) {
        return Response.json({ error: "Unsupported publication adapter" }, {
          status: 400,
        });
      }
      const at = Date.parse(payload.capturedAt),
        baseAt = Date.parse(payload.baseCapturedAt ?? payload.capturedAt);
      if (
        !Number.isFinite(at) || !Number.isFinite(baseAt) || baseAt > at ||
        at > Date.now() || Date.now() - baseAt > 36 * 3600000
      ) {
        return Response.json({
          error: "Collect fresh source data before publishing",
        }, { status: 422 });
      }
      const publication = await ports.publish(payload);
      return Response.json({ ok: true, publication });
    } catch {
      // Never echo received bodies, credentials or provider diagnostic data.
      return Response.json({
        error: "Publication rejected; retained versions are unchanged",
      }, { status: 500 });
    }
  };
}
