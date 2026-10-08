import { obj } from "./contracts.ts";

export const comparisonModels = ["gpt-6.1-sol", "gpt-6-luna"] as const;
export const modelRegistry: Record<
  string,
  { input: number; cached: number; output: number; reasoning: boolean }
> = {
  "gpt-6.1-sol": { input: 2, cached: .1, output: 10, reasoning: true },
  "gpt-6-luna": { input: .1, cached: .01, output: .5, reasoning: true },
  "gpt-4.1-mini": { input: .4, cached: .1, output: 1.6, reasoning: false },
  "gpt-4.1-mini-2025-04-14": {
    input: .4,
    cached: .1,
    output: 1.6,
    reasoning: false,
  },
  "gpt-4.1-nano": { input: .1, cached: .025, output: .4, reasoning: false },
  "gpt-4.1-nano-2025-04-14": {
    input: .1,
    cached: .025,
    output: .4,
    reasoning: false,
  },
};
export interface ModelReceipt {
  stage: "interpret" | "review";
  requestedModel: string;
  returnedModel: string | null;
  responseId: string | null;
  status: string;
  elapsedMs: number;
  inputTokens: number | null;
  cachedInputTokens: number | null;
  outputTokens: number | null;
  reasoningTokens: number | null;
  /** Standard USD estimate, not billing. Cache-write details may be absent. */
  estimatedUsd: { minimum: number; maximum: number } | null;
  pricingDate: "2026-10-08";
  usage: unknown;
}
export interface ModelOptions {
  key: string;
  model: string;
  fetcher?: typeof fetch;
  onReceipt?: (receipt: ModelReceipt) => void;
}
export function receiptFor(
  model: string,
  stage: ModelReceipt["stage"],
  body: unknown,
  elapsedMs: number,
  status?: string,
): ModelReceipt {
  const b = obj(body), u = obj(b.usage), details = obj(u.input_tokens_details);
  const count = (v: unknown) =>
    typeof v === "number" && Number.isFinite(v) && v >= 0 ? v : null;
  const input = count(u.input_tokens), output = count(u.output_tokens);
  const cached = count(details.cached_tokens), price = modelRegistry[model];
  const estimate = input !== null && output !== null && price
    ? (() => {
      const read = Math.min(input, cached ?? 0), uncached = input - read;
      const minimum =
        (uncached * price.input + read * price.cached + output * price.output) /
        1e6;
      // GPT-6 cache writes cost 1.25x input. Without a write-token count, retain
      // a range rather than claiming an exact bill. No Fast/regional/tools used.
      const maximum = minimum +
        (price.reasoning ? uncached * price.input * .25 / 1e6 : 0);
      return { minimum, maximum };
    })()
    : null;
  return {
    stage,
    requestedModel: model,
    returnedModel: typeof b.model === "string" ? b.model : null,
    responseId: typeof b.id === "string" ? b.id : null,
    status: status ?? String(b.status ?? "unknown"),
    elapsedMs: Math.round(elapsedMs),
    inputTokens: input,
    cachedInputTokens: cached,
    outputTokens: output,
    reasoningTokens: count(obj(u.output_tokens_details).reasoning_tokens),
    estimatedUsd: estimate,
    pricingDate: "2026-10-08",
    usage: b.usage ?? null,
  };
}
/** One bounded paid call. The caller's idempotent reservation owns retries. */
export async function structuredResponse(
  input: {
    stage: ModelReceipt["stage"];
    instructions: string;
    input: unknown;
    schema: unknown;
    name: string;
  },
  options: ModelOptions,
) {
  const configuration = modelRegistry[options.model];
  if (!configuration) throw new Error("Modèle IA non autorisé.");
  const payload = {
    model: options.model,
    store: false,
    service_tier: "default",
    max_output_tokens: configuration.reasoning ? 6000 : 1800,
    ...(configuration.reasoning ? { reasoning: { effort: "low" } } : {}),
    instructions: input.instructions,
    input: JSON.stringify(input.input),
    text: {
      format: {
        type: "json_schema",
        name: input.name,
        strict: true,
        schema: input.schema,
      },
    },
  };
  const body = JSON.stringify(payload);
  if (new TextEncoder().encode(body).length > 48000) {
    throw new Error(
      "Cette demande contient trop de données pour l’analyse IA.",
    );
  }
  const started = performance.now();
  let recorded = false;
  try {
    const response = await (options.fetcher ?? fetch)(
      "https://api.openai.com/v1/responses",
      {
        method: "POST",
        redirect: "error",
        signal: AbortSignal.timeout(input.stage === "review" ? 30000 : 45000),
        headers: {
          authorization: `Bearer ${options.key}`,
          "content-type": "application/json",
        },
        body,
      },
    );
    const result = await response.json();
    const receipt = receiptFor(
      options.model,
      input.stage,
      result,
      performance.now() - started,
      response.ok ? undefined : `http_${response.status}`,
    );
    options.onReceipt?.(receipt);
    recorded = true;
    if (!response.ok) {
      throw new Error(
        `Le service IA est indisponible (HTTP ${response.status}).`,
      );
    }
    if (result.status !== "completed") {
      throw new Error(
        "La réponse IA est incomplète. Aucune composition n’a été modifiée.",
      );
    }
    const content = (Array.isArray(result.output) ? result.output : []).flatMap(
      (o: unknown) => {
        const c = obj(o).content;
        return Array.isArray(c) ? c.map(obj) : [];
      },
    );
    const text = content.filter((c: Record<string, unknown>) =>
      c.type === "output_text"
    ).map((c: Record<string, unknown>) => c.text).join("");
    if (!text) {
      throw new Error("La réponse IA ne contient pas d’analyse exploitable.");
    }
    return { value: JSON.parse(text), usage: result.usage, receipt };
  } catch (error) {
    if (!recorded) {
      options.onReceipt?.(
        receiptFor(
          options.model,
          input.stage,
          null,
          performance.now() - started,
          "failed_without_usage",
        ),
      );
    }
    throw error;
  }
}
