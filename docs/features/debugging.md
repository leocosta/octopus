# Debugging

The Octopus bug-fix workflow — active by default on every
bug-triage task. The features pair for `implement`.

The skill codifies four phases, in order:

1. **Reproduce deterministically** — one command or sequence that
   triggers the bug every run. If the bug is intermittent, stop
   and gather more context first.
2. **Isolate** — `git bisect` for regressions; hypothesis →
   test → refute for everything else. Narrow by input, env, code
   path, or dependency version. Logs confirm hypotheses; they do
   not substitute for isolation.
3. **Fix with a regression test first** — write a test that
   fails on the bug, then the minimal fix to make it pass. The
   test joins the project's normal suite so future regressions
   are caught.
4. **Document non-obvious cause** — if the diff does not explain
   the root cause, write it down (commit message, ADR, or
   `continuous-learning` entry). Silent "it works now" fixes
   return as the same bug under a different symptom months
   later.

## When to use

The skill engages automatically on tasks that start from a
failure in the current working copy — bug report, failing test,
stack trace, regression. It does not engage for new-feature work
(that's `implement`) or read-only stack-trace analysis from an
external source.

## Enable

The `starter` bundle includes `debugging`, so a standard
`octopus setup` run delivers it. If you use an explicit
`skills:` list in `.octopus.yml`, add:

```yaml
skills:
  - debugging
```

## Explicit invocation

```
/octopus:debugging <bug description or failing test name>
```

## Relationship to other skills

- `implement` — features workflow. Phase 3 of `debugging` reuses
  `implement`'s TDD loop.
- `audit-all` — pre-merge audit. Run after the fix, before
  opening the PR.
- `continuous-learning` — Phase 4 destination for recurring
  patterns.
- `rules/common/*` — always-on static rules. `debugging` never
  duplicates them.
- `superpowers:systematic-debugging` — when installed, wins per
  phase on the practices it already covers.

## Extension point

The `## Task Routing` section is a v1 stub reserved for RM-034,
which will auto-dispatch to the right companion skill based on
the bug (`dotnet` for .NET traces, `tenant-scope-audit` for
data-leak bugs, `money-review` for financial regressions, etc.).

## Review before merging

The `debugging` skill is guidance, not a gate. Treat anti-pattern
violations as review blockers; the skill itself never fails the
build. Run `audit-all` after a fix to catch downstream effects.
