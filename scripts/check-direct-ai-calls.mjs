#!/usr/bin/env node
/**
 * ai-gateway-check v3 — no new direct LLM calls. Zero dependencies (plain Node >= 18, git).
 *
 * Canonical copy: aqueducts-ai/threefold `scripts/check-direct-ai-calls.mjs`. Every aqueducts-ai repo
 * vendors this exact file; change it there and roll the new version out to all repos together.
 *
 * Every LLM call goes through the Vercel AI Gateway with a per-feature key
 * (`<FEATURE>_AI_GATEWAY_API_KEY`, e.g. LOOP_REVIEW_AI_GATEWAY_API_KEY) so cost and usage are
 * measurable per feature. Rule + how to migrate: `.claude/rules/ai-gateway.md`.
 *
 * Signals, counted per file (TS/JS and Python):
 *   provider-sdk   a provider SDK import (openai, @anthropic-ai/sdk, @ai-sdk/openai|anthropic|google, @google/genai,
 *                  anthropic, google.generativeai, litellm, …). Not counted in a file that points the SDK at the
 *                  gateway (`ai-gateway.vercel.sh`), which is the supported way to use the gateway from Python.
 *   provider-host  a provider API hostname (api.openai.com, api.anthropic.com, generativelanguage.googleapis.com, …)
 *   provider-key   a provider key env var (OPENAI_*_API_KEY, ANTHROPIC_*, GEMINI_*, GOOGLE_GENERATIVE_AI_*, …)
 *   shared-gw-key  the shared `AI_GATEWAY_API_KEY`: spend cannot be split per feature
 *
 * Existing usage is grandfathered in `scripts/check-direct-ai-calls.baseline.json` (the migration map, one entry
 * per file with a `disposition`). The check fails when a file NOT in the baseline has any signal, or a baselined
 * file has MORE of a signal than its baseline. Repo-specific paths to skip go in the baseline's `$ignore`
 * (array of regexes matched against repo-relative paths).
 *
 * Inline exception (visible in review), on the line BEFORE the hit:
 *   // ai-gateway-allow: <signal>  reason: <why a direct call is unavoidable>     (or `#` in Python)
 *
 * Usage:
 *   node scripts/check-direct-ai-calls.mjs            # check (CI / pre-commit)
 *   node scripts/check-direct-ai-calls.mjs --update   # ratchet the baseline down after a migration (never adds)
 *   node scripts/check-direct-ai-calls.mjs --report   # print the migration map grouped by disposition
 *   node scripts/check-direct-ai-calls.mjs --self-test   # run the built-in OpenAI/Anthropic fixtures (CI runs it first)
 *   node scripts/check-direct-ai-calls.mjs --base <file>  # CI on PRs: also fail if the baseline grew vs the base branch's copy
 *   node scripts/check-direct-ai-calls.mjs --init     # (re)generate the baseline; only when adopting the check
 *
 * Exit code 0 = clean, 1 = violations.
 */

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync, writeFileSync } from "node:fs";
import { join } from "node:path";

const ROOT = process.cwd();
const BASELINE_REL = "scripts/check-direct-ai-calls.baseline.json";
const BASELINE_PATH = join(ROOT, BASELINE_REL);
const SELF = new Set(["scripts/check-direct-ai-calls.mjs", "scripts/check-direct-ai-calls.ts", BASELINE_REL]);

const SIGNALS = ["provider-sdk", "provider-host", "provider-key", "shared-gw-key"];

const JS_PKGS =
  "openai|@anthropic-ai/[a-z-]+|@ai-sdk/(?:openai|anthropic|google|google-vertex|azure|amazon-bedrock|groq|mistral|cohere|xai|deepseek|perplexity|togetherai|fireworks|cerebras)|@google/generative-ai|@google/genai|@google-cloud/vertexai|groq-sdk|cohere-ai|@mistralai/mistralai|@aws-sdk/client-bedrock-runtime|replicate|@langchain/(?:openai|anthropic|google-genai)";
