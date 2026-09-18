type JsonObject = Record<string, unknown>;

const corsHeaders = {
  "access-control-allow-origin": "*",
  "access-control-allow-headers": "authorization, x-client-info, apikey, content-type",
  "access-control-allow-methods": "POST, OPTIONS",
};

// This function is deliberately the boundary between private, heavy provider
// data and the public mobile read model. It never exposes histories, xG event
// rows, player pages, standings or raw cache to the app.
Deno.serve(async (request) => {
  if (request.method === "OPTIONS") return respond({ ok: true });
  if (request.method !== "POST") return respond({ error: "Method not allowed." }, 405);
  const secret = requiredEnv("API_FOOTBALL_SYNC_SECRET");
  if (request.headers.get("authorization") !== `Bearer ${secret}`) {
    return respond({ error: "Unauthorized." }, 401);
  }

  try {
    const payload = objectValue(await request.json()) ?? {};
    const snapshotId = stringValue(payload.snapshot_id);
    if (snapshotId === null) return respond({ error: "snapshot_id is required." }, 400);
    const supabaseUrl = requiredEnv("SUPABASE_URL");
    const serviceRoleKey = requiredEnv("SUPABASE_SERVICE_ROLE_KEY");

    const existing = await supabaseFetch({
      supabaseUrl, serviceRoleKey,
      path: `/rest/v1/match_feed_analysis_snapshots?select=id&source_snapshot_id=eq.${encodeURIComponent(snapshotId)}&limit=1`,
      method: "GET",
    });
    if (existing.length > 0) {
      return respond({ ok: true, reused: true, analysisSnapshotId: String(objectValue(existing[0])?.id ?? "") });
    }

    // Announcements are the single source for both the Bilan and the mobile
    // feed. Publishing happens before materialisation, so a reading has the
    // same definition and immutable evidence everywhere in the product.
    const publication = await invokeFunction({
      supabaseUrl,
      name: "publish-reading-announcements",
      secret,
      payload: { snapshot_id: snapshotId },
    });
    if (booleanValue(publication.ok) !== true) {
      throw new Error(`Reading publication failed: ${stringValue(publication.error) ?? "unknown error"}`);
    }

    const snapshots = await supabaseFetch({
      supabaseUrl, serviceRoleKey,
      path: `/rest/v1/match_feed_snapshots?select=id,schema_version,source,scope,scope_key,league_ids,timezone,window_start,window_end,captured_at,as_of,payload,coverage_summary&id=eq.${encodeURIComponent(snapshotId)}&limit=1`,
      method: "GET",
    });
    const snapshot = objectValue(snapshots[0]);
    if (snapshot === null) throw new Error("Snapshot not found.");
    const snapshotPayload = objectValue(snapshot.payload);
    const raw = objectValue(snapshotPayload?.raw) ?? {};
    const fixtures = objectList(raw.fixtures);
    const odds = objectList(raw.odds);

    // Announcements are immutable and intentionally written only once per
    // fixture/reading. A newer source snapshot must reuse the existing
    // announcement rather than filtering it out by source snapshot.
    const fixtureIds = [
      ...new Set(
        fixtures
          .map((row) => numberValue((objectValue(row.fixture) ?? {}).id))
          .filter((id): id is number => id !== null),
      ),
    ];
    const announced = fixtureIds.length === 0
      ? []
      : await supabaseFetch({
        supabaseUrl,
        serviceRoleKey,
        path: `/rest/v1/match_reading_announcements?select=fixture_id,reading_id,reading_label,subject_side,subject_team_id,player_id,evidence,sample_size,announcement_kind,required_reading_ids,outcome_rule&fixture_id=in.(${fixtureIds.join(",")})&order=fixture_id,reading_id`,
        method: "GET",
      });
    const computedByFixture = new Map<number, JsonObject[]>();
    for (const value of announced) {
      const row = objectValue(value);
      const fixtureId = row === null ? null : numberValue(row.fixture_id);
      if (fixtureId === null || row === null) continue;
      const item = {
        id: stringValue(row.reading_id) ?? "unknown",
        label: stringValue(row.reading_label) ?? "Lecture",
        kind: stringValue(row.announcement_kind) ?? "reading",
        side: stringValue(row.subject_side) ?? "match",
        subject_team_id: stringValue(row.subject_team_id) ?? `api-fixture-${fixtureId}`,
        player_id: numberValue(row.player_id),
        sample_size: numberValue(row.sample_size) ?? 0,
        evidence: objectList(row.evidence),
        required_reading_ids: stringList(row.required_reading_ids),
        outcome_rule: stringValue(row.outcome_rule),
      };
      const values = computedByFixture.get(fixtureId) ?? [];
      values.push(item);
      computedByFixture.set(fixtureId, values);
    }

    const computedFixtures: JsonObject[] = [];
    for (const fixtureRow of fixtures) {
      const fixture = objectValue(fixtureRow.fixture) ?? {};
      const fixtureId = numberValue(fixture.id);
      if (fixtureId === null) continue;
      const items = computedByFixture.get(fixtureId) ?? [];
      computedFixtures.push({
        fixture_id: fixtureId,
        readings: items.filter((item) => item.kind === "reading"),
        scenarios: items.filter((item) => item.kind === "scenario"),
      });
    }

    const compactPayload = {
      schema_version: 1,
      source: stringValue(snapshot.source) ?? "api-football",
      captured_at: stringValue(snapshot.captured_at),
      timezone: stringValue(snapshot.timezone) ?? "Europe/Paris",
      window_start: stringValue(snapshot.window_start),
      window_end: stringValue(snapshot.window_end),
      raw: { fixtures, odds },
      computed: {
        engine_version: "server_computed_feed_v1",
        fixtures: computedFixtures,
      },
    };
    const stored = await supabaseFetch({
      supabaseUrl, serviceRoleKey,
      path: "/rest/v1/match_feed_analysis_snapshots",
      method: "POST",
      body: [{
        source_snapshot_id: snapshotId,
        schema_version: 1,
        source: stringValue(snapshot.source) ?? "api-football",
        scope: stringValue(snapshot.scope) ?? "global",
        scope_key: stringValue(snapshot.scope_key) ?? "global",
        league_ids: numberList(snapshot.league_ids),
        timezone: stringValue(snapshot.timezone) ?? "Europe/Paris",
        window_start: stringValue(snapshot.window_start),
        window_end: stringValue(snapshot.window_end),
        captured_at: stringValue(snapshot.captured_at),
        as_of: stringValue(snapshot.as_of),
        payload: compactPayload,
        coverage_summary: {
          source_snapshot_id: snapshotId,
          fixture_count: fixtures.length,
          reading_count: announced.filter((value) => stringValue(objectValue(value)?.announcement_kind) !== "scenario").length,
          scenario_count: announced.filter((value) => stringValue(objectValue(value)?.announcement_kind) === "scenario").length,
          publication: publication.summary ?? {},
        },
      }],
      prefer: "return=representation",
    });
    return respond({
      ok: true,
      reused: false,
      analysisSnapshotId: stringValue(objectValue(stored[0])?.id),
      summary: { fixtures: fixtures.length, announcements: announced.length },
    });
  } catch (error) {
    return respond({ ok: false, error: error instanceof Error ? error.message : String(error) }, 500);
  }
});

