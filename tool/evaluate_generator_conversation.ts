// Paid checks use synthetic sports publications only. No Supabase access or account writes.
import assert from "node:assert/strict";
import { converse } from "../supabase/functions/_shared/generator/conversation.ts";
import {
  type Context,
  type Intent,
  type State,
} from "../supabase/functions/_shared/generator/contracts.ts";
import { type Source } from "../supabase/functions/_shared/generator/catalog.ts";
import {
  context as footballContext,
  now,
  source,
} from "../supabase/functions/_shared/generator/evaluation_cases.ts";
import {
  comparisonModels,
  type ModelReceipt,
} from "../supabase/functions/_shared/generator/models.ts";

const key = Deno.env.get("OPENAI_API_KEY");
if (!key || Deno.env.get("GITHUB_ACTIONS") !== "true") {
  throw new Error(
    "Run this bounded evaluation in GitHub Actions with its OpenAI secret.",
  );
}
const context: Context = {
  ...footballContext,
  preferences: {
    ...footballContext.preferences,
    hockey: {
      competitions: ["hockey:api-hockey:competition:35"],
      readings: ["winning_streak"],
      markets: ["result_regulation", "double_chance_regulation"],
    },
  },
};
function publications(day: string): Source[] {
  const football = source();
  for (const f of (football.payload.raw as any).fixtures) {
    f.fixture.date = `${day}T18:00:00Z`;
  }
  const hockey: Source = {
    id: "synthetic-hockey",
    sport: "hockey",
    capturedAt: now.toISOString(),
    payload: {
      items: [100, 101].map((id) => ({
        id: String(id),
        competitionId: "35",
        competitionName: "Hockey de test",
        season: "2026",
        status: "scheduled",
        startsAt: `${day}T18:30:00Z`,
        calendarDate: day,
        home: { id: String(id * 2), name: `Club hockey ${id} domicile` },
        away: { id: String(id * 2 + 1), name: `Club hockey ${id} extérieur` },
        scores: {},
        readings: [{
          id: "winning_streak",
          subject_team_id: String(id * 2),
          side: "home",
          sample_size: 5,
          explanation: "Trois victoires finales consécutives",
        }],
        quotesCollectedAt: now.toISOString(),
        quotes: [
          {
            marketCode: "result_regulation",
            scope: "regulation",
            selectionCode: "home",
            decimalOdds: 2.2,
            capturedAt: now.toISOString(),
            bookmakerId: "1",
            bookmaker: "Test",
          },
          {
            marketCode: "double_chance_regulation",
            scope: "regulation",
            selectionCode: "home_draw",
            decimalOdds: 1.5,
            capturedAt: now.toISOString(),
            bookmakerId: "1",
            bookmaker: "Test",
          },
        ],
      })),
    },
  };
  return [football, hockey];
}
const cases: {
  name: string;
  message: string;
  accepts: (i: Intent, s: State) => void;
}[] = [
  {
    name: "first_ticket",
    message:
      "Pour samedi 10 octobre, prépare une composition de football avec une mise de 20 euros, trois rencontres maximum. Pas d’objectif de retour imposé.",
    accepts(i, s) {
      assert.equal(i.date, "2026-10-10");
      assert.deepEqual(i.sports, ["football"]);
      assert.equal(i.tickets[0]?.stake, 20);
      assert.equal(i.maxSelections, 3);
      assert.ok(s.messages.at(-1)?.ticketIds?.length);
    },
  },
  {
    name: "add_hockey",
    message:
      "Ajoute aussi le hockey. Je veux les deux sports dans la composition, avec les autres contraintes conservées.",
    accepts(i, s) {
      assert.deepEqual([...i.sports].sort(), ["football", "hockey"]);
      assert.equal(i.tickets[0]?.stake, 20);
      assert.equal(i.maxSelections, 3);
      assert.equal(i.requireEachSport, true);
      assert.equal(i.date, "2026-10-10");
      assert.ok(
        s.tickets.some((t) =>
          t.picks.some((p) => p.sport === "hockey") &&
          t.picks.some((p) => p.sport === "football")
        ),
      );
    },
  },
  {
    name: "football_only_shorter",
    message:
      "Finalement enlève le hockey, uniquement du football, avec deux rencontres maximum. Garde la mise et la journée.",
    accepts(i) {
      assert.deepEqual(i.sports, ["football"]);
      assert.equal(i.tickets[0]?.stake, 20);
      assert.equal(i.maxSelections, 2);
      assert.equal(i.date, "2026-10-10");
    },
  },
  {
    name: "odds_goal",
    message:
      "Je garde ces contraintes mais je vise maintenant une cote cumulée autour de 3,50. Tu peux revoir les rencontres et les marchés si nécessaire.",
    accepts(i) {
      assert.equal(i.targetOdds, 3.5);
      assert.equal(i.tickets[0]?.stake, 20);
      assert.equal(i.maxSelections, 2);
      assert.equal(i.date, "2026-10-10");
      assert.deepEqual(i.sports, ["football"]);
    },
  },
  {
    name: "other_day",
    message:
      "Refais cette composition pour lundi 12 octobre dans Tous. Conserve les autres contraintes.",
    accepts(i) {
      assert.equal(i.date, "2026-10-12");
      assert.equal(i.view, "all");
      assert.equal(i.tickets[0]?.stake, 20);
      assert.equal(i.maxSelections, 2);
      assert.equal(i.targetOdds, 3.5);
    },
  },
  {
    name: "no_write",
    message:
      "Active le marché buteur dans mon profil et enregistre automatiquement ce pari comme placé.",
    accepts(i, s) {
      assert.equal(i.action, "unsupported");
      assert.deepEqual(s.context.preferences, context.preferences);
      assert.equal(s.saved, false);
    },
  },
];
const outcomes: unknown[] = [], receipts: ModelReceipt[] = [];
let success = true;
for (const model of comparisonModels) {
  let state: State | null = null;
  for (const evaluation of cases) {
    const began = performance.now(), priorReceipts = receipts.length;
    try {
      const result = await converse({
        message: evaluation.message,
        date: "2026-10-10",
        context: structuredClone(context),
        state,
        today: "2026-10-08",
        now,
        id: "99999999-9999-4999-8999-999999999999",
      }, {
        key,
        model,
        onReceipt: (r) => receipts.push(r),
        reads: {
          sources: async (_scope, day, sports) =>
            publications(day).filter((p) => sports.includes(p.sport)),
          bilan: async () => ({ readings: [], personal: [], synthetic: true }),
        },
      });
      state = result.next;
      evaluation.accepts(state.conversation!.workingIntent, state);
      const record = {
        model,
        case: evaluation.name,
        passed: true,
        elapsedMs: Math.round(performance.now() - began),
        paidCalls: receipts.length - priorReceipts,
        intent: state.conversation!.workingIntent,
        response: state.messages.at(-1)?.text,
        consultations: result.consultations,
        tickets: state.tickets.map((t) => ({
          id: t.id,
          stake: t.stake,
          totalOdds: t.totalOdds,
          sports: t.picks.map((p) => p.sport),
          matches: t.picks.map((p) => p.matchId),
        })),
      };
      outcomes.push(record);
      console.log(
        JSON.stringify({
          model,
          case: evaluation.name,
          passed: true,
          paidCalls: record.paidCalls,
          elapsedMs: record.elapsedMs,
        }),
      );
    } catch (error) {
      success = false;
      outcomes.push({
        model,
        case: evaluation.name,
        passed: false,
        error: error instanceof Error ? error.message : "evaluation_failed",
        intent: state?.conversation?.workingIntent,
        response: state?.messages.at(-1)?.text,
      });
      console.log(
        JSON.stringify({
          model,
          case: evaluation.name,
          passed: false,
          error: error instanceof Error ? error.message : "evaluation_failed",
        }),
      );
      break; // Do not retry paid calls or test context-dependent follow-ups after a failure.
    }
  }
}
const report = {
  protocol: "lector-conversation-v2",
  synthetic: true,
  accountWrites: 0,
  outcomes,
  receipts,
  estimatedUsd: {
    minimum: receipts.reduce((n, r) => n + (r.estimatedUsd?.minimum ?? 0), 0),
    maximum: receipts.reduce((n, r) => n + (r.estimatedUsd?.maximum ?? 0), 0),
  },
};
await Deno.writeTextFile(
  "/tmp/lector-generator-conversation.json",
  JSON.stringify(report, null, 2),
);
console.log(
  JSON.stringify({
    conversationEvaluationPassed: success,
    turns: outcomes.length,
    paidCalls: receipts.length,
    estimatedUsd: report.estimatedUsd,
  }),
);
if (!success) {
  throw new Error(
    "Conversation evaluation failed; deployment must remain blocked.",
  );
}
