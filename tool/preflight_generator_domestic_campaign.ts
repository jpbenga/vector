/** Independent campaign 2 data audit. No API key, grading or remote fetch. */
import { ConversationReader } from "../supabase/functions/_shared/generator/conversation_tools.ts";
import type { Source } from "../supabase/functions/_shared/generator/catalog.ts";
import type { Context } from "../supabase/functions/_shared/generator/contracts.ts";
import {
  campaign1Profile,
  domesticCampaignReadiness,
  sha256,
} from "./generator_exploration_campaign.ts";
const [path, output, day, asOf, maxAgeHours] = Deno.args;
if (!path || !output || !day || !asOf) {
  throw Error(
    "Indiquer export JSON, sortie JSON, date sportive et borne observation UTC.",
  );
}
const bytes = await Deno.readFile(path),
  input = JSON.parse(new TextDecoder().decode(bytes));
// An archived single-publication example is accepted for a data smoke check;
// it does not become a new large-day campaign by passing this parser.
const sources: Source[] = Array.isArray(input.sources) ? input.sources : [{
  id: "archived-data-check",
  sport: "football",
  capturedAt: input.capturedAt,
  payload: { raw: input.raw, computed: input.computed ?? { fixtures: [] } },
}];
const now = new Date(asOf);
if (!Number.isFinite(now.getTime())) throw Error("Borne observation invalide.");
const context: Context = {
  view: "all",
  origin: "profile",
  scope: "strict",
  timezone: "Europe/Paris",
  budget: 0,
  preferences: {
    football: {
      competitions: [],
      readings: [...campaign1Profile.readings],
      markets: [],
    },
  },
};
const reader = new ConversationReader({
  context,
  date: day,
  now,
  state: null,
  id: "campaign-2-data-check",
  message: "Audit des données de forme vérifiée",
}, { sources: async () => sources });
const query = await reader.query(day, ["football"], "all", "teams");
const report = {
  ...domesticCampaignReadiness(
    query,
    now,
    maxAgeHours ? Number(maxAgeHours) : 24,
  ),
  sourcePath: path,
  sourceSha256: await sha256(bytes),
  auditAsOf: asOf,
  testProfile: campaign1Profile,
  authorization: { paid: false, requiresSeparateAuthorization: true },
};
await Deno.writeTextFile(output, JSON.stringify(report, null, 2));
console.log(
  JSON.stringify({
    campaign: report.campaign,
    status: report.status,
    fixtureCount: report.fixtureCount,
    fullyVerified: report.fullyVerified,
    paidCalls: 0,
  }),
);