const PY_PKGS =
  "openai|anthropic|google\\.generativeai|google\\.genai|vertexai|groq|cohere|mistralai|litellm|replicate|langchain_openai|langchain_anthropic|langchain_google_genai";

const SDK_JS = new RegExp(`(?:from\\s*|import\\s*\\(\\s*|require\\(\\s*|import\\s+)['"](?:${JS_PKGS})(?:/[^'"]*)?['"]`);
const SDK_PY = new RegExp(`^\\s*(?:(?:from|import)\\s+(?:${PY_PKGS})\\b|from\\s+google\\s+import\\s+(?:genai|generativeai)\\b)`);

const PATTERNS = {
  "provider-host":
    /(?:api\.openai\.com|api\.anthropic\.com|generativelanguage\.googleapis\.com|[a-z0-9-]*aiplatform\.googleapis\.com|api\.groq\.com|openrouter\.ai\/api|api\.x\.ai|api\.mistral\.ai|api\.cohere\.(?:ai|com)|api\.together\.xyz|api\.deepseek\.com|api\.perplexity\.ai)/,
  "provider-key":
    /\b(?:OPENAI|ANTHROPIC|GEMINI|GOOGLE_GENERATIVE_AI|GOOGLE_AI|GROQ|MISTRAL|COHERE|XAI|PERPLEXITY|DEEPSEEK|OPENROUTER|TOGETHER)_(?:[A-Z_]*API_KEY|[A-Z_]*AUTH_TOKEN|[A-Z_]*BASE_URL)\b/,
  "shared-gw-key": /(?<![A-Z_])AI_GATEWAY_API_KEY\b/,
};

const DEFAULT_IGNORE = [
  /(^|\/)node_modules\//,
  /(^|\/)\.next\//,
  /^(dist|build|out|coverage|vendor)\//,
  /(^|\/)\.?venv\//,
  /^docs\//,
  /^\.github\//,
  /^\.claude\//,
  /(^|\/)__mocks__\//,
  /\.(test|spec)\.[cm]?[jt]sx?$/,
  /(^|\/)(test_[^/]*|[^/]*_test|conftest)\.py$/,
  /\.min\.js$/,
];
const CODE_FILE = /\.(?:ts|tsx|js|jsx|mjs|cjs|py)$/;
const GATEWAY_HOST = /ai-gateway\.vercel\.sh/;
const ALLOW_RE = /ai-gateway-allow:\s*([a-z-]+)\s+reason:\s*\S+/;

function readBaselineRaw() {
  if (!existsSync(BASELINE_PATH)) return {};
  return JSON.parse(readFileSync(BASELINE_PATH, "utf8"));
}

function loadBaseline() {
  const raw = readBaselineRaw();
  const entries = {};
  for (const [k, v] of Object.entries(raw)) if (!k.startsWith("$")) entries[k] = v;
  const ignore = (raw.$ignore ?? []).map((s) => new RegExp(s));
  return { raw, entries, ignore };
}

function listFiles(ignore) {
  const out = execFileSync("git", ["ls-files", "-z", "--cached", "--others", "--exclude-standard"], {
    cwd: ROOT,
    maxBuffer: 256 * 1024 * 1024,
  }).toString("utf8");
  return out
    .split("\0")
    .filter(Boolean)
    .filter((f) => CODE_FILE.test(f) && !SELF.has(f))
    .filter((f) => !DEFAULT_IGNORE.some((re) => re.test(f)) && !ignore.some((re) => re.test(f)))
    .filter((f) => existsSync(join(ROOT, f)));
}

const isComment = (t, py) => (py ? t.startsWith("#") : t.startsWith("//") || t.startsWith("*") || t.startsWith("/*"));

