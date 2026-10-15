import { generatorHandler } from "../_shared/generator/handler.ts";
import { reservedKeepAlive } from "../_shared/generator/request_connection.ts";

const runtime = (globalThis as typeof globalThis & {
  EdgeRuntime?: { waitUntil: (task: Promise<unknown>) => void };
}).EdgeRuntime;
Deno.serve(reservedKeepAlive(
  (onReserved) => generatorHandler({ workshop: true, onReserved }),
  runtime ? (task) => runtime.waitUntil(task) : undefined,
));
