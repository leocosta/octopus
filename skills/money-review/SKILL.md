---
name: money-review
description: >
  Pre-merge audit of money-touching code. Given a branch or PR, inspects
  numeric types, rounding, tests for non-round cents, env-var consistency,
  payment idempotency, webhook signature verification, and fee disclosure
  coupling. Produces a severity-tiered report (block / warn / info).
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

**Arguments / options:**

- `ref` (optional) — PR (`#123`/URL), branch name, or commit SHA.
  Default: current HEAD vs its upstream.
- `--base=<branch>` — base for the diff. Default: `main`.
- `--write-report` — also save `docs/reviews/YYYY-MM-DD-money-<slug>.md`.
- `--only=<list>` — comma-separated subset of inspection families:
  `types,rounding,tests,env,idempotency,webhook,disclosure`. Default: all.

## File Discovery

A file is "money-touched" if any of the following match in the diff of
`<ref>` against `--base`:

1. **Filename tokens** — path contains any of: `billing`, `payment`,
   `charge`, `cobran`, `split`, `invoice`, `subscription`, `asaas`,
   `stripe`, `pix`, `webhook`, `refund`, `reembolso`, `tax`, `taxa`,
   `fee`.
2. **Content regex (case-insensitive)** on the added/removed lines:
   - `\b(PERCENT|PERCENTAGE|RATE|FEE)[_A-Z]*\s*=`
   - `\bdecimal\b` in `*.cs` files near `cents|centavos|amount|valor`
   - `asaas|stripe|mercadopago`
   - `webhook` combined with `signature|hmac|signing`
3. **Repo overrides** — the file cascade applies (first match wins):
   - `docs/money-review/patterns.md` (canonical)
   - `docs/MONEY_REVIEW_PATTERNS.md` (uppercase compat)
   - `skills/money-review/templates/patterns.md` (embedded default)

   The repo override **appends** tokens/patterns; it does not replace the
   defaults. Same rule for `providers.md`.

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

**Default (chat):** one markdown block with three headings, each listing
findings for that severity with the format
`Tn **family**: <description> [file:line]`.

```
## 🚫 Block (N)
- T4 **env**: `ASAAS_SPLIT_PERCENT_BOLETO` added to `api/.env.sandbox`
  but missing in `api/.env`. `api/.env.sandbox:42`

## ⚠ Warn (N)
- T1 **types**: `double Fee` — prefer `decimal`.
  `api/src/.../FeeCalculator.cs:17`

## ℹ Info (N)
- T3 **tests**: no test file touched for
  `api/src/.../SplitCalculator.cs`.
```

Always end with: `money-review: N block, N warn, N info`.

**With `--write-report`:** same content written to
`docs/reviews/YYYY-MM-DD-money-<slug>.md` with a frontmatter block:

```yaml
---
ref: feat/billing-v2
base: main
generated_by: octopus:money-review
generated_at: 2026-04-19
summary: "0 block, 3 warn, 1 info"
---
```

The slug is derived from the branch name or PR number: lowercase ASCII,
non-alphanumeric runs collapsed to `-`, max 40 chars.

## Errors

- **Not in a git repo** → abort.
- **Base branch not found** → abort with "run `git fetch` or pass
  `--base=<branch>`".
- **No money-touched files** → print "no money-related changes detected"
  and exit 0 with `money-review: 0 block, 0 warn, 0 info`.
- **Override file malformed** → print a warning, ignore the override,
  continue with defaults.
- **Unrecognized `--only` family** → abort, list valid families.

## Composition

- Run `security-scan` first (secrets/injection) and `money-review` after
  (money-logic). Both findings together form the pre-merge safety net.
- Output is plain markdown designed to paste into a PR comment as-is.
