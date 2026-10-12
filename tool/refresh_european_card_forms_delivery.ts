/** Refresh only the derived European card forms from the same public sources.
 * New content-addressed day paths preserve immutable prior artifacts.
 * No collection, model call, or change to the sporting observations. */
import {
  europeanCardForms,
  type Json,
} from "../supabase/functions/_shared/delivery/feed_delivery.ts";
const obj = (v: unknown): Json =>
  v && typeof v === "object" && !Array.isArray(v) ? v as Json : {};
const rows = (v: unknown): Json[] => Array.isArray(v) ? v.map(obj) : [];
export async function refreshEuropeanCardForms(
  indexPath: string,
  output: string,
) {
  const index = JSON.parse(await Deno.readTextFile(indexPath));
  const sources = new Map(
    rows(Array.isArray(index) ? index : index.rows).map(
      (r) => [String(r.id), r],
    ),
  );
  const cache = new Map<string, Map<number, Json>>();
  const get = async (id: string) => {
    if (cache.has(id)) return cache.get(id)!;
    const r = sources.get(id);
    if (!r?.sourceFile) throw new Error(`Public source not indexed: ${id}`);
    const source = JSON.parse(await Deno.readTextFile(String(r.sourceFile)));
    if (String(source.id) !== id) throw new Error("Source identity mismatch");
    const forms = new Map(
      europeanCardForms(obj(obj(source.payload).raw)).map(
        (f) => [Number(f.fixtureId), f],
      ),
    );
    cache.set(id, forms);
    return forms;
  };
  let days = 0, fixtures = 0, domesticResults = 0, extraBytes = 0;
  const counts: Json = {};
  for await (const directory of Deno.readDir(`${output}/delivery/football`)) {
    if (!directory.isDirectory || !/^\d{4}-\d{2}-\d{2}$/.test(directory.name)) {
      continue;
    }
    const manifestPath =
      `${output}/delivery/football/${directory.name}/manifest.json`;
    const manifest = JSON.parse(await Deno.readTextFile(manifestPath));
    if (!manifest.path) continue;
    const day = JSON.parse(
        await Deno.readTextFile(`${output}/${manifest.path}`),
      ),
      raw = obj(day.raw);
    const forms: Json[] = [];
    for (const f of rows(raw.fixtures)) {
      if (![2, 3, 848].includes(Number(obj(f.league).id))) continue;
      const fixtureId = Number(obj(f.fixture).id),
        descriptor = obj(
          obj(obj(day.delivery).detailPaths)[`api-fixture-${fixtureId}`],
        );
      const path = String(descriptor.path ?? ""), owner = path.split("/")[2];
      if (!owner || !path.startsWith(`delivery/football/${owner}/`)) {
        throw new Error("Missing European fixture owner");
      }
      const form = (await get(owner)).get(fixtureId);
      if (form) {
        forms.push(form);
        fixtures++;
        domesticResults += rows(obj(form.home).domesticRecentMatches).length +
          rows(obj(form.away).domesticRecentMatches).length;
      }
    }
    if (!forms.length) continue;
    const text = JSON.stringify({
      ...day,
      raw: { ...raw, european_card_forms: forms },
    });
    const hash = [
      ...new Uint8Array(
        await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)),
      ),
    ].map((v) => v.toString(16).padStart(2, "0")).join("").slice(0, 24);
    const path = `delivery/football/card-forms-${hash}/${directory.name}.json`;
    await Deno.mkdir(`${output}/delivery/football/card-forms-${hash}`, {
      recursive: true,
    });
    await Deno.writeTextFile(`${output}/${path}`, text);
    const bytes = new TextEncoder().encode(text).length;
    extraBytes += bytes - Number(manifest.bytes ?? 0);
    await Deno.writeTextFile(
      manifestPath,
      JSON.stringify({
        ...manifest,
        path,
        bytes,
        publishedAt: new Date().toISOString(),
      }),
    );
    counts[directory.name] = { fixtures: forms.length, bytes };
    days++;
  }
  return { days, fixtures, domesticResults, extraBytes, counts };
}
if (import.meta.main) {
  const [index, output] = Deno.args;
  if (!index || !output) {
    throw new Error("Usage: public-source-index.json built-demo-directory");
  }
  console.log(JSON.stringify(await refreshEuropeanCardForms(index, output)));
}
