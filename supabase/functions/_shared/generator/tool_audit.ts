import { obj, rows } from "./contracts.ts";
import { redactAuditText } from "./release.ts";

/** Owner-private facts only; never provider bodies, reasoning or credentials. */
export function toolAudit(
  name: string,
  args: unknown,
  result: unknown,
  elapsedMs: number,
) {
  const r = obj(result),
    matches = Array.isArray(result) ? rows(result) : rows(r.matches);
  const parameters = JSON.parse(
    redactAuditText(
      JSON.stringify(
        args,
        (key, value) =>
          /authorization|password|secret|token|api.?key/i.test(key)
            ? "[redacted]"
            : value,
      ),
    ),
  );
  return {
    name,
    parameters,
    elapsedMs: Math.round(elapsedMs),
    result: {
      queryId: r.queryId,
      total: r.total,
      offset: r.offset,
      hasMore: r.hasMore,
      nextOffset: r.nextOffset,
      coverage: r.coverage,
      sourceIds: r.sourceIds,
      missing: r.missing,
      error: typeof r.error === "string" ? redactAuditText(r.error) : undefined,
      contract: r.contract,
      scope: r.scope,
      competitionScope: r.competitionScope ?? obj(r.intent).competitionScope,
      dossiers: r.dossiers,
      projectionId: r.projectionId,
      alreadyConsulted: r.alreadyConsulted,
      previousCallId: r.previousCallId,
      matches: matches.slice(0, 60).map((m) => ({
        key: m.key,
        sourceId: m.sourceId,
        capturedAt: m.capturedAt,
        competitionId: m.competitionId,
        status: m.status,
        candidates: typeof m.candidates === "number"
          ? m.candidates
          : rows(m.candidates).length,
        evidenceReferences: rows(m.evidence).map((e) => e.id).slice(0, 40),
        publishedQuoteCount: rows(m.publishedQuotes).length,
        marketAvailability: m.marketAvailability,
      })),
      matchesTruncated: matches.length > 60,
    },
  };
}

/** Reject explicit empty-calendar claims after a failed search. The existing
 * bounded contract repair explains the technical failure before any commit. */
export function assertCatalogueAnswer(
  text: string,
  events: ReturnType<typeof toolAudit>[],
) {
  const searches = events.filter((e) =>
    e.name === "search_matches" || e.name === "read_shortlist"
  );
  const last = searches.at(-1);
  if (!last) return;
  const emptyClaim =
    /aucun(?:e)?\s+(?:match|rencontre)|ne\s+trouve\s+pas\s+(?:de\s+)?(?:match|rencontre)|no\s+(?:matches|fixtures)\s+found/i
      .test(text);
  const eligibilityClaim =
    /aucun(?:e)?\s+(?:match|rencontre)(?:\s+n[’']est\s+admissible|\s+ne\s+(?:peut|satisfait)|\s+(?:admissibl|composabl|analysabl|avec une cote))/i
      .test(text);
  const explainsFailure =
    /indisponibl|incompl[eè]t|erreur|[ée]chec|consultation impossible/i.test(
      text,
    );
  if (emptyClaim && last.result.error && !explainsFailure) {
    throw Error(
      "La recherche a échoué : expliquez l’indisponibilité technique, sans annoncer un calendrier vide.",
    );
  }
  if (
    emptyClaim && !eligibilityClaim && Number(last.result.total) > 0 &&
    typeof last.parameters?.query === "string" && last.parameters.query.trim()
  ) {
    throw Error(
      "La recherche ciblée a trouvé des rencontres : distinguez découverte, preuves et composition.",
    );
  }
}
