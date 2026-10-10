/** Carry the actual failing operation, independently of later progress writes. */
export class GeneratorFailure extends Error {
  constructor(error: unknown, readonly stage: string) {
    super(error instanceof Error ? error.message : "La préparation a échoué.", {
      cause: error,
    });
    this.name = error instanceof Error ? error.name : "Error";
  }
}

export function generatorTimeoutMessage(stage: string) {
  const operation = stage.startsWith("conversation")
    ? "La préparation de la réponse IA a dépassé le délai."
    : stage === "interpret"
    ? "L’interprétation a pris trop de temps."
    : "La récupération des données a pris trop de temps.";
  return `${operation} Votre conversation est conservée ; vous pouvez réessayer.`;
}
