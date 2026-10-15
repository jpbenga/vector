import type { CompetitionConstraint, Sport } from "./contracts.ts";

/** Only explicitly named competitions. No inference from team nationality.
 * Null leaves the remembered scope intact; [] is an explicit removal. */
export function requestedCompetitions(
  message: string,
): CompetitionConstraint[] | null {
  const text = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
  if (/^\s*(pourquoi|explique|comment)\b/.test(text)) return null;
  if (
    /\b(?:toutes les competitions|sans restriction de competition)\b/.test(text)
  ) return [];
  const names: [string, string][] = [
    ["2", "(?:champions league|ligue des champions)"],
    ["3", "(?:europa (?:league|ligue)|ligue europa)"],
    ["40", "(?:championship)"],
    ["848", "(?:conference (?:league|ligue)|ligue (?:de )?conference)"],
  ];
  const scope: CompetitionConstraint[] = [];
  for (const [id, name] of names) {
    if (!new RegExp(`\\b${name}\\b`).test(text)) continue;
    if (
      new RegExp(`\\b(?:sans|sauf|pas de|exclure)\\s+(?:la |l['’])?${name}\\b`)
        .test(text)
    ) continue;
    const count = text.match(
      new RegExp(
        `\\b(\\d+|un|une|deux|trois|quatre|cinq|six|sept|huit)\\s+(?:(?:matchs?|rencontres?)\\s+)?(?:de\\s+|d['’]\\s*)(?:la\\s+|l['’])?(?:uefa\\s+)?${name}\\b`,
      ),
    );
    const numbers: Record<string, number> = {
      un: 1,
      une: 1,
      deux: 2,
      trois: 3,
      quatre: 4,
      cinq: 5,
      six: 6,
      sept: 7,
      huit: 8,
    };
    const n = count ? numbers[count[1]] ?? Number(count[1]) : undefined;
    scope.push({
      sport: "football",
      id,
      ...(n !== undefined && n >= 1 && n <= 20 ? { selections: n } : {}),
    });
  }
  return scope.length ? scope : null;
}

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

/** An explicit competition request uses the universal calendar unless the user
 * also names a restricted workspace. Never changes stored profile settings. */
export function requestedView(
  message: string,
): "profile" | "radar" | "shortlist" | "all" | null {
  const text = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
  if (/\b(?:ma |la )shortlist\b/.test(text)) return "shortlist";
  if (/\bradar\b/.test(text)) return "radar";
  if (/\bpour moi\b|\bmes lectures\b/.test(text)) return "profile";
  if (
    requestedCompetitions(message)?.length ||
    /\b(?:tous les matchs|toutes les rencontres)\b/.test(text)
  ) return "all";
  return null;
}

/** Literal per-selection minimum; independent of a cumulative ticket target. */
export function requestedMinimumSelectionOdds(message: string): number | null {
  const text = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
  const m = text.match(
    /cotes?\s+(?:inferieur(?:e)?s?\s+a|minimum(?:s)?(?:\s+de)?|minimale?s?(?:\s+de)?|(?:d'au moins|au moins))\s*(\d+(?:[.,]\d+)?)/,
  );
  if (!m) return null;
  // "inférieures à" describes a bound only when those odds are forbidden.
  if (/inferieur/.test(m[0]) && !/interdit|aucune|pas de|sans/.test(text)) {
    return null;
  }
  const value = Number(m[1].replace(",", "."));
  return Number.isFinite(value) && value > 1 && value <= 100 ? value : null;
}

/** Repair only an unrequested model year substitution for the same calendar day.
 * Explicit years and relative year requests remain untouched and are validated. */
export function repairUnrequestedYear(
  date: string,
  reference: string,
  message: string,
): string {
  const text = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "")
    .toLowerCase();
  if (
    /\b20\d{2}\b|an(?:nee)? (?:dernier|derniere|prochain|prochaine|precedent|precedente)|il y a .*ans?\b/
      .test(text)
  ) return date;
  return /^\d{4}-\d{2}-\d{2}$/.test(date) &&
      date.slice(5) === reference.slice(5)
    ? reference
    : date;
}
