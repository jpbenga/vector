import {
  dayKey,
  dayOverview,
  type DeliveryPart,
  type Json,
  partArtifacts,
  selectParts,
} from "../supabase/functions/_shared/delivery/feed_delivery.ts";

/** Read archives individually; only publish details for their selected days. */
export async function buildDemoDelivery(
  footballPath: string,
  hockeyPath: string,
  output: string,
  today = dayKey(new Date().toISOString()),
) {
  const stats: Record<string, unknown> = {};
  const write = async (path: string, value: Json) => {
    const target = `${output}/${path}`;
    await Deno.mkdir(target.slice(0, target.lastIndexOf("/")), {
      recursive: true,
    });
    const json = JSON.stringify(value);
    await Deno.writeTextFile(target, json);
    return new TextEncoder().encode(json).length;
  };
  const index = JSON.parse(await Deno.readTextFile(footballPath));
  if (
    !Array.isArray(index) &&
    (index.schemaVersion !== 2 || index.today !== today)
  ) {
    throw new Error("Re-export public sources for the build calendar day");
  }
  const hockeyText = await Deno.readTextFile(hockeyPath);
  const hash = Array.from(
    new Uint8Array(
      await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(hockeyText),
      ),
    ),
  ).map((b) => b.toString(16).padStart(2, "0")).join("").slice(0, 24);
  const days = Array.from({ length: 21 }, (_, i) => {
    const date = new Date(`${today}T12:00:00Z`);
    date.setUTCDate(date.getUTCDate() + i - 7);
    return date.toISOString().slice(0, 10);
  });
  for (const sport of ["football", "hockey"] as const) {
    const sourceRows: Json[] = sport === "football"
      ? (Array.isArray(index) ? index : index.rows)
      : [{ id: `hockey-${hash}`, payload: JSON.parse(hockeyText) }];
    const candidates: DeliveryPart[] = sourceRows.map((row) => {
      const payload = (row.payload ?? {}) as Json;
      return {
        id: String(row.id),
        scopeKey: String(row.scope_key ?? "hockey"),
        capturedAt: String(row.captured_at ?? payload.capturedAt),
        asOf: String(row.as_of ?? payload.capturedAt),
        windowStart: String(row.window_start ?? payload.windowStart),
        windowEnd: String(row.window_end ?? payload.windowEnd),
        fullPath: `delivery/${sport}/${row.id}/full.json`,
        overview: {},
      };
    });
    const selections = new Map(
      days.map((day) => [day, selectParts(candidates, day, today)]),
    );
    const selectedDays = new Map<string, Set<string>>();
    for (const [day, selected] of selections) {
      for (const part of selected) {
        if (!selectedDays.has(part.id)) selectedDays.set(part.id, new Set());
        selectedDays.get(part.id)!.add(day);
      }
    }
    const parts = new Map<string, DeliveryPart>();
    const originalSizes = new Map<string, number>();
    let artifactBytes = 0;
    for (const row of sourceRows) {
      const id = String(row.id), neededDays = selectedDays.get(id);
      if (!neededDays) continue;
      const source = row.sourceFile
        ? JSON.parse(await Deno.readTextFile(String(row.sourceFile)))
        : row;
      if (source.id !== id) throw new Error("Public source identity mismatch");
      const payload = source.payload as Json;
      originalSizes.set(
        id,
        new TextEncoder().encode(JSON.stringify(payload)).length,
      );
      const bundle = partArtifacts(sport, id, payload);
      // Current and historic lists always reference split detail/context files.
      // Do not duplicate each football archive as an unused full.json, or ship
      // details of its future fixtures in every past day's source directory.
      const neededMatches = new Set(
        ((sport === "football"
          ? (payload.raw as Json).fixtures
          : payload.items) as Json[])
          .filter((fixture) =>
            neededDays.has(
              sport === "football"
                ? dayKey(String((fixture.fixture as Json).date))
                : String(fixture.calendarDate),
            )
          )
          .map((fixture) =>
            `match-${
              sport === "football" ? (fixture.fixture as Json).id : fixture.id
            }.json`
          ),
      );
      for (const [path, value] of bundle.artifacts) {
        const name = path.slice(path.lastIndexOf("/") + 1);
        if (sport === "football" && name === "full.json") continue;
        if (name.startsWith("match-") && !neededMatches.has(name)) continue;
        if (name.startsWith("context") && !neededMatches.size) continue;
        artifactBytes += await write(path, value);
      }
      const metadata = candidates.find((part) => part.id === id)!;
      parts.set(id, { ...metadata, overview: bundle.overview });
    }
    const sizes: Record<string, number> = {},
      originals: Record<string, number> = {};
    for (const day of days) {
      const selected = selections.get(day)!.map((part) => parts.get(part.id)!);
      const overview = dayOverview(sport, selected, day);
      if (!overview) {
        await write(`delivery/${sport}/${day}/manifest.json`, {});
        continue;
      }
      const path = `delivery/${sport}/demo-${today}/${day}.json`;
      const bytes = await write(path, overview);
      sizes[day] = bytes;
      originals[day] = selected.reduce(
        (sum, part) => sum + originalSizes.get(part.id)!,
        0,
      );
      await write(`delivery/${sport}/${day}/manifest.json`, {
        schemaVersion: 1,
        sport,
        day,
        path,
        bytes,
        sourceIds: selected.map((part) => part.id),
        publishedAt: new Date().toISOString(),
      });
    }
    stats[sport] = {
      sources: parts.size,
      artifactBytes,
      dayBytes: sizes,
      originalDayBytes: originals,
    };
  }
  const metrics = { builtAt: new Date().toISOString(), today, ...stats };
  await write("delivery/metrics.json", metrics);
  return metrics;
}

if (import.meta.main) {
  const [footballPath, hockeyPath, output] = Deno.args;
  if (!footballPath || !hockeyPath || !output) {
    throw new Error(
      "Usage: football-public-rows.json hockey-publication.json output",
    );
  }
  console.log(
    JSON.stringify(await buildDemoDelivery(footballPath, hockeyPath, output)),
  );
}
