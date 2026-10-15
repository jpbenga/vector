/** Per-request time allowances, tripled from the previous production release. */
export const generatorTimeouts = Object.freeze({
  conversationMs: 390000,
  finalizationMs: 105000,
  modelMs: 135000,
  analysisMs: 240000,
  databaseMs: 45000,
  authenticationMs: 30000,
  optionalHistoryMs: 9000,
});
