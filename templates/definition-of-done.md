# Definition of Done

> The team-wide baseline every change meets before it is "done" — ready to
> merge and ready to ship. This is a **contract**, not a reimplementation:
> each item points at the role, skill, or rule that *enforces* it. Per-feature
> acceptance criteria stay in the PRD; this is the floor under all of them.
>
> Authored and maintained via the `definition-of-done` skill. Edit the items
> below to fit the team — keep each one a **checkable statement** with a
> pointer to its enforcer in parentheses.

## Metadata

| Field | Value |
|---|---|
| **Owner** | {{OWNER}} (the manager / tech lead who maintains this) |
| **Last reviewed** | {{DATE}} |
| **Applies to** | every change merged to the default branch |

## The Bar

### Tested

- [ ] New or changed behavior is covered by tests for the **behavior**, not
      the implementation. (→ `rules/common/testing.md`, `test-tdd`)
- [ ] Critical paths (auth, payments, data mutations) have **integration**
      tests. (→ `rules/common/testing.md`)
- [ ] The full suite passes locally before review. (→ `implement`
      verification-before-completion)

### Reviewed

- [ ] Passes the `architect` self-review for design fit and readability.
      (→ role `architect`)
- [ ] Security-sensitive diffs (auth, secrets, tokens, `.env*`) pass the
      `security` role. (→ role `security`)
- [ ] Data-layer diffs (migrations, repositories, `.sql`, schemas) carry the
      `dba` + `architect` dual gate. (→ `core/pr-workflow.md`)
- [ ] At least one approval; the author does not approve their own PR.
      (→ `core/pr-workflow.md`)

### Documented

- [ ] Irreversible or hard-to-reverse decisions have an ADR. (→ `doc-adr`)
- [ ] Public API / contract changes update the relevant docs and the
      frontend/backend contract. (→ `review-contracts`)
- [ ] The PR description states **what**, **why**, and **how to test**.
      (→ `core/pr-workflow.md`)

### Grounded

- [ ] No invented conventions — naming, folders, fields, and enums match
      `CONTEXT.md` and the ADRs. (→ `audit-grounding`, `standards`)
- [ ] No unsupported domain facts in code, comments, or touched docs.
      (→ `audit-grounding`)

### Clean

- [ ] Formatter and type checker pass. (→ `guardrails` hooks,
      `rules/common/quality.md`)
- [ ] No debug statements (`console.log`, `print()`, `dd()`, …) in
      production code. (→ `guardrails` hooks)
- [ ] No `TODO` / `FIXME` checked in without a tracked issue or RM.
      (→ `implement` anti-patterns)
- [ ] Commits never used `--no-verify`; commit messages follow Conventional
      Commits. (→ `guardrails` hooks, `core/commit-conventions.md`)

### Released safely

- [ ] Money-touching code is audited when touched. (→ `audit-money`)
- [ ] Multi-tenant data-scope is audited when entities/queries change.
      (→ `audit-tenant`)
- [ ] Frontend/backend contracts are audited when both stacks change in one
      diff. (→ `review-contracts`)

## Team-specific items

> Add the items unique to this team that the baseline above doesn't cover —
> e.g. feature-flag hygiene, analytics events, accessibility, observability,
> on-call runbook updates. Keep the **statement → enforcer** shape. Delete
> this section if there are none.

- [ ] {{TEAM_ITEM}} (→ {{ENFORCER}})

## Changelog

- **{{DATE}}** — Initial Definition of Done.