/** Counts signals in one file's text. Exported via --self-test fixtures below. */
function scanText(text, py) {
  const sdk = py ? SDK_PY : SDK_JS;
  const lines = text.split("\n");
  // Only real code may opt a file into "SDK pointed at the gateway"; a comment mentioning the URL does not.
  const viaGateway = lines.some((l) => !isComment(l.trim(), py) && GATEWAY_HOST.test(l));
  const counts = {};
  lines.forEach((line, i) => {
    if (isComment(line.trim(), py)) return;
    const allow = i > 0 ? ALLOW_RE.exec(lines[i - 1]) : null;
    for (const signal of SIGNALS) {
      const hit = signal === "provider-sdk" ? !viaGateway && sdk.test(line) : PATTERNS[signal].test(line);
      if (!hit || (allow && allow[1] === signal)) continue;
      counts[signal] = (counts[signal] ?? 0) + 1;
    }
  });
  return counts;
}

function scanFile(file) {
  return scanText(readFileSync(join(ROOT, file), "utf8"), file.endsWith(".py"));
}

/**
 * Built-in fixtures, run in CI before the scan (`--self-test`), so a regex change can never silently
 * stop catching OpenAI or Anthropic. [name, code, isPython, expected signals (exact)].
 */
const FIXTURES = [
  // OpenAI, TypeScript/JavaScript
  ["openai default import", 'import OpenAI from "openai";', false, ["provider-sdk"]],
  ["openai named import", "import { OpenAI } from 'openai';", false, ["provider-sdk"]],
  ["openai subpath import", 'import { toFile } from "openai/uploads";', false, ["provider-sdk"]],
  ["openai require", 'const OpenAI = require("openai");', false, ["provider-sdk"]],
  ["openai dynamic import", 'const { default: OpenAI } = await import("openai");', false, ["provider-sdk"]],
  ["@ai-sdk/openai", 'import { openai } from "@ai-sdk/openai";', false, ["provider-sdk"]],
  ["openai key env", "const key = process.env.OPENAI_API_KEY;", false, ["provider-key"]],
  ["openai custom key env", "const key = process.env.OPENAI_KB_API_KEY;", false, ["provider-key"]],
  ["openai base url env", "baseURL: process.env.OPENAI_BASE_URL,", false, ["provider-key"]],
  ["openai raw fetch", 'await fetch("https://api.openai.com/v1/chat/completions", init);', false, ["provider-host"]],
  // Anthropic, TypeScript/JavaScript
  ["anthropic sdk import", 'import Anthropic from "@anthropic-ai/sdk";', false, ["provider-sdk"]],
  ["anthropic sdk subpath", 'import type { MessageParam } from "@anthropic-ai/sdk/resources";', false, ["provider-sdk"]],
  ["anthropic other pkg", 'import { query } from "@anthropic-ai/claude-agent-sdk";', false, ["provider-sdk"]],
  ["anthropic require", 'const Anthropic = require("@anthropic-ai/sdk");', false, ["provider-sdk"]],
  ["@ai-sdk/anthropic", 'import { createAnthropic } from "@ai-sdk/anthropic";', false, ["provider-sdk"]],
  ["anthropic key env", "apiKey: process.env.ANTHROPIC_API_KEY,", false, ["provider-key"]],
  ["anthropic auth token env", "authToken: process.env.ANTHROPIC_AUTH_TOKEN,", false, ["provider-key"]],
  ["anthropic raw fetch", 'await fetch("https://api.anthropic.com/v1/messages", init);', false, ["provider-host"]],
  // Python
  ["py import openai", "import openai", true, ["provider-sdk"]],
  ["py from openai", "from openai import OpenAI", true, ["provider-sdk"]],
  ["py import anthropic", "import anthropic", true, ["provider-sdk"]],
  ["py from anthropic", "from anthropic import Anthropic, AsyncAnthropic", true, ["provider-sdk"]],
  ["py litellm", "from litellm import completion", true, ["provider-sdk"]],
  ["py openai key", 'key = os.environ["OPENAI_API_KEY"]', true, ["provider-key"]],
  ["py anthropic key", 'key = os.getenv("ANTHROPIC_API_KEY")', true, ["provider-key"]],
  ["py anthropic host", 'requests.post("https://api.anthropic.com/v1/messages")', true, ["provider-host"]],
  // Shared gateway key
  ["shared gateway key", "createGateway({ apiKey: process.env.AI_GATEWAY_API_KEY })", false, ["shared-gw-key"]],
  // Allowed
  ["per-feature gateway key", "createGateway({ apiKey: process.env.LOOP_REVIEW_AI_GATEWAY_API_KEY })", false, []],
  ["ai package", 'import { createGateway, generateText } from "ai";', false, []],
  ["comment only", "// we used to call api.openai.com with OPENAI_API_KEY", false, []],
  ["py comment only", "# import anthropic", true, []],
  ["look-alike package", 'import { encode } from "openai-tokenizer-lite";', false, []],
  [
    "openai sdk via gateway",
    'import OpenAI from "openai";\nconst c = new OpenAI({ apiKey: process.env.VOICE_EVALS_AI_GATEWAY_API_KEY, baseURL: "https://ai-gateway.vercel.sh/v1" });',
    false,
    [],
  ],
  [
    "py openai via gateway",
    'from openai import OpenAI\nclient = OpenAI(api_key=os.environ["CALL_TRANSCRIBE_AI_GATEWAY_API_KEY"], base_url="https://ai-gateway.vercel.sh/v1")',
    true,
    [],
  ],
  ["gateway url only in a comment", '// see https://ai-gateway.vercel.sh/v1\nimport Anthropic from "@anthropic-ai/sdk";', false, ["provider-sdk"]],
  ["allow comment", '// ai-gateway-allow: provider-sdk  reason: key-rotation tool\nimport OpenAI from "openai";', false, []],
];

