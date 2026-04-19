# Money-Review

Pre-merge audit of code that touches money. Catches the bugs generic
review misses: float for currency, inconsistent rounding, missing cents
tests, env-var drift, payment calls without idempotency, webhook
endpoints without signature verification, fee changes shipped without
disclosure.

## When to use

Before merging any PR that touches billing, payments, splits, fees,
taxes, or refunds. Runs well alongside `security-scan`.

## Enable

```yaml
# .octopus.yml
skills:
  - money-review
  - security-scan
```

Run `octopus setup`.

## Use

```
/octopus:money-review                       # current branch vs main
/octopus:money-review #123                  # a PR
/octopus:money-review feat/billing --base=main
/octopus:money-review --only=env,webhook
/octopus:money-review --write-report
```

## Overrides (recommended for mature repos)

- `docs/money-review/patterns.md` — add domain-specific tokens
  (e.g. `mensalidade`, `matricula`) and content regex.
- `docs/money-review/providers.md` — override provider idioms
  (idempotency conventions, webhook signature helpers).

Both override files **append** to the defaults; they do not replace them.

## Inspection families

- **T1 types** — flags `float`/`double`/`number` for money; prefer
  `decimal` / integer cents.
- **T2 rounding** — requires explicit rounding mode; flags inconsistent
  modes across files.
- **T3 tests** — requires a non-round cents literal (`0.01`, `199.99`)
  in tests for modified money functions.
- **T4 env** — blocks new `*_PERCENT`/`*_FEE`/`*_RATE` keys that exist
  in sandbox but not production (or vice versa).
- **T5 idempotency** — warns when payment POST calls lack an idempotency
  key / `externalReference`.
- **T6 webhook** — blocks new webhook endpoints that don't verify a
  signature before processing.
- **T7 disclosure** — warns when a fee env var or pricing-UI rate
  changes without a linked spec mentioning user disclosure.

## Review before merge

The report is guidance, not a gate. Reviewers decide whether to block,
require changes, or accept with an explicit note.
