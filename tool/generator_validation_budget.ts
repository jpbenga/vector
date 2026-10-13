/** Admission accounting for an explicitly authorized validation, not billing. */
export class ValidationCallBudget {
  calls = 0;
  reservedUsd = 0;
  constructor(
    readonly maxUsd: number,
    readonly maxCalls: number,
    readonly inputPrice: number,
    readonly outputPrice: number,
  ) {
    if (
      !Number.isFinite(maxUsd) || maxUsd <= 0 || !Number.isInteger(maxCalls) ||
      maxCalls < 1 || maxCalls > 40 || !Number.isFinite(inputPrice) ||
      inputPrice <= 0 || !Number.isFinite(outputPrice) || outputPrice <= 0
    ) throw Error("Plafond de validation invalide.");
  }
  admit(body: string) {
    const payload = JSON.parse(body),
      outputTokens = Number(payload.max_output_tokens ?? 6000);
    if (
      !Number.isInteger(outputTokens) || outputTokens <= 0 ||
      outputTokens > 6000
    ) throw Error("Borne de sortie invalide.");
    // Bytes plus overhead are a conservative token admission estimate. Output
    // includes reasoning tokens. Keep reservations on timeout/unknown usage.
    const bytes = new TextEncoder().encode(body).length;
    const amount = ((bytes + 4096) * this.inputPrice * 1.25 +
      outputTokens * this.outputPrice) / 1e6;
    if (
      this.calls >= this.maxCalls || this.reservedUsd + amount > this.maxUsd
    ) throw Error("Plafond de validation atteint avant un nouvel appel.");
    this.calls++;
    this.reservedUsd += amount;
    return amount;
  }
}