function selfTest() {
  const failures = [];
  for (const [name, code, py, expected] of FIXTURES) {
    const got = Object.keys(scanText(code, py)).sort();
    const want = [...expected].sort();
    if (got.join(",") !== want.join(",")) failures.push(`${name}: expected [${want}] got [${got}]`);
  }
  if (failures.length) {
    console.error(`❌ Scanner self-test failed:\n  ${failures.join("\n  ")}`);
    return 1;
  }
  console.log(`✓ Scanner self-test passed (${FIXTURES.length} OpenAI / Anthropic / gateway cases).`);
  return 0;
}

const NOTE =
  "Grandfathered direct LLM usage = the migration map. NEVER add entries or raise counts: use a per-feature AI Gateway key (.claude/rules/ai-gateway.md). `--update` only lowers counts / removes entries. disposition: migrate | keep: <reason>. $ignore: extra path regexes to skip.";

function writeBaseline(raw, entries) {
  const out = { $note: NOTE };
  if (raw.$ignore?.length) out.$ignore = raw.$ignore;
  for (const k of Object.keys(entries).sort()) out[k] = entries[k];
  writeFileSync(BASELINE_PATH, `${JSON.stringify(out, null, 2)}\n`);
}

const fmt = (c) =>
  SIGNALS.filter((s) => c[s])
    .map((s) => `${s}×${c[s]}`)
    .join(", ");

/** Entries/counts/$ignore patterns present in `head` but not allowed by `base` (the base branch's baseline). */
function baselineGrowth(base, head) {
  const problems = [];
  const baseIgnore = new Set(base.$ignore ?? []);
  for (const re of head.$ignore ?? []) if (!baseIgnore.has(re)) problems.push(`$ignore pattern added: ${re}`);
  for (const [file, e] of Object.entries(head)) {
    if (file.startsWith("$")) continue;
    const b = base[file];
    if (!b) {
      problems.push(`${file}: added to the baseline`);
      continue;
    }
    for (const s of SIGNALS) {
      if ((e.counts?.[s] ?? 0) > (b.counts?.[s] ?? 0)) problems.push(`${file}: ${s} raised from ${b.counts?.[s] ?? 0} to ${e.counts[s]}`);
    }
  }
  return problems;
}

