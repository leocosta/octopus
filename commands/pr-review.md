---
name: pr-review
description: (Octopus) Self-review an open PR by orchestrating audit skills and review roles against the PR diff, post the aggregated report as a PR comment, then assign human reviewers.
cli: octopus.sh pr-review
agent: code
---

# /octopus:pr-review

Self-review of an **already-opened PR**. Pulls the PR diff via
`gh`, runs the same orchestration as `/octopus:codereview`
(detect → dispatch skills/roles → fallback checklist → aggregate
report), posts the report as a PR comment, then assigns the
human reviewers configured in `.octopus.yml`.

For **uncommitted** working-tree changes, use
`/octopus:codereview`. For **responding** to review comments,
use `/octopus:respond-to-review`.

## Phase 1 — Fetch PR Diff

Run `octopus pr-review <pr-number>` to:
- Print the PR diff (`gh pr diff <pr-number>`)
- Read reviewers from `.octopus.yml` and assign them at the end
  (Phase 5)

Capture the diff for the dispatch phase.

## Phase 2-4 — Orchestrate Review

Apply the same logic documented in
[`commands/codereview.md`](codereview.md) Phases 1–4 against the
PR diff:

- **Detect** what the diff touches (DB, security, money, tenant,
  contracts, general code)
- **Dispatch** in parallel:
  - `dba` role (if the diff touches the data layer) — `roles/dba.md`
  - `architect` role (always, for non-trivial production code) —
    `roles/architect.md`
  - `audit-security` (auth, secrets, env vars, credential paths)
  - `audit-money` (billing, payment, fee, invoice, subscription)
  - `audit-tenant` (multi-tenant scope, `IgnoreQueryFilters`,
    cross-tenant endpoints)
  - `audit-contracts` (DTO/endpoint changes touching both `api/`
    and `app/`/`lp/`)
- **Fallback checklist** for TODO/FIXME, debug statements,
  emoji, oversized files/functions, deep nesting
- **Aggregate** all findings into a single severity-tiered
  report (BLOCKING / ADVISORY / QUESTION) — same format as
  `codereview` Phase 4

The data-layer **dual gate** (both `dba` and `architect` must
pass) applies — see `core/pr-workflow.md`.

## Phase 5 — Post Report and Assign Reviewers

1. Post the aggregated report as a PR comment via
   `gh pr comment <pr-number> --body-file <report>`
2. If any BLOCKING/CRITICAL findings exist, surface them to the
   user and pause — the PR is not ready for human reviewers yet.
   Help the user fix, commit, push, then re-run.
3. If only ADVISORY/QUESTION findings remain, proceed:
   `octopus pr-review` already assigned the reviewers configured
   in `.octopus.yml`. Confirm assignment succeeded.

## Phase 6 — Hand Off

Inform the user:
> "PR is now in review. Invoke `/octopus:pr-comments <number>`
> when there is feedback (or `/octopus:respond-to-review` for a
> single comment)."
