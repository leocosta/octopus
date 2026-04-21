# Spec: `/octopus:implement` plan walker

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | Leonardo Costa |
| **Status** | Implemented (2026-04-21) |
| **RFC** | N/A |
| **Roadmap** | RM-037 |

## Problem Statement

RM-035 (`/octopus:doc-design`) and RM-036 (`/octopus:doc-plan`)
brought the spec-design and plan-writing legs of the Cluster 5
loop inside Octopus. The third leg — **executing** a plan
task-by-task with review checkpoints — still requires reaching
for `superpowers:executing-plans` or
`superpowers:subagent-driven-development`.

The existing `/octopus:implement` skill already codifies the
per-task TDD loop (red → green → verify → commit). What it
cannot do today is consume a plan file as input, walk the
checklist, and pause for human review between tasks. This
RM closes that gap and finishes Cluster 5.

## Goals

- Extend `/octopus:implement` so that, when invoked with a
  plan file path, it walks the `- [ ]` task checklist top to
  bottom, running the skill's current TDD loop per task.
- Pause for human review after each task (show a short
  recap — files touched, tests that now pass — and ask to
  continue / stop / redo).
- Flip each task's `- [ ]` to `- [x]` in-place as tasks
  complete, so a session that is interrupted can resume
  from where it stopped.
- Reuse the existing `/octopus:implement` surface — same
  skill, same bundle, same packaging — adding only the new
  input path.
- Chain naturally from `/octopus:doc-plan`: the plan
  command's final message already suggests
  `/octopus:implement --plan`; this RM makes the suggestion
  real.

## Non-Goals

- Running multiple tasks in parallel. The walker is
  sequential; parallel execution is what
  `superpowers:subagent-driven-development` does and is out
  of scope here.
- Generating a new plan from a spec on the fly. That is
  RM-036's territory (`/octopus:doc-plan`). The walker
  consumes existing plans only.
- Auto-creating PRs or pushing commits. The plan's per-task
  commits accumulate on the current branch; the user opens
  the PR manually after the walker completes.
- Editing the plan body. The walker only flips checkbox
  state; any textual drift (task renamed mid-session) is a
  human's call.

## Design

### Overview

`/octopus:implement` gains a second branch of behaviour:
when invoked with `--plan <path>`, the command reads the
plan file (produced by `/octopus:doc-plan`), walks its
`- [ ]` task checklist top to bottom, and dispatches the
existing `implement` skill to run each task's per-task TDD
loop. Between tasks, the command pauses for human review.

Packaging:

- `commands/implement.md` owns the walker orchestration
  (parse `--plan`, iterate tasks, flip checkboxes, pause
  between tasks, handle interruption).
- `skills/implement/SKILL.md` stays unchanged — it keeps
  codifying the per-task TDD protocol and is reused as the
  inner loop the walker calls.

No new SKILL.md. No new bundle. No new frontmatter.

**Checkbox persistence.** After a task finishes its commit
step, the walker edits the plan file in place, flipping that
task's `- [ ]` to `- [x]`. A session that is interrupted —
Ctrl-C, machine reboot, user steps away — can be resumed by
re-running `/octopus:implement --plan <path>` and the
walker picks up from the first unchecked task.

**Per-task review pause.** After each task's commit, the
walker prints:

- Task name + number.
- Files created / modified (from `git show --stat HEAD`).
- Tests that moved from RED to GREEN (if any).
- The next task's name.

Then prompts: `Continue / stop / redo-current (y / s / r)`.

**Chain completion.** When all tasks are checked, the
walker prints a final summary and suggests
`/octopus:pr-open` as the next step. HARD-GATE: the walker
never opens the PR, never pushes, never creates a branch
beyond the one the user started on.

### Detailed Design

**Command flow (`commands/implement.md`):**

