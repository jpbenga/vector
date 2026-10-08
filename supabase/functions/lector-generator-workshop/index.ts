import { generatorHandler } from "../_shared/generator/handler.ts";
Deno.serve(generatorHandler({ workshop: true }));
