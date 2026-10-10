import assert from "node:assert/strict";
import { buildCatalog } from "./catalog.ts";
import { context, intent, now, source } from "./evaluation_cases.ts";
import {
  modelCandidate,
  modelEvidence,
  modelTickets,
} from "./conversation_projection.ts";
import { ticketSummary } from "./conversation_memory.ts";
import { applyIntent } from "./service.ts";
import { GeneratorFailure, generatorTimeoutMessage } from "./failures.ts";

Deno.test("model projection removes images and repeated identities while retaining every market, quote and sporting fact", () => {
  const c = structuredClone(
    buildCatalog([source()], context, intent.date, now).candidates[0],
  );
  c.homeLogo = "https://example.test/home.png";
  c.evidence[0].photo = "https://example.test/player.png";
  c.evidence[0].metrics = [{ label: "Points", value: "15 / 15" }];
  c.evidence[0].lineage = { kind: "recent_results", matchIds: ["1", "2", "3"] };
  const projected = modelCandidate(c, now);
  assert.equal(projected.id, c.id);
  assert.equal(projected.odds, c.odds);
  assert.equal(projected.oddsAt, c.oddsAt);
  assert.equal(projected.bookmaker, c.bookmaker);
  assert.deepEqual(projected.teams, c.teams);
  assert.equal(projected.competitionId, c.competitionId);
  assert.deepEqual(
    projected.evidence.map((e) => e.id),
    c.evidence.map((e) => e.id),
  );
  const { photo: _photo, ...fact } = c.evidence[0];
  assert.deepEqual(modelEvidence(c.evidence[0]), fact);
  assert.ok(!JSON.stringify(projected).includes("home.png"));
  assert.ok(c.evidence[0].photo);
});

Deno.test("multiple composition variants share full facts once without changing persisted tickets or price snapshots", () => {
  const state = applyIntent({
    state: null,
    context,
    intent,
    sources: [source()],
    message: "Test",
    now,
    id: "test",
    workshop: true,
  });
  const tickets = state.proposals!;
  assert.ok(tickets.length > 1);
  const original = JSON.stringify(tickets);
  const projected = modelTickets(tickets);
  const facts = new Map(projected.facts.map((f) => [f.id, f]));
  for (const [i, t] of tickets.entries()) {
    assert.equal(projected.tickets[i].totalOdds, t.totalOdds);
    assert.equal(projected.tickets[i].returnTotal, t.returnTotal);
    for (const [j, c] of t.picks.entries()) {
      const p = projected.tickets[i].picks[j];
      assert.equal(p.odds, c.odds);
      assert.equal(p.oddsAt, c.oddsAt);
      assert.equal(p.bookmaker, c.bookmaker);
      assert.deepEqual(
        p.evidence.map((e) => e.id),
        c.evidence.map((e) => e.id),
      );
      for (const [k, e] of c.evidence.entries()) {
        const { supportsMarket, role, ...fact } = modelEvidence(e);
        assert.deepEqual(facts.get(e.id), fact);
        assert.equal(p.evidence[k].supportsMarket, supportsMarket);
        assert.equal(p.evidence[k].role, role);
      }
    }
  }
  assert.equal(JSON.stringify(tickets), original);
  const full = JSON.stringify(tickets.map(ticketSummary));
  assert.ok(JSON.stringify(projected).length < full.length);
});

Deno.test("timeouts identify model response and data fetching separately, preserving the original error name", () => {
  const error = new GeneratorFailure(
    new DOMException("Signal timed out.", "TimeoutError"),
    "conversation/respond",
  );
  assert.equal(error.name, "TimeoutError");
  assert.equal(error.stage, "conversation/respond");
  assert.match(generatorTimeoutMessage(error.stage), /réponse IA/);
  assert.ok(!generatorTimeoutMessage(error.stage).includes("récupération"));
  assert.match(
    generatorTimeoutMessage("rpc/lector_generator_day_page"),
    /récupération/,
  );
});
