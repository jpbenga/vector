import { buildDemoDelivery } from "../build_feed_delivery_demo.ts";
import {
  deliveryRpc,
  putDeliveryJson,
} from "../../supabase/functions/_shared/delivery/feed_delivery_store.ts";
const source = Deno.args[0];
if (!source) throw new Error("Missing verified hockey publication");
const payload = JSON.parse(await Deno.readTextFile(source));
if (payload.sport !== "hockey") throw new Error("Invalid delivery sport");
const dir = await Deno.makeTempDir({ prefix: "hockey-cloud-delivery-" });
try {
  await Deno.writeTextFile(`${dir}/football.json`, "[]");
  await buildDemoDelivery(
    `${dir}/football.json`,
    source,
    `${dir}/out`,
    undefined,
    true,
  );
  const manifests: Record<string, unknown>[] = [];
  const objects: [string, Record<string, unknown>][] = [];
  async function walk(path: string) {
    for await (const entry of Deno.readDir(path)) {
      const file = `${path}/${entry.name}`;
      if (entry.isDirectory) await walk(file);
      else if (entry.name.endsWith(".json")) {
        const key = file.slice(`${dir}/out/`.length);
        const body = JSON.parse(await Deno.readTextFile(file));
        if (entry.name === "manifest.json") {
          if (!body.path) continue;
          const id = body.sourceIds?.[0];
          if (
            !/^hockey-[a-f0-9]{24}$/.test(id) || body.sourceIds.length !== 1
          ) throw new Error("Invalid hockey delivery identity");
          const original = body.path;
          body.path = `delivery/hockey/${id}/${body.day}.json`;
          body.collectionId = payload.collectionId;
          body.capturedAt = payload.capturedAt;
          objects.push([
            body.path,
            JSON.parse(await Deno.readTextFile(`${dir}/out/${original}`)),
          ]);
          manifests.push(body);
        } else if (
          /^delivery\/hockey\/hockey-[a-f0-9]{24}\/[a-zA-Z0-9_.-]+\.json$/.test(
            key,
          )
        ) {
          objects.push([key, body]);
        }
      }
    }
  }
  await walk(`${dir}/out/delivery/hockey`);
  // Only immutable public hockey objects. Never publish raw provider responses.
  for (let start = 0; start < objects.length; start += 4) {
    await Promise.all(
      objects.slice(start, start + 4).map(([path, body]) =>
        putDeliveryJson(path, body)
      ),
    );
    if (start % 100 === 0) {
      console.log(
        JSON.stringify({
          uploaded: Math.min(start + 4, objects.length),
          total: objects.length,
        }),
      );
    }
  }
  const days = await deliveryRpc("hockey_delivery_publish", {
    p_collection: payload.collectionId,
    p_captured_at: payload.capturedAt,
    p_manifests: manifests,
  });
  if (days !== manifests.length) {
    throw new Error("Hockey delivery commit was not confirmed");
  }
  console.log(
    JSON.stringify({
      hockey_delivery: {
        days,
        objects: objects.length,
        capturedAt: payload.capturedAt,
        collectionId: payload.collectionId,
      },
    }),
  );
} finally {
  await Deno.remove(dir, { recursive: true });
}
