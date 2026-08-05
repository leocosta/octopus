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
[`commands/codereview.md`](codereview.md) Phases 0–4 against the
PR diff:

- **Size gate** (Phase 0) — a small, low-risk PR (under ~150 lines,
  no data/auth/money/tenant path) gets one consolidated pass, not
  the fan-out below.
- **Detect** what the diff touches (DB, security, money, tenant,
  contracts, general code), recording the file subset per match.
- **Resolve scope** for each matched audit with
  `octopus audit-scope <skill> --base <base> --ref <ref>` before
  dispatching (RM-172) — `skip` and `cached` do not spawn a
  sub-agent at all.
- **Dispatch** in parallel, each agent receiving **only its
  domain-matching file subset** (not the whole PR diff):
  - `dba` role (if the diff touches the data layer) — `roles/dba.md`
  - `architect` role (non-trivial production code: a matched
    domain, >~150 lines, or a public-API/architecture change) —
    `roles/architect.md`
  - `audit-security` (auth, secrets, env vars, credential paths)
  - `audit-money` (billing, payment, fee, invoice, subscription)
  - `audit-tenant` (multi-tenant scope, `IgnoreQueryFilters`,
    cross-tenant endpoints)
  - `audit-contracts` (DTO/endpoint changes touching both `api/`
    and `app/`/`lp/`)
  Dispatch only the audits whose files matched (the
  `cli/lib/audit-map.sh` map), never the full fixed set.
- **Fallback checklist** for TODO/FIXME, debug statements,
  emoji, oversized files/functions, deep nesting
- **Aggregate** all findings into a single severity-tiered
  report (BLOCKING / ADVISORY / QUESTION) — same format as
  `codereview` Phase 4

The data-layer **dual gate** (both `dba` and `architect` must
pass) applies — see `.claude/core/pr-workflow.md`.

## Phase 4.5 — Anchor Verification

Run `codereview` Phase 4.5 against the aggregated report **before
posting it** (RM-170):

```bash
octopus review-anchor --base <base> --ref <ref> --file <report>
```

A PR comment is public and durable, so an unverifiable `path:line`
costs more here than in a local review: demote `missing-file` and
`line-out-of-range` findings to QUESTION, tagged `unanchored`, and
only then post.

## Phase 4.55 — Reflection Pass

Findings are written by models and nothing has judged them yet — Phase 4.5
proved only that their locations are real. A false BLOCKING stops real work, and
the fastest way to teach a team to bypass a gate is to block them wrongly once
(RM-171). This runs before the report is posted, not before a commit block.

```bash
octopus review-reflect prepare --base <base> --ref <ref> --file <report>
```

**Exit 1 means nothing was eligible — skip the rest of this phase entirely.** Do
not spawn the sub-agent. Only findings from a role or an `audit-*` skill whose
anchor resolved are adjudicable; `fallback` and `definition-of-done` findings are
deterministic and never enter.

Otherwise dispatch **one** sub-agent on the tier the payload's
`OCTOPUS_REFLECT_MODEL` line names (Agent tool, `model` set to that value). Give
it the payload and this instruction:

> For each finding, decide whether the code shown sustains the claim. The burden
> of proof is on the finding: if the window does not sustain it, `reject`. One
> exception — if the window does not show enough to judge (a claim about coupling
> across files, for instance), `keep`. Doubt favours the finding. Do not look for
> new issues and do not read files beyond what you were given. Return one line
> per finding, tab-separated: `<id>	keep|reject	<one-line reason>`.

Write its reply to a file and apply it:

```bash
octopus review-reflect apply --base <base> --ref <ref> --file <report> \
  --verdicts <verdicts-file> --filtered <filtered-file>
```

A rejected BLOCKING/CRITICAL is **demoted to ADVISORY**, not deleted — the claim
stays readable and stops gating. A rejected finding below that tier leaves the
report and lands in `<filtered-file>` for Phase 4.6. Report the
`OCTOPUS_REFLECT_SUMMARY` line so an over-aggressive filter is visible in the run
itself.

If the sub-agent fails or returns nothing usable, `apply` leaves the report
unchanged — the filter never removes what it did not explicitly reject.

## Phase 4.6 — Record the Run

Persist the report before posting it (RM-176):

```bash
octopus review-session record --base <base> --ref <ref> \
  --report <report-file> [--audits <resolutions-file>] [--filtered <filtered-file>]
```

`--filtered` takes the file Phase 4.55 wrote. Pass it — a filter whose discards
are not recorded is a silent hole in coverage rather than a tunable one.

A posted PR comment is the *presentation*; the record is the data.
Only the record survives in a form anything downstream can read.

## Phase 5 — Post Report and Assign Reviewers

1. Sign the report before posting: end the report body with the
   Octopus signature on its own line, preceded by a `---` rule —
   ```
   ---
   <sub>🐙 generated by Octopus</sub>
   ```
   A general PR comment (this aggregated report) is signed; inline
   thread replies — `/octopus:pr-comments`, `/octopus:respond-to-review`
   — are **not**. Then post it as a PR comment via
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
