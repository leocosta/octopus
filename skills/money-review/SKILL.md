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
