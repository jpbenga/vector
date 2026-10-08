// Two small interpreter checks. No private account content, no saved conversation.
import {
  calendarDay,
  type Candidate,
  type Context,
  type Intent,
  type State,
} from "../supabase/functions/_shared/generator/contracts.ts";
import {
  compose,
  compositionKey,
} from "../supabase/functions/_shared/generator/engine.ts";
import { interpret } from "../supabase/functions/_shared/generator/openai.ts";
import { resolveIntent } from "../supabase/functions/_shared/generator/service.ts";
const key = Deno.env.get("OPENAI_API_KEY")!,
  token = Deno.env.get("SUPABASE_ACCESS_TOKEN")!;
if (!key || !token) throw new Error("Missing repository credentials.");
async function reserve() {
  const response = await fetch(
    "https://api.supabase.com/v1/projects/ednvvxxvlawaagjyshkj/database/query",
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(30000),
      headers: {
        authorization: `Bearer ${token}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        query:
          "update public.lector_generator_budget set reserved_usd=reserved_usd+0.025 where id=true and reserved_usd+0.025<=limit_usd returning id",
      }),
    },
  );
  if (!response.ok || !(await response.json()).length) {
    throw new Error("Test envelope unavailable.");
  }
}
const model = "gpt-4.1-mini-2025-04-14",
  day = calendarDay(new Date(), "Europe/Paris");
const context: Context = {
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 100,
  preferences: {
    football: {
      competitions: ["61"],
      readings: ["strong_home_team"],
      markets: ["matchResult", "doubleChance"],
    },
  },
};
const intent: Intent = {
  action: "generate",
  date: day,
  sports: ["football"],
  tickets: [{ stake: 50, minimum: 90, maximum: 110, kind: "total" }],
  diversify: true,
  requireEachSport: false,
  maxSelections: 3,
  ticketIndex: null,
  selectionIndex: null,
  marketIds: [],
  message: "",
};
const pick = (id: string): Candidate => ({
  id,
  matchId: id,
  sport: "football",
  competitionId: "61",
  competition: "Fixture de validation",
  home: id + " domicile",
  away: id + " extérieur",
  teams: [id + "-home", id + "-away"],
  kickoff: day + "T20:00:00Z",
  marketId: "matchResult",
  market: "Résultat du match",
  selection: "Domicile gagne",
  odds: 2,
  oddsAt: new Date().toISOString(),
  bookmaker: "Fixture de validation",
  snapshotId: "fixture",
  evidence: [],
  warnings: [],
  discovery: false,
});
const candidates = [pick("validation-a"), pick("validation-b")],
  tickets = compose(candidates, intent, context);
const state: State = {
  id: crypto.randomUUID(),
  revision: 1,
  context,
  intent,
  tickets,
  versions: [tickets],
  pending: null,
  drafts: tickets,
  compositions: tickets.map((t) => compositionKey(t.picks)),
  messages: [{
    role: "user",
    text:
      "Un ticket pour aujourd’hui, 50 euros de mise, retour total autour de 100 euros et 3 matchs maximum.",
  }, { role: "assistant", text: "Voici un premier brouillon." }],
  saved: false,
  updatedAt: new Date().toISOString(),
};
await reserve();
const alternative = await interpret({
  message: "Propose-moi un autre ticket.",
  date: day,
  today: day,
  context,
  state,
}, { key, model });
if (alternative.intent.action !== "alternative") {
  throw new Error("Alternative intent was not detected.");
}
const resolved = resolveIntent(alternative.intent, state),
  next = compose(candidates, resolved, context, { tickets });
if (
  resolved.tickets[0].stake !== 50 || resolved.tickets[0].minimum !== 90 ||
  resolved.maxSelections !== 3 || next.length !== 1 ||
  compositionKey(next[0].picks) === compositionKey(tickets[0].picks)
) throw new Error("Alternative constraints or uniqueness failed.");
await reserve();
const incomplete: State = {
  ...state,
  tickets: [],
  drafts: [],
  intent: null,
  pendingIntent: {
    ...intent,
    tickets: [{ stake: 50, minimum: 300, maximum: 330, kind: "unspecified" }],
    maxSelections: 6,
  },
  messages: [{
    role: "user",
    text:
      "Un ticket pour aujourd’hui avec 50 euros, objectif 300 euros environ, 6 matchs maximum.",
  }, { role: "assistant", text: "Retour total ou bénéfice net ?" }],
};
const clarification = await interpret({
  message: "Retour total",
  date: day,
  today: day,
  context,
  state: incomplete,
}, { key, model });
if (
  clarification.intent.action !== "generate" ||
  clarification.intent.date !== day ||
  clarification.intent.maxSelections !== 6 ||
  clarification.intent.tickets[0]?.stake !== 50 ||
  clarification.intent.tickets[0]?.kind !== "total"
) throw new Error("Clarification lost the original constraints.");
console.log(JSON.stringify({
  regression: "generator_conversation_v11",
  passed: true,
  paid_calls: 2,
  alternative_distinct: true,
  constraints_preserved: true,
  usage: [alternative.usage, clarification.usage],
}));
await Deno.writeTextFile("/tmp/lector-generator-model.txt", model);
