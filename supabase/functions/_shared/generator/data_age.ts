/** Observation dates remain factual. Age is a disclosure, never an expiry. */
export function dataAgeWarnings(
  publicationAt: string,
  quoteAt?: string,
  now = new Date(),
): string[] {
  const warnings: string[] = [];
  for (
    const [label, at, hours] of [
      ["Publication analytique", publicationAt, 36],
      ["Cote", quoteAt, 48],
    ] as const
  ) {
    if (!at) continue;
    const age = now.getTime() - Date.parse(at);
    if (Number.isFinite(age) && age > hours * 3600000) {
      warnings.push(
        `${label} ancienne : relevée le ${at} (${
          Math.floor(age / 3600000)
        } h). Utilisée telle que publiée ; sa valeur actuelle n’est pas confirmée.`,
      );
    }
  }
  return warnings;
}
