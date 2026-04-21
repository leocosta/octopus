---
name: implement
description: Walk the Octopus implementation workflow explicitly — TDD, plan-before-code, verification, simplify, commit cadence.
---

---
description: Walk the Octopus implementation workflow explicitly — TDD, plan-before-code, verification, simplify, commit cadence.
agent: code
---

# /octopus:implement

## Purpose

The `implement` skill is active by default on every code task;
this slash command drives it explicitly for a single task the
user describes inline.

## Usage

```
/octopus:implement <task description>
```

## Instructions

Invoke the `implement` skill (`skills/implement/SKILL.md`). The
skill owns the full workflow — do not reinterpret it here.

## Walker Mode (plan file execution)

### Entry

```
/octopus:implement              → single-task mode (unchanged; see above)
/octopus:implement --plan PATH  → walker mode
/octopus:implement --plan PATH --resume-from TaskN
                                → walker mode, start at TaskN
```

When `--plan PATH` is supplied the command enters walker mode,
parses the plan file at `PATH`, and walks its `## Task N` blocks
top-to-bottom. If the path is relative and not found, try
`docs/plans/<PATH>.md` as a fallback.

### HARD-GATE

**HARD-GATE:** the walker never pushes, never opens PRs, never
creates branches. Per-task commits accumulate on the branch the
user started on; the user opens the PR manually via
`/octopus:pr-open` after the walker completes.

### Step 1 — Load plan

1. Resolve `PATH`. Abort with a clear error if missing.
2. Parse tasks: each block starts at `^## Task \d+:` and ends at
   the next `^## ` or EOF.
3. For each task, classify by checkbox state:
   - `done` — every `- [ ]`/`- [x]` step is `- [x]`.
   - `in-progress` — mixed.
   - `not-started` — every step is `- [ ]`.
4. Re-parse on every loop iteration (plans may drift between
   tasks).

### Step 2 — Find starting task

- If `--resume-from TaskN` is set: start there; abort if `TaskN`
  is already `done`.
- Otherwise: first task that is not `done`.
- If none remain: print `All tasks already complete.` and exit 0.

### Step 3 — Main loop

For each selected task:

1. Print: `Running Task N: <name>`.
2. Read the task block into memory.
3. **Dispatch** to the `implement` skill (single-task mode above)
   with the task block as the ticket. The skill runs its
   per-task TDD protocol and returns after its commit step.
4. Verify a commit landed via `git log -1 --format='%s'`. If
   none landed, abort with a message pointing at the task.
5. Flip every step inside the task block from `- [ ]` to `- [x]`,
   stage the plan file, and amend the task commit per ADR
   [`001-plan-walker-checkbox-commit.md`](../docs/adr/001-plan-walker-checkbox-commit.md):

   ```bash
   git add <plan-path>
   git commit --amend --no-edit
   ```

6. Print the review pause:

   ```
   ┌─ Task N complete ───────────────────────────────────┐
   │ Name:  <task name>                                  │
   │ Files: <paths from git show --stat HEAD>            │
   │ Tests: <N passing, from skill output>               │
   │ Next:  <next task header or 'Done'>                 │
   └─────────────────────────────────────────────────────┘
   Continue / stop / redo-current (y / s / r):
   ```

7. Handle reply:
   - `y` (default) → next iteration.
   - `s` → exit walker; report the next pending task.
   - `r` → `git reset --soft HEAD^`, unflip that task's
     checkboxes, repeat the iteration.

### Step 4 — Completion

When no unchecked tasks remain:

- Print a final summary: `<N> tasks done, <N> commits on
  <branch>, plan at <path>`.
- Suggest `/octopus:pr-open` as the next step. Never open the PR
  automatically.

### Dispatch contract with `implement` (single-task mode)

- Input: a markdown block — the task header + its Files block +
  step list with code.
- Output: a commit matching the task's Step 5 (the TDD commit
  step).
- If the skill requires human input mid-task, pass it through
  untouched.

### Parsing rules

- Task header regex: `^## Task \d+:`.
- Checkbox toggle: inside a task block only, replace every
  `- [ ]` with `- [x]` (done) or vice versa (redo).
- Editing the plan **during** a running task is undefined
  behaviour; re-parse happens only between iterations.