async function invokeFunction({ supabaseUrl, name, secret, payload }: { supabaseUrl: string; name: string; secret: string; payload: JsonObject }): Promise<JsonObject> {
  const response = await fetch(`${supabaseUrl}/functions/v1/${name}`, {
    method: "POST",
    headers: { authorization: `Bearer ${secret}`, "content-type": "application/json" },
    body: JSON.stringify(payload),
  });
  const body = objectValue(await response.json().catch(() => ({}))) ?? {};
  if (!response.ok) throw new Error(`${name}: ${response.status} ${stringValue(body.error) ?? ""}`);
  return body;
}

async function supabaseFetch({ supabaseUrl, serviceRoleKey, path, method, body, prefer }: { supabaseUrl: string; serviceRoleKey: string; path: string; method: "GET" | "POST"; body?: JsonObject[]; prefer?: string }): Promise<unknown[]> {
  const response = await fetch(`${supabaseUrl}${path}`, {
    method,
    headers: { apikey: serviceRoleKey, authorization: `Bearer ${serviceRoleKey}`, "content-type": "application/json", ...(prefer === undefined ? {} : { prefer }) },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error(`Supabase ${method} ${path}: ${response.status} ${await response.text()}`);
  const result = await response.json().catch(() => []);
  return Array.isArray(result) ? result : [];
}
function objectValue(value: unknown): JsonObject | null { return value !== null && typeof value === "object" && !Array.isArray(value) ? value as JsonObject : null; }
function objectList(value: unknown): JsonObject[] { return Array.isArray(value) ? value.map(objectValue).filter((value): value is JsonObject => value !== null) : []; }
function stringList(value: unknown): string[] { return Array.isArray(value) ? value.map(stringValue).filter((value): value is string => value !== null) : []; }
function numberList(value: unknown): number[] { return Array.isArray(value) ? value.map(numberValue).filter((value): value is number => value !== null) : []; }
function stringValue(value: unknown): string | null { return typeof value === "string" && value.length > 0 ? value : null; }
function numberValue(value: unknown): number | null { const parsed = typeof value === "number" ? value : typeof value === "string" ? Number(value) : Number.NaN; return Number.isFinite(parsed) ? parsed : null; }
function booleanValue(value: unknown): boolean | null { return typeof value === "boolean" ? value : null; }
function requiredEnv(name: string): string { const value = Deno.env.get(name); if (!value) throw new Error(`Missing ${name}`); return value; }
function respond(payload: JsonObject, status = 200): Response { return new Response(JSON.stringify(payload), { status, headers: { ...corsHeaders, "content-type": "application/json; charset=utf-8" } }); }
