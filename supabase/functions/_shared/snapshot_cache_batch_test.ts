import { SnapshotCacheBatch } from "./snapshot_cache_batch.ts";
const assert = (ok: boolean) => {
  if (!ok) throw new Error("Assertion failed");
};
Deno.test("batched cache preserves team, league and exact query identities, including empty rows", async () => {
  let calls = 0;
  const batch = new SnapshotCacheBatch(
    async (_endpoint, filters, field, ids) => {
      calls++;
      return ids.filter((id) => id !== "12").flatMap((id) => [
        { query_params: { ...filters, [field]: id }, value: id },
        {
          query_params: { ...filters, [field]: id, page: "2" },
          value: "page2",
        },
      ]);
    },
  );
  const ids = Array.from({ length: 60 }, (_, i) => String(i + 1));
  await batch.prefetch("/players", { league: "10", season: "2026" }, "team", [
    ...ids,
    "1",
  ]);
  assert(calls === 3);
  assert(
    batch.read("/players", { league: "10", season: "2026", team: "1" })
      ?.length === 2,
  );
  assert(
    batch.read("/players", { league: "10", season: "2026", team: "1" }, true)
      ?.length === 1,
  );
  assert(
    batch.read("/players", { league: "10", season: "2026", team: "12" })
      ?.length === 0,
  );
  assert(
    batch.read("/players", { league: "11", season: "2026", team: "1" }) ===
      undefined,
  );
  assert(batch.read("/fixtures/players", { fixture: "1" }) === undefined);
  assert(calls === 3);
});
Deno.test("failed cache batch never masquerades as an empty successful collection", async () => {
  const batch = new SnapshotCacheBatch(async () => {
    throw new Error("cache offline");
  });
  let failed = false;
  try {
    await batch.prefetch("/fixtures/events", {}, "fixture", ["1"]);
  } catch {
    failed = true;
  }
  assert(failed);
  assert(batch.read("/fixtures/events", { fixture: "1" }) === undefined);
});
