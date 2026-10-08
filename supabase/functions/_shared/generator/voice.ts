/** One minute of mono 16kHz PCM, verified on the server, bounds transcription cost. */
export function decodeVoice(value: unknown): Uint8Array {
  if (
    typeof value !== "string" || value.length > 2560064 ||
    !/^[A-Za-z0-9+/]+={0,2}$/.test(value)
  ) throw new Error("Enregistrement invalide.");
  let bytes: Uint8Array;
  try {
    bytes = Uint8Array.from(atob(value), (c) => c.charCodeAt(0));
  } catch {
    throw new Error("Enregistrement invalide.");
  }
  if (bytes.length < 3244 || bytes.length > 1920044) {
    throw new Error("La dictée doit durer entre 0,1 et 60 secondes.");
  }
  const view = new DataView(bytes.buffer);
  const text = (offset: number, length: number) =>
    new TextDecoder().decode(bytes.slice(offset, offset + length));
  if (
    text(0, 4) !== "RIFF" || text(8, 4) !== "WAVE" || text(12, 4) !== "fmt " ||
    text(36, 4) !== "data" || view.getUint32(4, true) !== bytes.length - 8 ||
    view.getUint32(16, true) !== 16 || view.getUint16(20, true) !== 1 ||
    view.getUint16(22, true) !== 1 || view.getUint32(24, true) !== 16000 ||
    view.getUint32(28, true) !== 32000 || view.getUint16(32, true) !== 2 ||
    view.getUint16(34, true) !== 16 ||
    view.getUint32(40, true) !== bytes.length - 44 || (bytes.length - 44) % 2
  ) throw new Error("Format de dictée invalide.");
  return bytes;
}
export async function transcribe(
  audio: Uint8Array,
  options: { key: string; fetcher?: typeof fetch },
): Promise<string> {
  const form = new FormData();
  form.append(
    "file",
    new Blob([audio as Uint8Array<ArrayBuffer>], { type: "audio/wav" }),
    "dictee.wav",
  );
  form.append("model", "whisper-1");
  form.append("language", "fr");
  form.append("response_format", "json");
  const response = await (options.fetcher ?? fetch)(
    "https://api.openai.com/v1/audio/transcriptions",
    {
      method: "POST",
      redirect: "error",
      signal: AbortSignal.timeout(45000),
      headers: { authorization: `Bearer ${options.key}` },
      body: form,
    },
  );
  if (!response.ok) {
    throw new Error(
      "La transcription est momentanément indisponible. Réessayez ou utilisez le clavier.",
    );
  }
  const body = await response.json();
  const text = String(body.text ?? "").trim();
  if (!text || text.length > 2000) {
    throw new Error(
      "La dictée n’a pas pu être transcrite. Utilisez un message plus court.",
    );
  }
  return text;
}
