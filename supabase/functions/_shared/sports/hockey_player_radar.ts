import {
  compactHockeyGames,
  object,
  providerRows,
  type PublicFixture,
  type PublicFormResult,
  recentHockeyResults,
  type SportPublication,
} from "./hockey_feed.ts";
import {
  compactHockeyEvents,
  type HockeyEnrichmentPorts,
  HockeyEventDataError,
  type HockeyMeeting,
} from "./hockey_enrichment.ts";

export type PublicPlayerActivity = PublicFormResult & {
  goals: number | null;
  assists: number | null;
};
export type PublicPlayerProfile = {
  id: string;
  name: string;
  identitySource: "event-name";
  competitionId: string;
  season: string;
  team: PublicFixture["home"];
  activity: PublicPlayerActivity[];
};
export type PublicPlayerRadar = {
  profiles: PublicPlayerProfile[];
  coverage: {
    competitionId: string;
    teamId: string;
    status: string;
    history?: PublicFormResult[];
  }[];
};

/** Only a complete goal ledger establishes zero contributions. Empty, partial,
 * crossed or unavailable events never establish an absence or a zero match. */
export function hockeyContributions(
  payload: unknown,
  game: HockeyMeeting,
): Map<string, Map<string, { goals: number; assists: number }>> | null {
  const events = compactHockeyEvents(payload, game);
  const goals = events.filter((e) => e.type === "goal");
  const score = game.scores.final;
  if (!score) return null;
  const shootout = ["AP", "APEN"].includes(game.providerStatus);
  const expectedHome = score.home -
    (shootout && score.home > score.away ? 1 : 0);
  const expectedAway = score.away -
    (shootout && score.away > score.home ? 1 : 0);
  if (
    goals.filter((e) => e.teamId === game.home.id).length !== expectedHome ||
    goals.filter((e) => e.teamId === game.away.id).length !== expectedAway
  ) return null;
  const teams = new Map<
    string,
    Map<string, { goals: number; assists: number }>
  >([
    [game.home.id, new Map()],
    [game.away.id, new Map()],
  ]);
  for (const event of goals) {
    const scorers = [
      ...new Set(event.players.map((n) => n.trim()).filter(Boolean)),
    ];
    const assists = [
      ...new Set(event.assists.map((n) => n.trim()).filter(Boolean)),
    ];
    // Missing scorer or duplicate scorer/assist identities cannot be trusted.
    if (
      scorers.length !== 1 || assists.length > 2 || assists.includes(scorers[0])
    ) return null;
    const team = teams.get(event.teamId)!;
    for (
      const [names, metric] of [[scorers, "goals"], [
        assists,
        "assists",
      ]] as const
    ) {
      for (const name of names) {
        const counts = team.get(name) ?? { goals: 0, assists: 0 };
        counts[metric]++;
        team.set(name, counts);
      }
    }
  }
  return teams;
}

/** Reuses the full season already collected and the historical event cache.
 * The whole available verified season is retained. Requests are deduplicated
 * per game across both teams and served by the historical event cache.
 * No player-photo, lineup or minutes endpoint is assumed to exist. */
