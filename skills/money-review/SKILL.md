---
name: money-review
description: >
  Pre-merge audit of money-touching code. Given a branch or PR, inspects
  numeric types, rounding, tests for non-round cents, env-var consistency,
  payment idempotency, webhook signature verification, and fee disclosure
  coupling. Produces a severity-tiered report (block / warn / info).
triggers:
  paths: []
  keywords: ["payment", "invoice", "stripe", "billing", "subscription", "checkout", "price"]
  tools: []
pre_pass:
  file_patterns: "billing|payment|charge|cobran|split|invoice|subscription|asaas|stripe|pix|webhook|refund|reembolso|tax|taxa|fee"
  line_patterns: "PERCENT[_A-Z]*\\s*=|\\bdecimal\\b|asaas|stripe|mercadopago|webhook.*(signature|hmac)"
---

# Money-Review Protocol

## Overview

This skill audits changes that touch money-logic before merge. It resolves
the target ref, isolates the diff against a base branch, identifies
money-touched files via keyword heuristics, and runs seven inspection
families. Findings are grouped by severity.

The skill composes with `security-scan`: that one finds secrets and
generic vulnerabilities; this one finds money-logic correctness. Run both
on any billing PR.

## Invocation

```
/octopus:money-review [ref] [--base=main] [--write-report] [--only=<families>]
```

Flags `ref`, `--base`, `--only`, `--write-report` follow the shared
convention — see [`skills/_shared/audit-output-format.md`](../_shared/audit-output-format.md).

Valid `--only` families:
`types,rounding,tests,env,idempotency,webhook,disclosure`.
Report prefix: `money`.

## File Discovery

Follow the Pre-Pass protocol in `skills/_shared/audit-pre-pass.md`.
Use this skill's `pre_pass.file_patterns` and `pre_pass.line_patterns` from the frontmatter.
Proceed to inspection checks only with the scoped diff produced by Step 4.

A separate "spec set" is collected: any `docs/specs/*.md`,
`docs/research/*.md`, or `docs/roadmap.md` section touched by the same
diff. This set feeds the T7 (disclosure) inspection.

## Inspection Families

Each family produces zero or more findings. A finding has: severity, file
path, line number (when applicable), short description, and a one-line
suggested fix. Families are skippable via `--only`.

### T1 types — numeric type safety

Scan money-touched files (added/modified lines):

- C# (`*.cs`): flag `float` or `double` used for monetary fields
  (fields named like `Amount`, `Fee`, `Value`, `Price`, `Total`,
  `Percent`, `Rate`). Suggest `decimal`.
- TS/JS (`*.ts`/`*.tsx`/`*.js`): flag `number` used for currency when
  the variable name matches the same list AND there is no comment
  mentioning "cents" or "centavos" on an adjacent line. Suggest storing
  cents as integers or using a decimal library.

Severity: ⚠ Warn.

### T2 rounding — explicit rounding strategy

Scan money-touched files:

- C#: flag `Math.Round(x)` or `Math.Round(x, n)` without an explicit
  `MidpointRounding` argument. Suggest `MidpointRounding.ToEven` for
  bankers rounding (match the repo's existing choice when overrides
  say so).
- TS/JS: flag `.toFixed(n)` used on money values (lossy). Suggest an
  explicit rounding function with documented mode.
- Cross-file check: if two money-touched files use different rounding
  modes in the same diff, flag the inconsistency.

Severity: ⚠ Warn.

### T3 tests — cents coverage

For each money-touched non-test file that was modified, check whether a
corresponding test file was also modified. If yes, require that at least
one test added/modified in the diff uses a non-round cents literal —
pattern from `patterns.md` (default: `\b\d+\.(01|99|55|33|45|77)\b`).

If the non-test file was modified but no test file was touched, emit an
Info finding suggesting a test.

Severity: ⚠ Warn (test touched but no cents literal) / ℹ Info (no test
touched at all).

### T4 env — env-var consistency

Scan for newly added env var keys matching
`^[A-Z][A-Z0-9_]*_(PERCENT|PERCENTAGE|RATE|FEE)[A-Z_0-9]*`.

For each such key, resolve the repo's environment files:

- Sandbox: `api/.env.sandbox`, `.env.sandbox`, `.env.staging`,
  `apps/*/.env.sandbox` — first that exists.
- Production reference: `api/.env`, `.env.production`,
  `apps/*/.env.production`, or a deploy manifest referenced from
  `.octopus.yml` (optional override).
- Also scan `appsettings.*.json` files when present (relevant for .NET).

Block when the key exists in one environment but not the other.

Severity: 🚫 Block.

### T5 idempotency — payment-call idempotency

Scan money-touched files for outbound HTTP calls matching:

- `POST ` to a URL containing `payments`, `charges`, `subscriptions`,
  `checkout`, or `orders` on any payment provider host from
  `providers.md`.
- Any `HttpClient.PostAsync` / `fetch(..., { method: 'POST' })` with
  these URLs.

For each match, verify that the request carries one of:
- `Idempotency-Key` / `X-Idempotency-Key` header
- An `externalReference` field (Asaas convention)
- Provider-specific idempotency token from `providers.md`

Severity: ⚠ Warn when missing.

### T6 webhook — signature verification

Scan for new webhook endpoint declarations:

- C# ASP.NET: `[Route("webhook")]`, `[HttpPost("webhook/...")]`,
  or method names matching `^Handle.*Webhook.*`.
- Node/TS: `app.post('/webhook/...')`, route definitions matching
  `/webhook|/callback` pattern.

For each endpoint, require that the method body references a signature
verification helper BEFORE processing the payload. Default verification
helper names: `VerifySignature`, `verifyWebhookSignature`, `VerifyHmac`,
`verifyAsaasToken`, `verifyStripeSignature`. Overrides allowed via
`providers.md`.

Severity: 🚫 Block when a new webhook endpoint lands without a verifier.

### T7 disclosure — fee/tax disclosure coupling

Triggered when the diff either:
- Adds a new `*_PERCENT`/`*_FEE`/`*_RATE` env var, OR
- Adds/changes a rate/percentage field in a pricing / billing UI
  component (file path matches `billing|pricing|fee|taxa` in
  `apps/*/src/.../` or similar frontend path).

The skill inspects the spec set (specs/research/roadmap sections touched
by the same diff) for the tokens `disclosure`, `consent`, `consentimento`,
`aviso`, `disclaimer`, `taxa`. If none of the touched spec files mention
any of these, emit a warning: "fee change without disclosure coupling —
confirm a spec/research document addresses user-facing communication".

Severity: ⚠ Warn.

## Output

Severity headings, trailer, and `--write-report` frontmatter follow
the shared format — see
[`_shared/audit-output-format.md`](../_shared/audit-output-format.md).
Skill-specific notes:

- Finding ID prefix: `T1`–`T7`.
- Trailer: `money-review: N block, N warn, N info`.
- Report path: `docs/reviews/YYYY-MM-DD-money-<slug>.md`.

## Errors

Shared errors (not in git repo, base branch missing, no relevant
files, malformed override, unrecognized `--only`) behave per the
shared convention. Skill-specific wording:

- **No money-touched files** → `no money-related changes detected`.

## Composition

Run `security-scan` first (secrets/injection), then `money-review`
(money-logic). Both form the pre-merge safety net; output is plain
markdown designed to paste into a PR comment as-is.
