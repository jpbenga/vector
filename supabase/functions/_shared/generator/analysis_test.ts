import nodeAssert from "node:assert/strict";
import {
  analysisCandidates,
  analysisContext,
  analyzeDay,
  readAnalysisResponse,
} from "./analysis.ts";
import { buildCatalog } from "./catalog.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import { obj, rows } from "./contracts.ts";
const assert = (value: unknown, message = "assertion failed") => {
  if (!value) throw new Error(message);
};
async function rejects(fn: () => Promise<unknown>) {
  let failed = false;
  try {
    await fn();
  } catch {
    failed = true;
  }
  assert(failed);
}
const request = {
  ...intent,
  action: "analyze" as const,
  tickets: [],
  maxSelections: 5,
  view: "profile" as const,
};
function result(output: unknown[]) {
  return {
    id: "response-test",
    model: "gpt-6.1-sol",
    status: "completed",
    usage: {
      input_tokens: 100,
      output_tokens: 60,
      output_tokens_details: { reasoning_tokens: 20 },
    },
    output,
  };
}
function final(
  candidates: ReturnType<typeof analysisCandidates>,
  ids: string[],
) {
  return result([{
    type: "message",
    content: [{
      type: "output_text",
      text: JSON.stringify({
        text: "Voici les rencontres à examiner, avec les limites des données.",
        comparedMatchIds: ids,
        limitations: ["Les séries de forme peuvent se recouper."],
        selections: candidates.slice(0, 1).map((c) => ({
          candidateId: c.id,
          reason: "La solidité à domicile soutient ce marché.",
          vigilance: "L’adversaire a un avantage au classement.",
          references: [c.evidence[0].id],
        })),
      }),
    }],
  }]);
}
Deno.test("explicit views narrow Pour moi, retain preferences and include only factual scoped matches", () => {
  const config = analysisContext({ ...context, scope: "discovery" }, request);
  assert(config.scope === "strict" && config.view === "profile");
  assert(config.preferences === context.preferences);
  const s = source();
  rows(obj(s.payload.raw).fixtures)[0].league = { id: 999, name: "Outside" };
  assert(buildCatalog([s], config, request.date, now).matches?.length === 3);
  assert(
    buildCatalog(
      [s],
      analysisContext(context, { ...request, view: "all" }),
      request.date,
      now,
    ).matches?.length === 4,
  );
});
Deno.test("semantic quote duplicates do not inflate the options; stale prices remain excluded", () => {
  const catalog = buildCatalog([source()], context, request.date, now);
  const c = catalog.candidates[0];
  catalog.candidates.push({ ...c, id: "duplicate", odds: 1.04 });
  assert(analysisCandidates(catalog, request, now).length === 8);
  catalog.candidates.push({ ...c, id: "old", oddsAt: "2020-01-01", odds: 8 });
  assert(
    !analysisCandidates(catalog, request, now).some((c) => c.id === "old"),
  );
});
Deno.test("contextual analysis compares the overview, fetches verified details, and accounts for medium reasoning", async () => {
  const catalog = buildCatalog([source()], context, request.date, now),
    candidates = analysisCandidates(catalog, request, now);
  const ids = catalog.matches!.map((m) => m.id),
    phases: string[] = [],
    receipts: unknown[] = [];
  let calls = 0;
  const analysis = await analyzeDay({
    message: "Top 5 dans Pour moi",
    intent: request,
    context,
    catalog,
    state: null,
    now,
  }, {
    key: "test",
    model: "gpt-6.1-sol",
    onReceipt: (r) => receipts.push(r),
    onProgress: async (p) => {
      phases.push(p.phase);
    },
    fetcher: ((_url: unknown, init: RequestInit) => {
      const body = obj(JSON.parse(String(init.body)));
      assert(
        obj(body.reasoning).effort === "medium" &&
          obj(body.reasoning).summary === "auto" && body.stream === true,
      );
      assert(body.store === false && body.parallel_tool_calls === false);
      if (++calls === 1) {
        const overview = obj(
          JSON.parse(String(obj((body.input as unknown[])[0]).content)),
        );
        assert(
          rows(overview.matches).length === 4 &&
            obj(overview.context).date === request.date,
        );
        return Promise.resolve(
          Response.json(
            result([{ type: "reasoning", id: "reasoning-test", summary: [] }, {
              type: "function_call",
              name: "get_match_details",
              call_id: "lookup",
              arguments: JSON.stringify({ matchIds: ids }),
            }]),
          ),
        );
      }
      const toolOutput = rows(body.input).find((x) =>
        x.type === "function_call_output"
      );
      assert(
        toolOutput?.call_id === "lookup" &&
          String(toolOutput.output).includes("Avantage au classement"),
      );
      assert(rows(body.input).some((x) => x.id === "reasoning-test"));
      return Promise.resolve(Response.json(final(candidates, ids)));
    }) as typeof fetch,
  });
  assert(calls === 2 && receipts.length === 2 && phases.includes("details"));
  assert(analysis.selections[0].candidate.odds === candidates[0].odds);
  assert(
    analysis.context.view === "profile" && analysis.selections.length === 1,
  );
});
Deno.test("out-of-scope tools stop before a second paid request", async () => {
  let calls = 0;
  await rejects(() =>
    analyzeDay({
      message: "top 5",
      intent: request,
      context,
      catalog: buildCatalog([source()], context, request.date, now),
      state: null,
      now,
    }, {
      key: "test",
      model: "gpt-6.1-sol",
      fetcher: (() => {
        calls++;
        return Promise.resolve(
          Response.json(
            result([{
              type: "function_call",
              name: "get_match_details",
              call_id: "bad",
              arguments: '{"matchIds":["other-user-match"]}',
            }]),
          ),
        );
      }) as typeof fetch,
    })
  );
  assert(calls === 1);
});
Deno.test("a shortlist cannot skip details or invent selection IDs or evidence", async () => {
  const catalog = buildCatalog([source()], context, request.date, now);
  await rejects(() =>
    analyzeDay({
      message: "top 5",
      intent: request,
      context,
      catalog,
      state: null,
      now,
    }, {
      key: "test",
      model: "gpt-6.1-sol",
      fetcher: (() =>
        Promise.resolve(
          Response.json(final(
            catalog.candidates,
            catalog.matches!.map((m) => m.id),
          )),
        )) as typeof fetch,
    })
  );
});
Deno.test("empty scope abstains without a paid call and keeps its selected date", async () => {
  const analysis = await analyzeDay({
    message: "top 5",
    intent: request,
    context,
    catalog: buildCatalog([], context, request.date, now),
    state: null,
    now,
  }, {
    key: "test",
    model: "gpt-6.1-sol",
    fetcher: (() => {
      throw new Error("must not call");
    }) as typeof fetch,
  });
  assert(
    analysis.selections.length === 0 && analysis.context.date === request.date,
  );
});
Deno.test("stream parsing exposes API summaries only and requires a confirmed completion", async () => {
  const frames = [
    { type: "response.reasoning_text.delta", delta: "PRIVATE MUST NOT APPEAR" },
    {
      type: "response.reasoning_summary_text.delta",
      delta: "Comparaison des données.",
    },
    { type: "response.completed", response: result([]) },
  ].map((x) => `data: ${JSON.stringify(x)}\n\n`).join("");
  const summaries: string[] = [];
  const body = new ReadableStream({
    start(c) {
      const bytes = new TextEncoder().encode(frames);
      for (let i = 0; i < bytes.length; i += 7) {
        c.enqueue(bytes.slice(i, i + 7));
      }
      c.close();
    },
  });
  const response = await readAnalysisResponse(
    new Response(body, { headers: { "content-type": "text/event-stream" } }),
    async (s) => {
      summaries.push(s);
    },
  );
  assert(
    response.status === "completed" &&
      summaries.join("").includes("Comparaison"),
  );
  assert(!summaries.join("").includes("PRIVATE"));
  await rejects(() =>
    readAnalysisResponse(
      new Response('data: {"type":"response.created"}\n\n', {
        headers: { "content-type": "text/event-stream" },
      }),
      async () => {},
    )
  );
});
Deno.test("cancelled progress interrupts tool analysis without a replacement result", async () => {
  let calls = 0;
  await rejects(() =>
    analyzeDay({
      message: "top 5",
      intent: request,
      context,
      catalog: buildCatalog([source()], context, request.date, now),
      state: null,
      now,
    }, {
      key: "test",
      model: "gpt-6.1-sol",
      onProgress: async (p) => {
        if (p.phase === "details") throw new Error("cancelled");
      },
      fetcher: (() => {
        calls++;
        return Promise.resolve(
          Response.json(
            result([{
              type: "function_call",
              name: "get_match_details",
              call_id: "lookup",
              arguments: '{"matchIds":["api-fixture-1"]}',
            }]),
          ),
        );
      }) as typeof fetch,
    })
  );
  assert(calls === 1);
});
Deno.test("insufficient evidence is distinguished from missing collected quotes", () => {
  const s = source();
  for (const r of rows(rows(obj(s.payload.computed).fixtures)[0].readings)) {
    r.sample_size = 2;
  }
  const catalog = buildCatalog([s], context, request.date, now);
  assert(!catalog.candidates.some((c) => c.matchId === "api-fixture-1"));
  assert(
    catalog.matches?.find((m) => m.id === "api-fixture-1")
      ?.quoteAvailability === "recent",
  );
});

Deno.test("provider failure exposes a safe code without leaking provider messages", async () => {
  await nodeAssert.rejects(
    () =>
      readAnalysisResponse(
        Response.json({
          error: {
            code: "insufficient_quota",
            message: "private request data",
          },
        }, { status: 429 }),
        async () => {},
      ),
    /HTTP 429 · insufficient_quota/,
  );
  const events = "data: " +
    JSON.stringify({
      type: "error",
      code: "rate_limit_exceeded",
      message: "private request data",
    }) + "\n\n";
  await nodeAssert.rejects(
    () =>
      readAnalysisResponse(
        new Response(events, {
          headers: { "content-type": "text/event-stream" },
        }),
        async () => {},
      ),
    /interrompu \(rate_limit_exceeded\)/,
  );
});
