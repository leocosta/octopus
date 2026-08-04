# Spec: Review Anchor Verification

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-08-04 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-170 (Cluster 31 — review-engine parity) |

## Problem Statement

Every finding a review produces cites `<path>:<line>`, and that citation is
written from the model's head. Nothing checks it. A reviewer who opens the wrong
file to verify a finding pays the full cost of a real finding and gets nothing —
the most common way review output wastes a senior's time.

The failure is invisible by construction: an invented location arrives formatted
exactly like a correct one. It is also load-bearing for the rest of Cluster 31 —
RM-171 cannot filter findings it cannot locate, and RM-175 cannot score a hit
without a line to match against annotations.

## Goals

- Every `path:line` in a report is resolved against the diff before the report is
  printed or posted, deterministically and with no model call.
- A citation that cannot be resolved is **labelled**, not silently reported at a
  plausible-looking location.
- An unresolvable finding **cannot block a commit** — an unverifiable location is
  not grounds to stop work, though the underlying claim may still be true.
- Report formatting survives verification (headers, blank lines, prose).

## Non-Goals

- **Not judging whether the finding is correct** — only whether its location is
  real and touched by this change. Correctness filtering is RM-171.
- **Not rewriting the report.** The command annotates and summarises; the caller
  decides what to demote. Keeping it side-effect-free is what makes it safe to run
  in both `codereview` and `pr-review`.
- **Not inline PR comments yet.** Anchors are the precondition
  (`gh api .../comments` needs a `line` the API accepts), but posting them is
  separate work.

## Design

### Overview

- `cli/lib/anchor-verify.sh` — sourceable library, no side effects.
- `cli/lib/review-anchor.sh` — the `octopus review-anchor` command.

Same split as RM-172 (`audit-prepass`/`audit-cache` + `audit-scope`): helper libs
are not in `cli/lib/commands.default`, so they are never dispatchable.

### Detailed Design

**Changed-line resolution.** `git diff -U0 <base>..<ref> -- <path>`, parsing the
`@@ … +start,count @@` post-image spec. `-U0` is what makes the answer the changed
lines themselves rather than their context. A hunk with `count == 0` is a pure
deletion and contributes no anchorable line.

**Verdicts:**

| Verdict | Condition |
|---|---|
| `anchored` | file exists at `<ref>`, line ≤ EOF, line is in a changed hunk |
| `not-in-diff` | file and line exist, but this change did not touch it |
| `line-out-of-range` | line < 1, non-numeric, or past EOF at `<ref>` |
| `missing-file` | no such path at `<ref>` |
| `no-anchor` | the text carries no citation (section headers, prose) |

`not-in-diff` is deliberately **not** a failure: a finding about pre-existing code
reached through the diff is legitimate. Only `line-out-of-range` and
`missing-file` — locations that cannot exist — count as failures and drive the
exit status.

**Citation extraction** is conservative: a token must contain a dot or a slash
before the colon, so `TODO: refactor` and `BLOCKING (2)` do not read as anchors.
The first citation on a line wins.

**Integration.** A new Phase 4.5 in `codereview` (after aggregation, before
Phase 5) and in `pr-review` (before the report is posted). Failed findings demote
to QUESTION tagged `unanchored`; Phase 5 explicitly does not block on them.

### Migration / Backward Compatibility

Additive. A review that never calls `review-anchor` behaves exactly as before, so
the command can ship ahead of any orchestrator adopting it.

## Implementation Plan

1. `cli/lib/anchor-verify.sh` — changed-line resolution, verdicts, extraction,
   stream annotation.
2. `cli/lib/review-anchor.sh` + registry entry.
3. `tests/test_review_anchor.sh` — git fixtures.
4. `commands/codereview.md` Phase 4.5 + the Phase 5 non-blocking rule;
   `commands/pr-review.md` before posting.

## Context for Agents

**Knowledge modules**: [architecture]
**Implementing roles**: [architect]
**Related ADRs**: N/A
**Skills needed**: [implement, test-tdd]
**Bundle**: N/A — no new skill.

**Constraints**:
- Pure bash; `git` and POSIX text tools only.
- Never mutate the report — annotate and summarise.
- Deterministic: no model call anywhere in this path.
- Follow the `cli/lib/audit-scope.sh` conventions (documented API header,
  helper libs stay out of the registry).

## Testing Strategy

`tests/test_review_anchor.sh`, against throwaway git repositories: changed-line
resolution for a modified line and appended lines; untouched file yields none;
each of the five verdicts; extraction rejecting prose colons and taking the first
citation; stream annotation preserving blank lines; exit 1 on failure and 0 when
clean; stdin and `--file` paths; refusal outside a git repo; registry placement.

## Risks

- **Renames.** A finding about a file renamed within the same diff cites the new
  path, which resolves — but a finding citing the old path reads as
  `missing-file`. Correct, if occasionally surprising.
- **Whitespace-only or mode-change hunks** produce anchorable lines that carry no
  semantic change. Harmless: this step judges location, not substance.
- **Over-demotion.** If extraction were too eager it would demote good findings.
  Mitigated by requiring a dot or slash in the path token, and by `no-anchor`
  being a pass-through rather than a failure.
- **Large reports.** One `git diff` per cited file; fine at review scale, worth
  memoising per path if a report ever carries hundreds of findings.

## Changelog

- **2026-08-04** — Initial draft (RM-170)
