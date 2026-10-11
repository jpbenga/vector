import { type Json, obj } from "./contracts.ts";
import { generatorTimeoutMessage } from "./failures.ts";

export function canReadTurnResponse(
  session: Json | undefined,
  now = new Date(),
) {
  if (!session) return false;
  const expiresAt = session.mode === "legacy"
    ? Date.parse(String(session.updated_at)) + 24 * 60 * 60 * 1000
    : Date.parse(String(session.expires_at));
  return Number.isFinite(expiresAt) && expiresAt > now.getTime();
}

/** The caller must select this row by authenticated user, conversation and turn. */
export function turnStatus(row: Json | undefined, workshop: boolean): Json {
  const usage = obj(row?.usage);
  const status = row?.status ?? "starting";
  return {
    turn: {
      status,
      phase: usage.phase ?? "interpret",
      ...(workshop
        ? {
          steps: usage.steps ?? [],
          context: usage.context ?? null,
          summary: usage.summary ?? null,
        }
        : {}),
      ...(status === "failed"
        ? {
          error: ["TimeoutError", "AbortError"].includes(
              String(usage.failure_name),
            )
            ? generatorTimeoutMessage(String(usage.failure_stage ?? ""))
            : "Cette préparation s’est arrêtée côté serveur. Votre conversation est conservée.",
        }
        : {}),
    },
    ...(status === "complete" && row?.response ? { state: row.response } : {}),
  };
}
