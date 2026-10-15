/** Server-owned, per-exchange budgets. No user/session quota and no new storage. */
export interface ExplorationBudgetConfig {
  internalMs: number;
  evaluationMs: number;
  deepeningMs: number;
  finalizationMs: number;
  maxDeepened: number;
  extraBatchCalls: number;
}
export const defaultExplorationBudget: Readonly<ExplorationBudgetConfig> = {
  internalMs: 330000,
  evaluationMs: 135000,
  deepeningMs: 60000,
  finalizationMs: 105000,
  maxDeepened: 4,
  extraBatchCalls: 2,
};
export function explorationBudgetConfig(
  input: Partial<ExplorationBudgetConfig> = {},
): ExplorationBudgetConfig {
  const config = { ...defaultExplorationBudget, ...input };
  const caps: Record<keyof ExplorationBudgetConfig, number> = {
    internalMs: 390000,
    evaluationMs: 285000,
    deepeningMs: 285000,
    finalizationMs: 180000,
    maxDeepened: 4,
    extraBatchCalls: 2,
  };
  for (const key of Object.keys(config) as (keyof ExplorationBudgetConfig)[]) {
    if (
      !(key in caps) || !Number.isInteger(config[key]) || config[key] < 0 ||
      config[key] > caps[key]
    ) throw new Error(`Budget d’exploration invalide : ${key}.`);
  }
  if (
    config.internalMs < 1000 || config.finalizationMs < 1000 ||
    config.finalizationMs >= config.internalMs ||
    config.evaluationMs + config.deepeningMs >
      config.internalMs - config.finalizationMs
  ) {
    throw new Error(
      "Les phases d’exploration consomment la réserve de finalisation.",
    );
  }
  return config;
}
/** Env reads stay in the handler; tests and domain code require no env permissions. */
export function explorationBudgetFromEnvironment(
  read: (key: string) => string | undefined,
) {
  const input: Partial<ExplorationBudgetConfig> = {};
  const names: Record<keyof ExplorationBudgetConfig, string> = {
    internalMs: "LECTOR_EXPLORATION_INTERNAL_MS",
    evaluationMs: "LECTOR_EXPLORATION_EVALUATION_MS",
    deepeningMs: "LECTOR_EXPLORATION_DEEPENING_MS",
    finalizationMs: "LECTOR_EXPLORATION_FINALIZATION_MS",
    maxDeepened: "LECTOR_EXPLORATION_MAX_DEEPENED",
    extraBatchCalls: "LECTOR_EXPLORATION_EXTRA_BATCH_CALLS",
  };
  for (const key of Object.keys(names) as (keyof ExplorationBudgetConfig)[]) {
    const value = read(names[key]);
    if (value !== undefined && value !== "") input[key] = Number(value);
  }
  return explorationBudgetConfig(input);
}
export type DeepeningReason =
  | "boundary_tie"
  | "relevant_conflict"
  | "missing_decisive_fact"
  | "explicit_comparison";
export class ExplorationBudget {
  readonly config: ExplorationBudgetConfig;
  private evaluationStarted: number | null = null;
  private deepeningStarted: number | null = null;
  private batches = 0;
  private deepened = new Map<string, DeepeningReason>();
  private denied: string[] = [];
  private results = new Map<
    string,
    | "available"
    | "absent"
    | "timeout"
    | "version_mismatch"
    | "oversized"
    | "failed"
  >();
  constructor(
    config: Partial<ExplorationBudgetConfig> = {},
    private clock: () => number = () => performance.now(),
    private started = clock(),
  ) {
    this.config = explorationBudgetConfig(config);
  }
  get deadline() {
    return this.started + this.config.internalMs;
  }
  get workDeadline() {
    return this.deadline - this.config.finalizationMs;
  }
  evaluationDeadline(outerDeadline: number) {
    this.evaluationStarted ??= this.clock();
    return Math.min(
      outerDeadline,
      this.workDeadline,
      this.evaluationStarted + this.config.evaluationMs,
    );
  }
  claimBatch(maximum: number): boolean {
    if (this.clock() >= this.workDeadline || this.batches >= maximum) {
      this.denied.push("evaluation_budget");
      return false;
    }
    this.batches++;
    return true;
  }
  admitDeepening(
    key: string,
    reason: DeepeningReason,
    eligible: boolean,
  ): boolean {
    if (this.deepened.has(key)) {
      this.denied.push("duplicate_deepening");
      return false;
    }
    const reasons: DeepeningReason[] = [
      "boundary_tie",
      "relevant_conflict",
      "missing_decisive_fact",
      "explicit_comparison",
    ];
    if (!eligible || !reasons.includes(reason)) {
      this.denied.push("unjustified_deepening");
      return false;
    }
    this.deepeningStarted ??= this.clock();
    if (
      this.deepened.size >= this.config.maxDeepened ||
      this.clock() >=
        Math.min(
          this.workDeadline,
          this.deepeningStarted + this.config.deepeningMs,
        )
    ) {
      this.denied.push("deepening_budget");
      return false;
    }
    this.deepened.set(key, reason);
    return true;
  }
  deepeningDeadline(outerDeadline: number) {
    return Math.min(
      outerDeadline,
      this.workDeadline,
      (this.deepeningStarted ?? this.clock()) + this.config.deepeningMs,
    );
  }
  recordDeepening(
    key: string,
    result:
      | "available"
      | "absent"
      | "timeout"
      | "version_mismatch"
      | "oversized"
      | "failed",
  ) {
    if (!this.deepened.has(key)) {
      throw new Error("Approfondissement non admis.");
    }
    this.results.set(key, result);
  }
  snapshot() {
    return {
      config: { ...this.config },
      elapsedMs: Math.max(0, Math.round(this.clock() - this.started)),
      evaluationCalls: this.batches,
      deepened: this.deepened.size,
      deepenings: [...this.deepened].map(([key, reason]) => ({
        key,
        reason,
        result: this.results.get(key) ?? "pending",
      })),
      denied: [...this.denied],
    };
  }
}
