---
name: pr-ready
description: (Octopus) Mark a draft PR as ready for review
cli: octopus.sh pr-ready
---

## Instructions

1. Resolve the PR number from `$1`. If it is empty, pass no argument —
   the CLI falls back to the PR open for the current branch.
2. Run: `octopus pr-ready <pr-number>` (or `octopus pr-ready` to use
   the fallback).
3. The script will:
   - Report and stop successfully if the PR is already ready for review
   - Otherwise mark the draft ready
4. Report the result and suggest `/octopus:pr-review <pr-number>` as
   the next step.
