# Dog-food report — /octopus:doc-plan (RM-036)

**Date:** 2026-04-21
**Command exercised:** `/octopus:doc-plan implement-plan-walker`
  (plan-B — the slash-command registration was not yet
  reloaded in the session, so the agent followed the
  protocol from `commands/doc-plan.md` inline).
**Input spec:** `docs/specs/implement-plan-walker.md` (RM-037)
**Output plan:** `docs/plans/implement-plan-walker.md`

## What worked

- **Coverage check (Step 1).** Detected that the spec's
  `## Implementation Plan` section was populated (5 items,
  P1..P5, no `<!--` placeholders) and allowed the session to
  proceed.
- **Context scan (Step 2).** Silent read of commits, spec
  metadata, Implementation Plan items, and the
  `plan-skeleton.md` fixture; emitted one-line report and
  moved on.
- **Header + File Structure (Step 3).** Derived Goal,
  Architecture, and Tech Stack from the spec's Overview +
  Detailed Design + Context for Agents constraints. File
  Structure table listed every file the spec's Implementation
  Plan mentioned. User approved without revision.
- **Adaptive decomposition heuristics (Step 4).** Correctly
  fired "too big" on Task 1 (ADR — verbs: spike, inspect,
  capture) and Task 4 (dog-food — verbs: produce, run,
  capture, merge). Did not fire on trivial tasks. User
  answered `n` to both; split would have been ceremonial.
- **Self-review (Step 5).** Zero placeholder red flags,
  type consistency OK, spec coverage: all 5 `P_i` mapped.
  Plan size (5 tasks) well under the 15-task split warning.
- **Docs-only branch + commit (Step 6).** The session
  started on `docs/implement-plan-walker-design` (not
  main), so no auto-branch was needed; the plan was
  committed on that existing branch alongside the spec.

## What surfaced

- **Task ordering mismatch.** The spec's Implementation Plan
  listed items in writing order (P1 = extend command,
  P2 = ADR), but a sensible execution order needed P2 before
  P1 (the command references the ADR literally). The command
  iterates `P_i` in the order given; the agent had to reorder
  manually. Gap worth codifying: after Step 2, detect
  "depends on Step N" mentions in the spec and suggest a
  topological sort.
- **Non-TDD task shapes.** Three of five tasks (ADR,
  dog-food, roadmap finalisation) did not fit the
  "failing test → minimal impl → verify → commit" skeleton.
  The agent adapted them manually as sequential-step tasks
  without `Expected: FAIL` / `PASS` lines. The command
  currently prescribes TDD as the default; it should
  document alternative task shapes explicitly
  (e.g. "doc-only tasks omit the RED/GREEN steps").
- **Mid-execution scope adjustment.** During executing-plans,
  the original Task 4 (walker dog-food against
  `bundle-diff-preview`) was dropped because it would have
  pulled 2 real RM-027 implementation commits into this PR.
  The scope reduction was a manual judgment call, not
  something the plan format surfaces. Not necessarily a
  `doc-plan` bug — could be a `writing-plans` guideline
  ("flag cross-RM dependencies explicitly").

## Fixes considered

None of the gaps are correctness bugs; all three are
instructional quality-of-life improvements. Worth rolling
into a follow-up `fix(doc-plan)` PR alongside the first
real walker dog-food (see next section).

## Next dog-food (RM-037)

Once `/octopus:implement --plan` ships (this PR), dog-food
it against any plan (does not need to be a full
implementation — can be `docs/plans/implement-plan-walker.md`
itself, re-run, to exercise the resume path). Capture walker
behaviour in a separate `docs/research/YYYY-MM-DD-plan-walker-dogfood.md`.