```
Entry:
  /octopus:implement              → single-task mode (unchanged)
  /octopus:implement --plan PATH  → walker mode (new)
  /octopus:implement --plan PATH --resume-from TaskN
                                  → walker mode, start at TaskN

Walker mode steps:

Step 1 — Load plan
  - Resolve PATH (default docs/plans/ + slug if relative).
  - Abort if file missing.
  - Parse the plan into a list of Tasks:
    Task = { header, start_line, end_line, checked:bool }
  - Identify tasks by regex '^## Task \d+'; each task block
    ends at the next '^## ' or EOF.
  - Identify check state by scanning the '- [ ]' / '- [x]'
    lines inside each block. A task is 'checked' iff EVERY
    step line is '- [x]'.

Step 2 — Find starting task
  - If --resume-from TaskN: start at that task; refuse if
    the task is already fully checked.
  - Else: first task with at least one '- [ ]' step.
  - If none: print 'All tasks already complete.' and exit.

Step 3 — Main loop (per task)
  For task T:
    a. Print banner: 'Running Task N: <name>'
    b. Read the task block into memory.
    c. Dispatch to the existing `implement` skill with:
       - The task block as the sole input 'ticket'.
       - Instruction: follow the skill's per-task TDD
         protocol (red → green → verify → simplify pass →
         commit).
       - The skill returns when it hits its own commit step.
    d. Verify via `git log -1 --format='%s'` that a commit
       landed. If not (skill declined, tests failed, user
       asked to stop), abort the walker with a clear message
       pointing at the failed task.
    e. Flip the task's step lines from '- [ ]' to '- [x]'
       in the plan file. Stage + commit the plan file
       update as a trailing fixup:
         git commit --amend --no-edit
           (folded into the task's own commit to keep the
           history clean)
    f. Print the review pause block:
       ┌─ Task N complete ────────────────────────────────┐
       │ Name:     <task name>                            │
       │ Files:    <paths from git show --stat HEAD>      │
       │ Tests:    <N passing, inferred from skill output>│
       │ Next:     <next task header or 'Done'>           │
       └──────────────────────────────────────────────────┘
       Continue / stop / redo-current (y / s / r):
    g. Handle reply:
       - y (default)     → next iteration.
       - s               → exit walker, report next Task.
       - r               → git reset --soft HEAD^ AND
                           unflip the checkboxes; re-enter
                           step 3a for the same task.

Step 4 — Completion
  - Print final summary: tasks done, commits made,
    branch name, plan path.
  - Suggest: 'Open the PR with /octopus:pr-open'.
  - HARD-GATE: no auto-push, no auto-PR, no branch
    creation.
```

**Dispatch contract with the skill**

The walker calls into the existing `skills/implement/`
skill by injecting a task ticket. Contract:

- Input: a markdown block containing the task (header +
  Files + steps with their code blocks).
- The skill runs its established protocol for that single
  task. The skill's commit step is what the walker watches
  for to know the task finished.
- Output: exit code via the skill's normal verification
  loop. If the skill requires human input mid-task
  (approval, clarification), the walker passes it through —
  the walker does not suppress or pre-answer anything.

No change to the skill's SKILL.md. The "dispatch" is
instructional inside `commands/implement.md`: it tells the
agent "run the implement skill's protocol for this block"
and the agent does.

**Parsing rules (for the command instructions)**

- Task header regex: `^## Task \d+:` (matches the
  plan-skeleton fixture from RM-036).
- Checkbox detection: a task is considered "in progress"
  when at least one step is `- [ ]` AND at least one is
  `- [x]`; "not started" when all are `- [ ]`; "done" when
  all are `- [x]`.
- Redo: to unflip, the command edits the plan block
  touching that task and replaces every `- [x]` with
  `- [ ]` inside that block only.

**Interaction with the existing `--plan` flag**

`commands/implement.md` today does not define any flags.
`--plan` is new; its value is a path. If the path is
relative and does not exist, the walker tries
`docs/plans/<value>.md` as a convenience, to mirror the
`doc-plan` output path.

### Migration / Backward Compatibility

<!-- How do existing users/systems transition? What breaks? -->

## Implementation Plan

1. **Extend `commands/implement.md` with walker mode.**
   Add Entry section describing `--plan` and
   `--resume-from`. Add Instructions block with the 4-step
   walker flow (Load plan → Find start → Main loop →
   Completion). Add Dispatch contract and Parsing rules
   subsections. Keep the existing single-task instructions
   intact as the default branch. Isolated edit; no code.
2. **Pick the checkbox-flip commit strategy.** Before
   writing tests: implement a spike in a throw-away branch
   that runs one fake task end-to-end with each strategy
   (`--amend` vs separate commit), inspect the resulting
   history, and decide. Capture the decision in a short
   ADR under
   `docs/adr/<N>-plan-walker-checkbox-commit.md`. Depends
   on Step 1 (instructions reference the chosen strategy
   literally).
3. **Create `tests/test_implement_plan_walker.sh`.**
   Structural tests:
   - `commands/implement.md` documents the `--plan` flag.
   - `--resume-from` flag documented.
   - Walker 4-step flow present (`Step 1 — Load plan` …
     `Step 4 — Completion`).
   - Banner string "Task N complete" present (greppable
     anchor for the review pause).
   - Continue / stop / redo-current prompt literal
     present.
   - HARD-GATE against PR-open / push / branch creation.
   - Reference to the ADR from Step 2 (relative link).
   Structural only — no subprocess of the actual walker.
