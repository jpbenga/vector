import type { Sport } from "./contracts.ts";

export const sameSports = (a: Sport[], b: Sport[]) =>
  [...a].sort().join() === [...b].sort().join();

/** Only literal, unambiguous sport instructions. This is not an intent classifier:
 * names of teams, inferred competitions and questions about another sport do not
 * silently replace the session's constraints. The model still interprets intent. */
export function requestedSports(message: string): Sport[] | null {
  const text = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
  if (/^\s*(pourquoi|explique|comment)\b/.test(text)) return null;
  const sports = (["football", "hockey"] as Sport[]).filter((s) =>
    new RegExp(`\\b${s}\\b`).test(text)
  );
  if (!sports.length) return null;
  const excluded = sports.filter((s) =>
    new RegExp(
      `\\b(?:sans |sauf |exclu[st]? |pas (?:de |du )?|ne (?:veux|veut) pas (?:de |du )?)${s}\\b`,
    ).test(text)
  );
  if (excluded.length) {
    const included = sports.filter((s) => !excluded.includes(s));
    // A lone negation is not an instruction to select the other discipline.
    return included.length ? included : null;
  }
  if (sports.length === 1) return sports;
  if (
    /\bmultisport\b|football\s*(?:\+|et|&|avec)\s*(?:du |le )?hockey|hockey\s*(?:\+|et|&|avec)\s*(?:du |le )?football/
      .test(text)
  ) {
    return sports;
  }
  const target = text.match(
    /(?:passe|passons|passer|remplace|uniquement|seulement)[^.!?]{0,30}\b(football|hockey)\b/,
  );
  return target ? [target[1] as Sport] : null;
}

export type CompositionContract = {
  code: "sport_scope_mismatch" | "composition_details_missing";
  expected: { date: string; sports: Sport[]; view: string; radarKind: string };
  received: { date: string; sports: Sport[]; view: string; radarKind: string };
  queryId: string | null;
  dossierKeys: string[];
  compatibleQueryIds: string[];
  repair: string;
};

export class CompositionContractError extends Error {
  override readonly name = "CompositionContractError";
  readonly stage = "conversation/composition_contract";
  constructor(readonly contract: CompositionContract) {
    super(
      contract.code === "sport_scope_mismatch"
        ? `Le périmètre sportif demandé (${
          contract.expected.sports.join(" + ")
        }) diffère de celui du calcul (${
          contract.received.sports.join(" + ")
        }). Précisez le changement souhaité ; aucun ticket n’a été calculé.`
        : "Les données nécessaires au calcul n’ont pas été consultées dans le même périmètre que l’analyse. Une nouvelle lecture des rencontres concernées est nécessaire ; aucun ticket n’a été présenté.",
    );
  }
  fingerprint() {
    return JSON.stringify([
      this.contract.code,
      this.contract.expected,
      this.contract.received,
      this.contract.queryId,
      [...this.contract.dossierKeys].sort(),
    ]);
  }
  result() {
    return { error: this.message, contract: this.contract, noMutation: true };
  }
}
