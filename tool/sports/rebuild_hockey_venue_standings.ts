import {
  compactHockeyGames,
  type SportPublication,
} from "../../supabase/functions/_shared/sports/hockey_feed.ts";
import { calculateHockeyStandingContext } from "../../supabase/functions/_shared/sports/hockey_standing_context.ts";

// Rebuild the current publication's venue tables from its own retained season
// responses. No environment variables, credentials, network or new collection.
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
    Object.assign(c, calculateHockeyStandingContext(c, games, at));
    console.log(
      JSON.stringify({
        league: c.name,
        coverage: c.venueStandings!.status,
        teams: c.venueStandings!.home.length,
        unmatched: c.venueStandings!.unavailableTeams.length,
      }),
    );
  }
  const temp = new URL("published.json.tmp", storage);
  await Deno.writeTextFile(temp, JSON.stringify(publication), { mode: 0o600 });
  await Deno.rename(temp, path);
} finally {
  await Deno.remove(lock);
}
