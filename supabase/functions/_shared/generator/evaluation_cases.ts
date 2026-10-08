import { type Context, type Intent } from "./contracts.ts";
import { type Source } from "./catalog.ts";
export const now = new Date("2026-10-08T12:00:00Z");
export const context: Context = {
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 50,
  preferences: {
    football: {
      competitions: ["61"],
      readings: ["strong_home_team", "positive_streak", "ranking_superiority"],
      markets: ["matchResult", "doubleChance"],
    },
  },
};
export const intent: Intent = {
  action: "generate",
  date: "2026-10-10",
  sports: ["football"],
  tickets: [{ stake: 50, minimum: 300, maximum: null, kind: "total" }],
  diversify: false,
  requireEachSport: false,
  maxSelections: 6,
  ticketIndex: null,
  selectionIndex: null,
  marketIds: [],
  message: "",
  goalMode: "around",
};
export function source(): Source {
  const fixture = (id: number) => ({
    fixture: { id, date: "2026-10-10T18:00:00Z", status: { short: "NS" } },
    league: { id: 61, name: "Ligue de test" },
    teams: {
      home: { id: id * 2, name: `Équipe ${id} domicile` },
      away: { id: id * 2 + 1, name: `Équipe ${id} extérieur` },
    },
  });
  return {
    id: "publication-test",
    sport: "football",
    capturedAt: now.toISOString(),
    payload: {
      raw: {
        fixtures: [1, 2, 3, 4].map(fixture),
        odds: [1, 2, 3, 4].map((id) => ({
          fixture: { id },
          update: now.toISOString(),
          bookmakers: [{
            id: 1,
            name: "Test",
            bets: [{
              id: 1,
              values: [{ value: "Home", odd: String([2, 3, 1.5, 2][id - 1]) }],
            }, {
              id: 12,
              values: [{
                value: "Home/Draw",
                odd: String([1.9, 2.9, 1.4, 1.9][id - 1]),
              }],
            }],
          }],
        })),
      },
      computed: {
        fixtures: [1, 2, 3, 4].map((id) => ({
          fixture_id: id,
          readings: [
            {
              id: "strong_home_team",
              side: "home",
              subject_team_id: id * 2,
              label: "Solide à domicile",
              sample_size: 5,
              evidence: [{ label: "Trois victoires consécutives à domicile" }],
            },
            {
              id: "positive_streak",
              side: "home",
              subject_team_id: id * 2,
              label: "Dynamique positive",
              sample_size: 5,
            },
            {
              id: "ranking_superiority",
              side: "away",
              subject_team_id: id * 2 + 1,
              label: "Avantage au classement",
              sample_size: 10,
            },
          ],
        })),
      },
    },
  };
}
