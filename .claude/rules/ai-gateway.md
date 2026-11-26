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

- One key per feature, named `<FEATURE>_AI_GATEWAY_API_KEY` in SCREAMING_SNAKE_CASE (e.g.
  `LOOP_REVIEW_AI_GATEWAY_API_KEY`, `VOICE_EVALS_AI_GATEWAY_API_KEY`, `CALL_TRANSCRIBE_AI_GATEWAY_API_KEY`).
  `<FEATURE>` is the product feature that spends, so the gateway dashboard shows what spent the money:
  never a provider or model (`OPENAI_…`, `CLAUDE_…`: the model can change, the key stays) and never a
  catch-all (`AI_`, `LLM_`, `SHARED_`, `DEFAULT_`, `COMMON_`). A new feature gets a new key; never reuse
  another feature's, and never invent or paste a key.
- Provisioning (AI Gateway key with a budget, Vercel env var, Google Secret Manager) has one source of
  truth: the `ai-gateway-key` skill in `aqueducts-ai/threefold`. Its script
  `scripts/secret-rotation/create-ai-gateway-key.mjs` does all of it without anyone seeing the value; ask
  the user to run it (or follow the skill's manual steps). Never create a key with a tool that returns the
  secret into the conversation.
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
  On PRs, CI compares the baseline with the base branch and fails if it grew, and also runs the
  base branch's scanner, so editing the scanner in a PR does not weaken the check.
- After migrating a file: `node scripts/check-direct-ai-calls.mjs --update` (only lowers/removes) and
  commit the baseline with the migration.
- Rare, reviewed exception: `ai-gateway-allow: <signal>  reason: <why>` in a comment on the line
  before the hit. Signals: `provider-sdk`, `provider-host`, `provider-key`, `shared-gw-key`.
- The scanner is vendored; its canonical copy is in `aqueducts-ai/threefold`. Don't edit it locally.
