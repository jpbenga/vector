import {
  dayKey,
  dayOverview,
  type DeliveryPart,
  type Json,
  overviewPart,
  partArtifacts,
  selectParts,
} from "../supabase/functions/_shared/delivery/feed_delivery.ts";
const [footballPath, hockeyPath, output] = Deno.args;
if (!footballPath || !hockeyPath || !output) {
  throw new Error(
    "Usage: football-public-rows.json hockey-publication.json output",
  );
}
const today = dayKey(new Date().toISOString()),
  stats: Record<string, unknown> = {};
const write = async (path: string, value: Json) => {
  const target = `${output}/${path}`;
  await Deno.mkdir(target.slice(0, target.lastIndexOf("/")), {
    recursive: true,
  });
  const json = JSON.stringify(value);
  await Deno.writeTextFile(target, json);
  return new TextEncoder().encode(json).length;
};
for (const sport of ["football", "hockey"] as const) {
  const sourceRows: Json[] = sport === "football"
    ? JSON.parse(await Deno.readTextFile(footballPath))
    : [{
      id: "hockey-" +
        Array.from(
          new Uint8Array(
            await crypto.subtle.digest(
              "SHA-256",
              new TextEncoder().encode(await Deno.readTextFile(hockeyPath)),
            ),
          ),
        ).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 24),
      payload: JSON.parse(await Deno.readTextFile(hockeyPath)),
    }];
  const candidates: DeliveryPart[] = sourceRows.map((row) => {
    const payload = row.payload as Json;
    return {
      id: String(row.id),
      scopeKey: String(row.scope_key ?? "hockey"),
      capturedAt: String(row.captured_at ?? payload.capturedAt),
      asOf: String(row.as_of ?? payload.capturedAt),
      windowStart: String(row.window_start ?? payload.windowStart),
      windowEnd: String(row.window_end ?? payload.windowEnd),
      fullPath: `delivery/${sport}/${row.id}/full.json`,
      overview: overviewPart(sport, payload),
    };
  });
  // Static preview ships current sources only. Historical days retain the
  // existing public repository, rather than duplicating hundreds of archives.
  const currentIds = new Set(
    selectParts(candidates, today, today).map((p) => p.id),
  );
  const parts: DeliveryPart[] = [];
  let fullBytes = 0;
  for (const row of sourceRows) {
    if (!currentIds.has(String(row.id))) continue;
    const payload = row.payload as Json,
      id = String(row.id),
      bundle = partArtifacts(sport, id, payload);
    for (const [path, value] of bundle.artifacts) {
      fullBytes += await write(path, value);
    }
    parts.push({
      id,
      scopeKey: String(row.scope_key ?? "hockey"),
      capturedAt: String(row.captured_at ?? payload.capturedAt),
      asOf: String(row.as_of ?? payload.capturedAt),
      windowStart: String(row.window_start ?? payload.windowStart),
      windowEnd: String(row.window_end ?? payload.windowEnd),
      fullPath: `delivery/${sport}/${id}/full.json`,
      overview: bundle.overview,
    });
  }
  const sizes: Record<string, number> = {};
  for (let offset = -7; offset <= 13; offset++) {
    const date = new Date(`${today}T12:00:00Z`);
    date.setUTCDate(date.getUTCDate() + offset);
    const day = date.toISOString().slice(0, 10);
    const selected = day < today ? [] : selectParts(parts, day, today),
      overview = dayOverview(sport, selected, day);
    if (!overview) {
      await write(`delivery/${sport}/${day}/manifest.json`, {});
      continue;
    }
    const path = `delivery/${sport}/demo-${today}/${day}.json`,
      bytes = await write(path, overview);
    sizes[day] = bytes;
    await write(`delivery/${sport}/${day}/manifest.json`, {
      schemaVersion: 1,
      sport,
      day,
      path,
      bytes,
      sourceIds: selected.map((p) => p.id),
      publishedAt: new Date().toISOString(),
    });
  }
  stats[sport] = {
    sources: parts.length,
    artifactBytes: fullBytes,
    dayBytes: sizes,
  };
}
await write("delivery/metrics.json", {
  builtAt: new Date().toISOString(),
  today,
  ...stats,
});
console.log(JSON.stringify({ today, ...stats }));
