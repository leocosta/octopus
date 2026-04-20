<!-- Canonical task-routing matrix for the three starter workflow
     skills (implement, debugging, receiving-code-review).
     When you edit this file, the pre-commit / CI checks verify
     that each SKILL.md contains a byte-identical copy of the
     block between the BEGIN and END markers below. Edit once
     here; the sync is enforced by tests/test_task_routing.sh. -->

<!-- BEGIN task-routing -->
When a task starts, scan the signals below and consult the
matching companion skills alongside the core workflow. Signals
are heuristics — more than one may apply; treat them as a
checklist, not a switch statement.

**Stack / language signals**

| Signal | Consult |
|---|---|
| Paths under `api/**/*.cs`, `*.sln`, `*.csproj`; stack traces with `System.*` | `dotnet`, `backend-specialist` role |
| Paths under `app/**/*.tsx`, `*.jsx`, `*.vue`; UI-layer bugs; reviewer comments about rendering / accessibility | `frontend-specialist` role |
| Node/TypeScript backend (`apps/api/**/*.ts`, `package.json` with `express`/`fastify`/`hono`/`nestjs`) | `backend-patterns`, `backend-specialist` role |
| Astro / Next.js landing page (`lp/`, `apps/lp/`, `src/pages/`) | `frontend-specialist` role |

**Domain-audit signals**

| Signal | Consult |
|---|---|
| Keywords `payment`, `billing`, `split`, `fee`, `invoice`, `subscription`; paths `billing/`, `payment/` | `money-review` |
| New `DbSet<X>`, multi-tenant queries, `[Authorize]` changes, `IgnoreQueryFilters()` | `tenant-scope-audit` |
| Change touches both `api/` and `app/` (or `lp/`) in the same diff; DTO/endpoint changes | `cross-stack-contract` |
| Secrets, env vars, `detect-secrets` warnings, authentication paths | `security-scan` |
| Pre-merge on a non-trivial PR that touches billing or multi-tenant data | `audit-all` (composer — runs all four audits in parallel) |

**Cross-workflow signals**

| Signal | Consult |
|---|---|
| Trigger is a **new feature** or **refactor** (not a reported bug or review comment) | Stay in `implement` |
| Trigger is a **bug report**, **failing test**, **stack trace**, or **regression** | Hand off to `debugging` (Phase 3 uses `implement`'s TDD loop for the fix) |
| Trigger is a **PR review comment** | Hand off to `receiving-code-review` (Rule 1 verifies, then handoff back to `implement` or `debugging` per the comment's intent) |
| Task involves both docs and code | Compose with `feature-lifecycle` for docs (RFC / Spec / ADR), use the appropriate workflow skill for the code |

**Risk-profile signals**

| Signal | Consult |
|---|---|
| Large-scale / cross-module change (touches ≥ 3 modules) | Escalate `implement`'s plan-before-code gate to a spec via `/octopus:doc-spec`; add an ADR via `/octopus:doc-adr` if the change encodes a decision |
| Data migration, schema change, irreversible operation | Keep `debugging`'s Phase 3 regression test; consider an ADR; consider tagging the change for the destructive-action guard hook |
| Release-triggering change | Pair with `release-announce` (retention) or `feature-to-market` (acquisition) for the user-facing announcement after merge |

**Graceful degradation**

A companion skill that isn't installed in the current repo
doesn't block the workflow — the main skill continues with
`rules/common/*` and whatever else is available. Surface the
gap once, as a hint: "this task would benefit from
`<skill-name>`; add it to `.octopus.yml` to enable."

Don't stall. Don't block. Don't invent advice the missing skill
would have provided — point at the gap and move on.
<!-- END task-routing -->
