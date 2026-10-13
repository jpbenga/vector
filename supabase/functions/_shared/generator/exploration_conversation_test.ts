import assert from "node:assert/strict";
import { converse } from "./conversation.ts";
import { initialIntent } from "./conversation_memory.ts";
import {
  evaluateFixture,
  explorationDay,
  modelResponse,
} from "./exploration_cases.ts";
import { now } from "./evaluation_cases.ts";
import { obj, rows } from "./contracts.ts";

const tool = (name: string, args: unknown) => ({
  type: "function_call",
  name,
  call_id: name,
  arguments: JSON.stringify(args),
});
const response = (output: unknown[]) =>
  Response.json({
    id: "controlled-conversation",
    model: "gpt-6-luna",
    status: "completed",
    output,
    usage: { input_tokens: 100, output_tokens: 100 },
  });

Deno.test("conversation returns ten observations without quotes or stake, preserves the criterion, validates references and enforces server order", async () => {
  const { publication, context } = await explorationDay();
  let step = 0, calls = 0, detailed = 0, repaired = 0, selected: string[] = [];
  let saved: any;
  const result = await converse({
    message:
      "Parmi les 80 rencontres, montre-moi les dix selon mes lectures et la forme.",
    date: "2026-10-10",
    today: "2026-10-08",
    context,
    state: null,
    now,
    id: crypto.randomUUID(),
  }, {
    model: "gpt-6-luna",
    key: "test",
    reads: {
      sources: async () => [publication],
      matchData: async () => {
        detailed++;
        throw Error("unexpected");
      },
    },
    onEvaluation: async (report) => {
      saved = report;
    },
    onContractError: () => {
      repaired++;
    },
    fetcher: (async (_url, init) => {
      const body = JSON.parse(String(init?.body));
      if (body.text?.format?.name === "lector_match_evaluations") {
        calls++;
        return modelResponse(evaluateFixture(body));
      }
      if (step++ === 0) {
        return response([tool("search_matches", {
          date: "2026-10-10",
          sports: ["football"],
          view: "all",
          radarKind: "teams",
          query: null,
          offset: 0,
          limit: 60,
        })]);
      }
      if (step === 2) {
        return response([tool("evaluate_matches", {
          queryId: "q1",
          criteria: "mes lectures et la forme",
          matchKeys: null,
          observationCount: 10,
          useProfileReadings: true,
          formScope: "domestic_championship",
        })]);
      }
      const evaluation = body.input.filter((v: any) =>
        v.type === "function_call_output"
      )
        .map((v: any) => JSON.parse(v.output)).find((v: any) => v.exploration);
      selected = evaluation.exploration.selectedKeys;
      // Deliberately reversed: the server restores the reproducible order.
      const observations = [...selected].reverse().map((key) => ({
        matchId: key,
        reason: "Lecture publiée correspondant au critère.",
        references: saved.exploration.evidence[key].map((f: any) => f.id),
      }));
      const plan = {
        intent: {
          ...initialIntent(context, "2026-10-10"),
          action: "analyze" as const,
          sports: ["football"],
          view: "all",
          maxSelections: 6,
        },
        changedFields: ["sports", "view"],
        newTask: true,
        focusMode: "clear",
        focusKeys: [],
      };
      if (step === 3) {
        return modelResponse({
          plan,
          text: "Je ne peux pas proposer les rencontres sans cotes.",
          queryId: "q1",
          projectionId: null,
          analysis: null,
        });
      }
      return modelResponse({
        plan,
        text:
          "80 rencontres évaluées. Dix observations selon les lectures et les cinq résultats domestiques publiés.",
        queryId: "q1",
        projectionId: null,
        analysis: {
          text: "Exploration sans composition.",
          selections: [],
          observations,
          comparedMatchIds: [evaluation.comparisonReference],
          limitations: [],
        },
      });
    }) as typeof fetch,
  });
  const analysis = result.next.messages.at(-1)!.analysis!;
  assert.equal(analysis.selections.length, 0);
  assert.equal(analysis.observations!.length, 10);
  assert.deepEqual(
    analysis.observations!.map((o) => `${o.sport}:${o.matchId}`),
    selected,
  );
  assert.equal(analysis.exploration!.coverage.evaluated, 80);
  assert.equal(analysis.exploration!.criterion.observationCount, 10);
  assert.equal(
    analysis.exploration!.criterion.formScope,
    "domestic_championship",
  );
  assert.equal(detailed, 0);
  assert.equal(repaired, 1);
  assert.equal(calls, saved.batches);
  assert.equal(result.next.tickets.length, 0);
  assert.ok(JSON.stringify(analysis.exploration).length < 40000);
  assert.equal(rows(obj(analysis.exploration).manifest).length, 0);
});
