/** One paid replay of the reported clarification, in memory, with no account edit. */
import { interpret } from "../supabase/functions/_shared/generator/openai.ts";
import {
  calendarDay,
  contextFrom,
  type State,
  validateIntent,
} from "../supabase/functions/_shared/generator/contracts.ts";
import {
  buildCatalog,
  type Source,
} from "../supabase/functions/_shared/generator/catalog.ts";
import { compose } from "../supabase/functions/_shared/generator/engine.ts";
import { sourceQuery } from "../supabase/functions/_shared/generator/service.ts";
const token = Deno.env.get("SUPABASE_ACCESS_TOKEN")!,
  key = Deno.env.get("OPENAI_API_KEY")!;
if (!token || !key) throw new Error("Missing repository credentials.");
async function query(query: string, parameters: unknown[] = []) {
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
      body: JSON.stringify({ query, parameters }),
    },
  );
  if (!response.ok) {
    throw new Error(`Regression database HTTP ${response.status}`);
  }
  return await response.json();
}
const own = await query(
  "select c.state from public.lector_generator_conversations c join auth.users u on u.id=c.user_id where lower(u.email) in ('jpaulbengiar@gmail.com','jpaulbenga@gmail.com') and c.id='41a2fd3b-3432-4c36-8ef0-65c1a7266b5a' order by c.updated_at desc limit 1",
);
const state = own[0]?.state as State;
if (!state?.messages?.length) {
  throw new Error("Reported conversation is unavailable.");
}
const context = contextFrom(state.context), now = new Date();
const reserved = await query(
  "update public.lector_generator_budget set reserved_usd=reserved_usd+0.025 where id=true and reserved_usd+0.025<=limit_usd returning id",
);
if (!reserved.length) throw new Error("Test envelope exhausted.");
const model = "gpt-4.1-mini-2025-04-14";
const start = performance.now();
const result = await interpret({
  message: "retour total",
  date: calendarDay(now, context.timezone),
  today: calendarDay(now, context.timezone),
  context,
  state,
}, { key, model });
const i = result.intent;
if (
  i.action !== "generate" || i.date !== "2026-10-10" ||
  i.sports.join() !== "football" || i.maxSelections !== 6 ||
  i.tickets.length !== 1 || i.tickets[0].stake !== 50 ||
  i.tickets[0].kind !== "total" || i.tickets[0].minimum === null ||
  Math.abs(i.tickets[0].minimum - 500) > 50 || validateIntent(i, context, now)
) throw new Error("Reported clarification constraints were not preserved.");
const sourcesStart = performance.now();
const rows = await query(
  "select public.lector_generator_sources_filtered($1::date,$2::text,$3::text[],$4::text[],$5::text[],$6::text[]) v",
  [
    i.date,
    context.timezone,
    i.sports,
    sourceQuery(context, i.date, i.sports).p_competitions,
    sourceQuery(context, i.date, i.sports).p_readings,
    sourceQuery(context, i.date, i.sports).p_scenarios,
  ],
);
const sources = rows[0].v as Source[];
const sourceMs = Math.round(performance.now() - sourcesStart);
if (sourceMs >= 15000) {
  throw new Error("Source retrieval still exceeds the backend deadline.");
}
const catalog = buildCatalog(sources, context, i.date, now),
  tickets = compose(catalog.candidates, i, context);
if (
  tickets.some((t) =>
    t.stake !== 50 || t.picks.length > 6 ||
    t.picks.some((p) => p.sport !== "football")
  )
) throw new Error("Composed constraints failed.");
console.log(JSON.stringify({
  regression: "reported_clarification",
  passed: true,
  paid_calls: 1,
  source_ms: sourceMs,
  source_count: sources.length,
  source_bytes: new TextEncoder().encode(JSON.stringify(sources)).length,
  match_count: catalog.matchCount,
  candidate_count: catalog.candidates.length,
  tickets: tickets.length,
  pick_count: tickets[0]?.picks.length,
  return_total: tickets[0]?.returnTotal,
  elapsed_ms: Math.round(performance.now() - start),
  usage: result.usage,
}));
await Deno.writeTextFile("/tmp/lector-generator-model.txt", model);
