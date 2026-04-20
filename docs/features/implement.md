# Implement

The Octopus implementation workflow — active by default on every
code-editing task.

The skill codifies five universal practices:

1. **TDD loop** — write the failing test first, then the minimal
   implementation, then refactor, then commit.
2. **Plan-before-code gate** — present a short plan and wait for
   approval before editing code on non-trivial tasks.
3. **Verification-before-completion** — run the project's tests /
   typecheck / format before declaring work complete, and include
   the output in the reply.
4. **Simplify pass** — re-read the change with the simplifier
   lens before committing (duplication, dead code, premature
   abstraction, unclear names).
5. **Commit cadence** — one commit per logical step, each passing
   the project's pre-commit hooks. Never `--no-verify`.

## When to use

The skill is active by default — it engages whenever a task
involves editing code. It does not engage for read-only analysis
or documentation-only changes.

## Enable

The `starter` bundle includes `implement`, so a standard
`octopus setup` run already delivers it. If you use an explicit
`skills:` list in `.octopus.yml` instead of bundles, add:

```yaml
skills:
  - implement
```

## Explicit invocation

If the skill does not auto-engage, drive it explicitly:

```
/octopus:implement <task description>
```

## Relationship to other skills

- `rules/common/*` — always-on static rules. `implement` covers
  the dynamic side; never duplicates the rules.
- `feature-lifecycle` — docs workflow (RFC/Spec/ADR). `implement`
  is the code workflow. They compose.
- `debugging` (RM-031, future) — bug-fix flow. `implement`'s TDD
  loop still applies to the fix itself.
- `receiving-code-review` (RM-032, future) — PR feedback flow.
- Audit skills (`security-scan`, `money-review`,
  `tenant-scope-audit`, `cross-stack-contract`, `audit-all`) —
  pre-merge review. `implement` is pre-audit.
- `superpowers:*` skills — when installed, they win on the
  practices they already cover (TDD, systematic debugging,
  verification-before-completion). `implement` fills the gaps.

## Extension point

Section `## Task Routing` in the skill is a v1 stub reserved for
RM-034, which will auto-dispatch to the right sub-skill
(`backend-patterns`, `dotnet`, `frontend-specialist` role, …)
based on the task. Until RM-034 lands, the agent uses judgment.

## Review before merging

The `implement` skill is guidance, not a gate. Treat anti-pattern
violations as review blockers but the skill itself does not fail
the build. Audit skills (`audit-all`) are the pre-merge gate.
