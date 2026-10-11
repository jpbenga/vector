import assert from "node:assert/strict";
import { archiveWork, compactModelMemory } from "./work_storage.ts";
import { type State, type Ticket } from "./contracts.ts";
import { context, intent } from "./evaluation_cases.ts";
import { rememberTurn } from "./conversation_memory.ts";

Deno.test("large immutable work is archived once; subsequent messages and model memory stay compact", () => {
  const ticket = {
    id: crypto.randomUUID(),
    number: 1,
    target: { stake: 50 },
    picks: [{
      id: "p",
      sport: "football",
      matchId: "api-fixture-1",
      home: "A",
      away: "B",
      marketId: "matchResult",
      selection: "A gagne",
      evidence: [{ id: "f", text: "x".repeat(400000) }],
    }],
  } as unknown as Ticket;
  const state = {
    id: crypto.randomUUID(),
    revision: 1,
    context,
    intent,
    tickets: [ticket],
    drafts: [ticket],
    proposals: [ticket],
    versions: [[ticket]],
    pending: [ticket],
    messages: [{ role: "user", text: "Analyse" }, {
      role: "assistant",
      text: "Résultat ".repeat(4000),
    }],
    saved: false,
    updatedAt: new Date().toISOString(),
  } as State;
  rememberTurn(state, null, intent, [], []);
  const first = archiveWork(state);
  assert.equal(first.tickets.length, 1);
  assert.ok(JSON.stringify(first.state).length < 12000);
  assert.ok(JSON.stringify(compactModelMemory(state)).length < 12000);
  const oldMessages = new Set(first.messages.map((m) => m.id));
  const hydrated = {
    ...state,
    messages: [...first.messages],
    conversation: { ...state.conversation!, turns: first.turns },
  };
  hydrated.messages.push({
    id: crypto.randomUUID(),
    role: "user",
    text: "Merci",
  }, { id: crypto.randomUUID(), role: "assistant", text: "Avec plaisir" });
  const second = archiveWork(
    hydrated,
    new Set([ticket.id]),
    oldMessages,
    new Set(first.turns.map((t) => t.id)),
  );
  assert.equal(second.tickets.length, 0);
  assert.equal(second.messages.length, 2);
  assert.equal(second.turns.length, 0);
  assert.ok(JSON.stringify(second).length < 15000);
  assert.equal(first.tickets[0].picks[0].evidence[0].text.length, 400000);
});
