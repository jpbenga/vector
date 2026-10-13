/** Controlled public-data shape. This corpus never calls a provider or a model. */
import { ConversationReader } from "./conversation_tools.ts";
import { type Context, obj, rows } from "./contracts.ts";
import { largeQuery } from "./match_evaluation_cases.ts";
import { context, now } from "./evaluation_cases.ts";
import { explorationCriterion } from "./exploration.ts";

export async function explorationDay(count = 80, withOdds = false) {
  const { publication } = await largeQuery(count);
  const raw = obj(publication.payload.raw);
  if (!withOdds) raw.odds = [];
  raw.fixtures = rows(raw.fixtures).map((f) => ({
    ...f,
    league: { ...obj(f.league), season: 2026, type: "League" },
  }));
  const won = (i: number, side: string, j: number) =>
    side === "home" ? i >= count - 6 || j >= 2 : i < count - 6 && j >= 3;
  raw.recent_league_matches = rows(raw.fixtures).flatMap((f, i) =>
    ["home", "away"].map((side) => ({
      team: obj(obj(f.teams)[side]),
      league: { id: 61, season: 2026, type: "League" },
      matches: Array.from({ length: 5 }, (_, j) => ({
        fixture: {
          id: 10000 + i * 10 + j * 2 + Number(side === "away"),
          date: `2026-09-${String(j + 10).padStart(2, "0")}T12:00:00Z`,
          status: { short: "FT" },
        },
        league: { id: 61, season: 2026 },
        result: won(i, side, j) ? "W" : "L",
        venue: side,
        goals: {
          for: won(i, side, j) ? 2 : 1,
          against: won(i, side, j) ? 1 : 2,
        },
        opponent: { name: `Opponent ${j}` },
      })),
    }))
  );
  const scope: Context = { ...context, view: "all" };
  const reader = new ConversationReader({
    context: scope,
    date: "2026-10-10",
    now,
    state: null,
    id: "controlled",
    message: "Dix rencontres selon mes lectures et la forme",
  }, { sources: async () => [publication] });
  const query = await reader.query("2026-10-10", ["football"], "all", "teams");
  const criterion = explorationCriterion({
    request: "Dix rencontres selon mes lectures et la forme",
    criteria: "mes lectures et la forme",
    query,
    observationCount: 10,
    useProfileReadings: true,
    formScope: "domestic_championship",
  });
  return { publication, query, criterion, context: scope };
}
export const modelResponse = (value: unknown) =>
  Response.json({
    id: "controlled-model",
    model: "gpt-6-luna",
    status: "completed",
    usage: { input_tokens: 120, output_tokens: 180 },
    output: [{
      type: "message",
      content: [{ type: "output_text", text: JSON.stringify(value) }],
    }],
  });
/** Deterministic substitute for grading. All references refer to supplied local facts. */
export function evaluateFixture(body: any) {
  return {
    evaluations: Object.fromEntries(
      JSON.parse(body.input).matches.map((m: any) => {
        const proof = m.facts.find((f: any) => f.text.includes("15/15")) ??
          m.facts[0];
        return [m.key, {
          fit: proof?.text.includes("15/15") ? 4 : proof ? 1 : 0,
          status: proof ? "supported" : "insufficient",
          candidate: null,
          references: proof ? [proof.id] : [],
          vigilanceReferences: [],
          reason: proof
            ? "Adéquation documentée par le fait publié cité."
            : "Données insuffisantes.",
          limitations: [],
        }];
      }),
    ),
  };
}
