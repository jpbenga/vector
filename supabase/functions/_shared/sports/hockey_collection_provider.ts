/** Private adapter for the scheduled collector. The provider key stays here. */
const leagues = new Set(["57", "58", "35", "10", "18", "16", "47"]);
export function validCollectionRequest(
  path: unknown,
  value: unknown,
): value is Record<string, string> {
  if (
    typeof path !== "string" || !value || typeof value !== "object" ||
    Array.isArray(value)
  ) return false;
  const params = value as Record<string, unknown>;
  const keys: Record<string, string[]> = {
    leagues: ["id"],
    games: ["league", "season", "timezone"],
    standings: ["league", "season"],
    "teams/statistics": ["league", "season", "team"],
    "games/h2h": ["h2h"],
    "games/events": ["game"],
  };
  const expected = keys[path];
  if (
    !expected || Object.keys(params).length !== expected.length ||
    expected.some((k) => typeof params[k] !== "string")
  ) return false;
  if (Object.keys(params).some((k) => !expected.includes(k))) return false;
  if (path === "leagues") return leagues.has(String(params.id));
  if (path === "games/events") return /^\d{1,12}$/.test(String(params.game));
  if (path === "games/h2h") {
    return /^\d{1,12}-\d{1,12}$/.test(String(params.h2h));
  }
  return leagues.has(String(params.league)) &&
    /^20\d{2}$/.test(String(params.season)) &&
    (path !== "games" || params.timezone === "Europe/Paris") &&
    (path !== "teams/statistics" || /^\d{1,12}$/.test(String(params.team)));
}

export function hockeyCollectionProvider(ports: {
  secret: () => string | undefined;
  reserve: () => Promise<boolean>;
  request: (path: string, params: Record<string, string>) => Promise<Response>;
}) {
  return async (req: Request): Promise<Response> => {
    if (req.method !== "POST") return new Response(null, { status: 405 });
    const secret = ports.secret();
    if (!secret || req.headers.get("authorization") !== `Bearer ${secret}`) {
      return new Response(null, { status: 401 });
    }
    const body = await req.json().catch(() => null);
    if (!validCollectionRequest(body?.path, body?.parameters)) {
      return Response.json({ error: "Invalid hockey collection request" }, {
        status: 400,
      });
    }
    try {
      if (!await ports.reserve()) {
        return Response.json({ error: "Shared hockey quota unavailable" }, {
          status: 429,
        });
      }
      const response = await ports.request(body.path, body.parameters);
      if (!response.ok) {
        return Response.json({ error: "Hockey provider unavailable" }, {
          status: response.status === 429 ? 429 : 502,
        });
      }
      const headers = new Headers({ "Content-Type": "application/json" });
      for (
        const name of [
          "x-ratelimit-limit",
          "x-ratelimit-remaining",
          "retry-after",
        ]
      ) {
        const value = response.headers.get(name);
        if (value) headers.set(name, value);
      }
      return new Response(await response.text(), { status: 200, headers });
    } catch {
      return Response.json({ error: "Hockey collection adapter unavailable" }, {
        status: 503,
      });
    }
  };
}
