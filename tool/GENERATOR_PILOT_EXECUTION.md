# Isolated authorized pilot — 13 October 2026

This validation branch preserves application code at commit 47bd623. Only the dependency closure of the prepared evaluation scripts, public archived fixtures, tests, and validation workflow are included.

The existing `deploy-supabase.yml` dispatch entry point is replaced **on this branch only** by a workflow that contains no deployment, SQL, Supabase key, or sports-provider step. This reuses the already registered manual GitHub dispatch entry point; it does not change the default or demo branch.

Launch only on `codex/generator-pilot-20261013`, `function=lector-generator-diagnostic`, and `diagnostic_since=authorized-2-calls-0.05-usd-2026-10-13`.

Hard limits: Luna, two structured evaluation calls, USD 0.05 conservative admission envelope, published readings only. The operator authorization is the user's explicit “Lance le” following the concrete pilot preparation. No automated paid retry, follow-up, or resume. Run attempts after the initial attempt are skipped.

The model secret stays in GitHub Actions. The output/read/write scopes are aligned so checkpoints and receipts are retained and can be read without another model call. Upload runs even when the pilot fails. Human sporting review remains pending.