function ruleLocation() {
  return existsSync(join(ROOT, ".claude/rules/ai-gateway.md")) ? ".claude/rules/ai-gateway.md" : "the AI Gateway section of CLAUDE.md";
}

function main() {
  const argv = process.argv.slice(2);
  const args = new Set(argv);
  const basePath = args.has("--base") ? argv[argv.indexOf("--base") + 1] : null;
  if (args.has("--self-test")) return selfTest();
  const { raw, entries, ignore } = loadBaseline();
  const found = new Map();
  for (const f of listFiles(ignore)) {
    const c = scanFile(f);
    if (Object.keys(c).length) found.set(f, c);
  }

  if (args.has("--init")) {
    const next = {};
    for (const [f, counts] of found) next[f] = { ...entries[f], counts, disposition: entries[f]?.disposition ?? "migrate" };
    writeBaseline(raw, next);
    console.log(`Baseline written: ${Object.keys(next).length} file(s).`);
    return 0;
  }

  if (args.has("--report")) {
    const groups = new Map();
    for (const [f, e] of Object.entries(entries)) {
      groups.set(e.disposition, [...(groups.get(e.disposition) ?? []), `${f}  (${fmt(e.counts)})`]);
    }
    if (!groups.size) console.log("No legacy direct LLM usage.");
    for (const [k, v] of [...groups].sort()) {
      console.log(`\n## ${k} (${v.length})`);
      for (const line of v.sort()) console.log(`  ${line}`);
    }
    return 0;
  }

  const violations = [];
  const shrunk = [];
  if (basePath && existsSync(basePath)) {
    for (const p of baselineGrowth(JSON.parse(readFileSync(basePath, "utf8")), raw)) violations.push(`baseline grew: ${p}`);
  }
  for (const [file, counts] of found) {
    const base = entries[file];
    if (!base) {
      violations.push(`${file}: new direct LLM usage (${fmt(counts)})`);
      continue;
    }
    for (const s of SIGNALS) {
      if ((counts[s] ?? 0) > (base.counts[s] ?? 0)) violations.push(`${file}: ${s} grew from ${base.counts[s] ?? 0} to ${counts[s]}`);
    }
  }
  for (const [file, base] of Object.entries(entries)) {
    const now = found.get(file) ?? {};
    if (SIGNALS.some((s) => (now[s] ?? 0) < (base.counts[s] ?? 0))) shrunk.push(file);
  }

  if (args.has("--update")) {
    if (violations.length) {
      console.error(`Refusing to update: fix the violations first.\n${violations.join("\n")}`);
      return 1;
    }
    for (const f of shrunk) {
      const now = found.get(f);
      if (!now) delete entries[f];
      else entries[f].counts = now;
    }
    writeBaseline(raw, entries);
    console.log(`Baseline ratcheted: ${shrunk.length} file(s) lowered/removed.`);
    return 0;
  }

  if (shrunk.length) {
    console.log(`ℹ️  ${shrunk.length} baselined file(s) improved; run \`node scripts/check-direct-ai-calls.mjs --update\` to lock it in.`);
  }
  if (violations.length) {
    console.error("\n❌ Direct LLM calls are not allowed (no new ones, none added to legacy files):\n");
    for (const v of violations) console.error(`  - ${v}`);
    console.error(
      "\nRoute the call through the Vercel AI Gateway with a per-feature key (<FEATURE>_AI_GATEWAY_API_KEY)." +
        `\nSee ${ruleLocation()}. Never grow the baseline to get green. Unavoidable exception: \`ai-gateway-allow: <signal>  reason: …\` comment on the line before.\n`
    );
    return 1;
  }
  console.log(`✓ No new direct LLM calls (${Object.keys(entries).length} legacy file(s) still to migrate).`);
  return 0;
}

process.exit(main());
