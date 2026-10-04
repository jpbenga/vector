/** Shared server transport, independent of any football orchestrator. */
export class SupabaseSportStore {
  constructor(private baseUrl: string, private serviceKey: string) {
    if (!baseUrl || !serviceKey) {
      throw new Error("Missing sport storage configuration");
    }
  }
  private async post(path: string, body: unknown): Promise<unknown> {
    const response = await fetch(`${this.baseUrl}/rest/v1/${path}`, {
      method: "POST",
      redirect: "error",
      headers: {
        apikey: this.serviceKey,
        authorization: `Bearer ${this.serviceKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(15_000),
    });
    if (!response.ok) {
      throw new Error(`Sport storage ${path}: HTTP ${response.status}`);
    }
    const text = await response.text();
    return text ? JSON.parse(text) : null;
  }
  claim(sport: string, competition: string) {
    return this.post("rpc/sport_collection_claim", {
      p_sport: sport,
      p_competition: competition,
    });
  }
  reserve(runId: string) {
    return this.post("rpc/reserve_sport_request", { p_run: runId });
  }
  async saveRaw(runId: string, kind: string, payload: unknown) {
    await this.post("sport_raw_responses", { run_id: runId, kind, payload });
  }
  finish(runId: string, payload: unknown) {
    return this.post("rpc/sport_collection_finish", {
      p_run: runId,
      p_payload: payload,
    });
  }
  fail(runId: string, error: string) {
    return this.post("rpc/sport_collection_finish", {
      p_run: runId,
      p_error: error,
    });
  }
}
