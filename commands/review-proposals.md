---
name: review-proposals
description: (Octopus) Walk the .octopus/proposals/ queue produced by the propose-knowledge-update Stop hook — review session findings, promote actionable items to CLAUDE.md / knowledge/ / rules/, archive the rest.
---

# /octopus:review-proposals

## Purpose

The Stop hook `hooks/stop/propose-knowledge-update.sh` scans
each session's transcript at session-end for signals worth preserving
(user corrections, files read 3+ times, patterns greped 3+ times) and
writes findings to `.octopus/proposals/<timestamp>.md`. This slash
command walks that queue with the user.

The hook never edits the project tree. This command is how proposals
become rules / knowledge / `CLAUDE.md` content — under human review.

## Usage

```
/octopus:review-proposals
```

## Instructions

### Step 1 — List the queue

List `.octopus/proposals/*.md` sorted newest-first. If the directory
is empty or does not exist, report "no proposals to review" and stop.

### Step 2 — Walk one proposal at a time

For each file, read it and present a one-paragraph summary to the
user covering: corrections count, re-reads count, re-greps count,
the most striking finding.

Ask the user the disposition. Four options:

- **promote** — the user wants action taken. Sub-ask which target:
  `CLAUDE.md` (project-level convention), `knowledge/<domain>/` (a
  domain-scoped pattern or hypothesis), `rules/<lang>/` (a coding
  rule), or `docs/adr/` (a hard-to-reverse architectural decision).
  Hand off to the matching skill: `doc-subcontext` if a per-module
  CLAUDE.md fits better, `continuous-learning` for `knowledge/`,
  `doc-adr` for ADRs.
- **partial** — some findings are worth promoting, others are noise.
  Cherry-pick the actionable lines and route those.
- **archive** — the findings are real but not worth codifying. Move
  the file to `.octopus/proposals/archive/YYYY-MM/`.
- **discard** — the findings are noise. Delete the file.

### Step 3 — Apply the disposition

For **promote** and **partial**: invoke the target skill (see Step 2)
with the relevant excerpt. Do not auto-edit `CLAUDE.md`, `knowledge/`,
or `rules/` from this command — always route through the owning skill
so its discipline applies.

For **archive**: `mkdir -p .octopus/proposals/archive/$(date +%Y-%m)`
and `mv` the file. Report the new path.

For **discard**: `rm` the file. No record kept.

### Step 4 — Continue or stop

After each disposition, ask whether to continue with the next
proposal or stop. Useful for short attention sessions — the queue
persists across invocations.

## Notes

- `.octopus/proposals/` is gitignored — proposals never reach the
  remote. Only the artifacts produced by promotion (commits to
  `CLAUDE.md`, `knowledge/`, `rules/`, ADRs) are tracked.
- The hook is read-only; if signals are noisy, tune the thresholds
  in `hooks/stop/propose-knowledge-update.sh` rather than silencing
  the hook entirely.
- A proposal with zero findings is never written — the hook
  short-circuits when no signal exceeds the thresholds.