4. **Dog-food test against `bundle-diff-preview`.**
   Use the landed RM-027 spec + a fresh `/octopus:doc-plan`
   run to produce `docs/plans/bundle-diff-preview.md`,
   then run
   `/octopus:implement --plan docs/plans/bundle-diff-preview.md`
   for the first 2 tasks. Capture the session output in
   `docs/research/YYYY-MM-DD-plan-walker-dogfood.md`.
   Merge any protocol issues back into
   `commands/implement.md` before the roadmap flip.
5. **Move RM-037 from Backlog to Completed** in
   `docs/roadmap.md`. Flip spec Status to
   `Implemented (<date>)`. Close Cluster 5 in the roadmap
   preamble.

## Context for Agents

**Knowledge modules**: N/A (workflow skill; no domain
knowledge).
**Implementing roles**: tech-writer (for the command
instructions and ADR), backend-specialist (bash — only if
the checkbox-flip strategy ends up needing a helper
script; most likely not).
**Related ADRs**: the checkbox-commit ADR from
Implementation Step 2 (`docs/adr/<N>-plan-walker-checkbox-commit.md`).
**Skills needed**: `adr`, `feature-lifecycle`, `implement`
(reused as the inner TDD loop), `plan-backlog-hygiene`.
**Bundle**: `starter (existing)` — `implement` is already
in `starter`; no new placement needed.

**Constraints**:
- Pure markdown command edits (no SKILL.md change, no new
  shell script unless Step 2 forces one).
- Walker is strictly sequential. No parallelism, no
  timeouts.
- HARD-GATE: walker never pushes, never opens PRs, never
  creates branches. The user owns the branch the walker
  commits onto.
- Checkbox is the single source of truth for progress
  state; no shadow state file.
- Re-parsing the plan is allowed only between tasks, not
  mid-task.
- Backwards compatible: `/octopus:implement` with no flags
  behaves exactly as today.

## Testing Strategy

- **Structural tests** in
  `tests/test_implement_plan_walker.sh` (step 3 of the
  plan):
  - `--plan` and `--resume-from` flags documented.
  - 4-step walker flow present (`Step 1 — Load plan` …
    `Step 4 — Completion`).
  - Greppable anchors: `Task N complete` banner, the
    `Continue / stop / redo-current` prompt, HARD-GATE
    string.
  - Relative link to the checkbox-commit ADR.
- **Dog-food** (step 4 of the plan): walk the first 2
  tasks of `bundle-diff-preview` and capture the session
  in `docs/research/`. This is the only end-to-end signal;
  the walker is conversational and not unit-testable in
  isolation.
- **Not tested** (same reasoning as `doc-design` and
  `doc-plan`): the per-task TDD loop (already covered by
  the existing `implement` skill), the skill's
  conversational quality, and the review-pause recap body
  (LLM-dependent).

## Risks

- **Mid-task interruption.** If the walker dies while the
  skill is mid-task, the checkbox stays `- [ ]` but files
  may already be edited and a commit may have landed.
  Resume naively tries to run the task again — it will
  double-commit or choke on "write failing test" because
  the test file is already present. Mitigation: step 3.d
  checks whether the current `HEAD` commit's subject
  mentions the task name; if so, the walker offers
  "Task N looks committed but not checked — flip and
  continue? (y/n)" for a semi-auto recovery.
- **Fixup amend vs clean history.** `git commit --amend
  --no-edit` to fold the checkbox flip into the task's own
  commit mutates a commit that was just created. It
  rewrites SHAs (breaks GPG signatures when configured)
  and is unsafe after push-then-resume. Alternative: emit
  a separate `docs(plans): mark task N complete` commit.
  Less clean history but reversible and signature-safe.
  Decision deferred to implementation; both options
  documented.
- **Skill hangs.** If the `implement` skill loops on
  clarification inside a task, the walker imposes no
  timeout. Mitigation: no timeout enforcement — human
  intervenes via Ctrl-C and the resume path (unchecked
  checkbox = restart) picks up cleanly. This is the same
  contract the checkbox-as-truth principle already relies
  on.
- **Plan drift mid-execution.** Editing the plan file
  while the walker is between tasks can leave the walker's
  in-memory view stale. Mitigation: re-parse the plan at
  the top of each loop iteration (cheap — it is a
  markdown file). Editing the plan **during** a running
  task remains undefined behaviour and is documented as
  such.

## Changelog

<!-- Updated as the spec evolves -->
- **2026-04-21** — Initial draft (design session via
  `/octopus:doc-design` plan-B)