export async function enrichHockeyPlayers(
  publication: SportPublication,
  rawGames: Map<string, unknown>,
  ports: HockeyEnrichmentPorts,
  now: Date,
): Promise<SportPublication> {
  const radar: PublicPlayerRadar = { profiles: [], coverage: [] };
  const ledgers = new Map<
    string,
    Awaited<ReturnType<typeof hockeyContributions>>
  >();
  for (const c of publication.competitions ?? []) {
    if (!c.formPhaseVerified) continue;
    const payload = rawGames.get(c.id);
    if (!payload) continue;
    const raw = new Map(providerRows(payload).map((r) => [String(r.id), r]));
    const games = new Map(
      compactHockeyGames(payload, {
        season: c.season,
        capturedAt: now.toISOString(),
        collectionId: publication.collectionId,
        timezone: publication.timezone,
        windowStart: "1900-01-01",
        windowEnd: "2999-12-31",
      }, Number(c.id)).items.map((g) => [g.id, g]),
    );
    const teams = new Map(
      c.tables.flatMap((t) => t.rows).map((r) => [r.team.id, r]),
    );
    // One validated ledger per game, shared by opponents and every player.
    async function ledger(result: PublicFormResult, teamId: string) {
      const game = games.get(result.id);
      if (
        !game || game.status !== "finished" ||
        game.startsAt >= now.toISOString() || game.season !== c.season ||
        ![game.home.id, game.away.id].includes(teamId)
      ) {
        return "invalid_history";
      }
      if (object(raw.get(game.id)).events !== true) return "events_unavailable";
      if (!ledgers.has(game.id)) {
        try {
          const events = await ports.request(
            "games/events",
            { game: game.id },
            now.getTime() - Date.parse(game.startsAt) < 2 * 86400_000
              ? 3600_000
              : 30 * 86400_000,
          );
          ledgers.set(
            game.id,
            hockeyContributions(events, {
              ...game,
              events: [],
              eventsCollected: true,
            }),
          );
        } catch (error) {
          if (!(error instanceof HockeyEventDataError)) throw error;
          ledgers.set(game.id, null);
        }
      }
      return ledgers.get(game.id) ? "" : "incomplete_events";
    }
    for (const row of teams.values()) {
      const recent = row.form.slice(-3);
      let issue = recent.length < 3 ? "insufficient_history" : "";
      if (!issue) {
        for (const result of recent) {
          issue = await ledger(result, row.team.id);
          if (issue) break;
        }
      }
      if (issue) {
        radar.coverage.push({
          competitionId: c.id,
          teamId: row.team.id,
          status: issue,
        });
        continue;
      }
      // Anchor to the standings' latest completed game, not the current date:
      // enrichment must never shift the three-game ranking window by itself.
      const cutoff = new Date(Date.parse(recent.at(-1)!.startsAt) + 1)
        .toISOString();
      const history = recentHockeyResults(
        [...games.values()],
        row.team.id,
        cutoff,
        Number.MAX_SAFE_INTEGER,
      );
      if (
        history.length < 3 ||
        history.slice(-3).some((r, i) =>
          r.id !== recent[i].id || r.startsAt !== recent[i].startsAt ||
          r.home !== recent[i].home || r.opponent !== recent[i].opponent ||
          r.scored !== recent[i].scored || r.conceded !== recent[i].conceded ||
          r.providerStatus !== recent[i].providerStatus
        )
      ) {
        radar.coverage.push({
          competitionId: c.id,
          teamId: row.team.id,
          status: "invalid_history",
        });
        continue;
      }
      for (const result of history.slice(0, -3)) {
        await ledger(result, row.team.id);
      }
      radar.coverage.push({
        competitionId: c.id,
        teamId: row.team.id,
        status: "complete",
        history,
      });
      // Older stars cannot qualify on past goals: discover candidates only in
      // the current three games, then attach their entire collected history.
      const names = new Set(
        recent.flatMap((r) => [...ledgers.get(r.id)!.get(row.team.id)!.keys()]),
      );
      for (const name of names) {
        radar.profiles.push({
          id: `event-name:${c.id}:${c.season}:${row.team.id}:${
            encodeURIComponent(name)
          }`,
          name,
          identitySource: "event-name",
          competitionId: c.id,
          season: c.season,
          team: row.team,
          activity: history.map((r) => ({
            ...r,
            ...(ledgers.get(r.id)?.get(row.team.id)?.get(name) ??
              (ledgers.get(r.id)
                ? { goals: 0, assists: 0 }
                : { goals: null, assists: null })),
          })),
        });
      }
    }
  }
  return { ...publication, playerRadar: radar };
}
