# AI Gateway: no direct LLM calls (company-wide)

Every LLM call (chat, vision, embeddings, transcription, reranking) goes through the **Vercel AI
Gateway** with a **dedicated key per feature**, so cost and usage are measurable per feature in the
gateway dashboard. Direct provider calls are legacy and are being migrated. This rule is the same in
every aqueducts-ai repo.

## Never (in new code)

- Call a provider directly: provider SDKs (`openai`, `@anthropic-ai/sdk`, `@ai-sdk/openai|anthropic|google`,
  `@google/genai`; Python `openai`, `anthropic`, `google.genai`, `litellm`, …) unless pointed at the
  gateway, or provider hosts (`api.openai.com`, `api.anthropic.com`, `generativelanguage.googleapis.com`, …).
- Read provider keys: `OPENAI_*`, `ANTHROPIC_*`, `GEMINI_*`, `GOOGLE_GENERATIVE_AI_*` and similar.
- Read the shared `AI_GATEWAY_API_KEY`: spend would land in the shared bucket.

## Always

- One key per feature: `<FEATURE>_AI_GATEWAY_API_KEY` (e.g. `LOOP_REVIEW_AI_GATEWAY_API_KEY`,
  `VOICE_EVALS_AI_GATEWAY_API_KEY`, `CALL_TRANSCRIBE_AI_GATEWAY_API_KEY`). A new feature gets a new
  key; never reuse another feature's. Ask the user to create it (Vercel → AI Gateway → API keys) and
  provision it; never invent or paste a key.
- TypeScript: `createGateway({ apiKey: process.env.<FEATURE>_AI_GATEWAY_API_KEY })` from `ai`, with
  gateway model ids (`anthropic/claude-sonnet-5.5`, `openai/gpt-6-luna`).
- Python / OpenAI-compatible clients: the OpenAI SDK with `base_url="https://ai-gateway.vercel.sh/v1"`
  and the feature key. A file that references `ai-gateway.vercel.sh` may import the SDK.
- Don't pick a model the provider has deprecated; check its deprecation page first.

## Enforcement

`scripts/check-direct-ai-calls.mjs` runs in CI (`.github/workflows/ai-gateway-check.yml`). It fails
when a file outside the baseline has a direct-call signal, or a baselined file gains one.

- **Baseline = migration map:** `scripts/check-direct-ai-calls.baseline.json` lists every legacy file,
  its signal counts and a `disposition`. `node scripts/check-direct-ai-calls.mjs --report` prints it.
- **Never add entries, raise counts or add `$ignore` patterns** to get green. Migrate the call instead.
  On PRs, CI compares the baseline with the base branch and fails if it grew.
- After migrating a file: `node scripts/check-direct-ai-calls.mjs --update` (only lowers/removes) and
  commit the baseline with the migration.
- Rare, reviewed exception: `ai-gateway-allow: <signal>  reason: <why>` in a comment on the line
  before the hit. Signals: `provider-sdk`, `provider-host`, `provider-key`, `shared-gw-key`.
- The scanner is vendored; its canonical copy is in `aqueducts-ai/threefold`. Don't edit it locally.
