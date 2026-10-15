import {
  compactHockeyGames,
  recentHockeyResults,
  type SportPublication,
} from "../../supabase/functions/_shared/sports/hockey_feed.ts";
import { calculateHockeyStandingContext } from "../../supabase/functions/_shared/sports/hockey_standing_context.ts";

// Use the publication's own retained season responses. No API calls and no
// invented collection timestamp. Fixture form and readings stay unchanged.
const storage = new URL("../../var/sports/hockey/", import.meta.url);
const lock = new URL("collection-write.lock/", storage);
await Deno.mkdir(lock);
try {
  const path = new URL("published.json", storage);
  const publication: SportPublication = JSON.parse(
    await Deno.readTextFile(path),
  );
  const at = publication.baseCapturedAt ?? publication.capturedAt;
  for (const c of publication.competitions ?? []) {
    const raw = JSON.parse(
      await Deno.readTextFile(
        new URL(`raw/${publication.collectionId}/games-${c.id}.json`, storage),
      ),
    );
    const games = compactHockeyGames(raw, {
      season: c.season,
      capturedAt: at,
      collectionId: publication.collectionId,
      timezone: publication.timezone,
      windowStart: "1900-01-01",
      windowEnd: "2999-12-31",
    }, Number(c.id)).items;
    let formGames = games;
    if (c.id === "57") {
      let reconciled = false;
      calculateHockeyStandingContext(c, games, at, (regular, verified) => {
        reconciled = verified;
        formGames = verified ? regular : [];
      });
      if (c.formPhaseVerified && !reconciled) {
        throw new Error(
          "NHL history no longer reconciles with the verified regular-season publication",
        );
      }
    }
    for (const table of c.tables) {
      for (const row of table.rows) {
        const history = c.formPhaseVerified
          ? recentHockeyResults(formGames, row.team.id, at, formGames.length)
          : [];
        if (JSON.stringify(history.slice(-5)) !== JSON.stringify(row.form)) {
          throw new Error(
            `Historical form does not match publication: ${c.id}/${row.team.id}`,
          );
        }
        row.formHistory = history;
      }
    }
    console.log(
      JSON.stringify({
        league: c.name,
        verified: c.formPhaseVerified,
        longestHistory: Math.max(
          0,
          ...c.tables.flatMap((t) => t.rows.map((r) => r.formHistory!.length)),
        ),
      }),
    );
  }
  const temp = new URL("published.json.history.tmp", storage);
  await Deno.writeTextFile(temp, JSON.stringify(publication), { mode: 0o600 });
  await Deno.rename(temp, path);
} finally {
  await Deno.remove(lock);
}
