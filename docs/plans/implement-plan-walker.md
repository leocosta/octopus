# `/octopus:implement` plan walker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extend `/octopus:implement` with a `--plan` walker that executes a plan file task-by-task with review checkpoints, closing Cluster 5.

**Architecture:** Single command-file edit (`commands/implement.md`) adds walker mode. `skills/implement/` stays unchanged and is reused as the per-task TDD loop. The checkbox-commit strategy is decided up-front in an ADR so the command instructions can reference it literally.

**Tech Stack:** Bash 4+, markdown, git.

**Spec:** `docs/specs/implement-plan-walker.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `docs/adr/NNN-plan-walker-checkbox-commit.md` | create | ADR — `git --amend` vs separate commit; output of the spike |
| `tests/test_implement_plan_walker.sh` | create | Structural tests — flags, walker steps, banner anchor, HARD-GATE, ADR link |
| `commands/implement.md` | modify | Add walker mode (Entry, 4-step flow, Dispatch contract, Parsing rules); preserve existing single-task branch |
| `docs/research/2026-04-21-plan-walker-dogfood.md` | create | Dog-food session log (first 2 tasks of a real plan) |
| `docs/roadmap.md` | modify (last task) | Move RM-037 to Completed, close Cluster 5 in the preamble |
| `docs/specs/implement-plan-walker.md` | modify (last task) | Flip Status to `Implemented (2026-04-21)` |

---

## Task 1: ADR — checkbox-commit strategy

**Files:**
- Create: `docs/adr/NNN-plan-walker-checkbox-commit.md` (resolve `NNN` from the current max ADR id + 1)

- [ ] **Step 1: Find the next ADR id**

Run:

```bash
ls docs/adr/ 2>/dev/null | grep -oE '^[0-9]+' | sort -n | tail -1
```

If no output, start from `001`; otherwise increment by 1 and zero-pad to 3 digits. Store as `ADR_ID`.

- [ ] **Step 2: Spike both strategies in a throw-away worktree**

```bash
git worktree add /tmp/plan-walker-spike main
cd /tmp/plan-walker-spike
# Strategy A — amend
git commit --allow-empty -m "feat(spike): pretend task N commit"
echo "task-N: done" >> /tmp/fake-plan.md
git add /tmp/fake-plan.md
git commit --amend --no-edit
git log -1 --format='%H %s' > /tmp/spike-A.txt
# Strategy B — separate commit
git reset --hard HEAD^
git commit --allow-empty -m "feat(spike): pretend task N commit"
echo "task-N: done" >> /tmp/fake-plan.md
git add /tmp/fake-plan.md
git commit -m "docs(plans): mark task N complete"
git log -2 --format='%H %s' > /tmp/spike-B.txt
cd -
git worktree remove /tmp/plan-walker-spike --force
```

Expected: two text files with representative history. Inspect both:
- Strategy A → one commit per task; clean history; SHA rewrite after amend is local only (no push-then-amend concern since the walker amends before any push).
- Strategy B → two commits per task; history is noisier but SHAs never mutate.

- [ ] **Step 3: Write the ADR**

Create `docs/adr/${ADR_ID}-plan-walker-checkbox-commit.md` with:

```markdown
# ADR ${ADR_ID}: Checkbox-flip commit strategy for /octopus:implement walker

## Status

Accepted — 2026-04-21

## Context

RM-037 extends `/octopus:implement` with a `--plan` walker that
marks each plan task `- [x]` as it completes. The flip is a
one-line edit in `docs/plans/<slug>.md`. We need to decide how
this edit reaches git.

Two candidate strategies were evaluated via a spike in a
throw-away worktree:

- **Strategy A — `git commit --amend --no-edit`.** The walker
  folds the plan-file flip into the task's own commit.
- **Strategy B — separate commit.** The walker emits a
  `docs(plans): mark task N complete` commit after the task's
  own commit.

## Decision

Adopt **Strategy A** (amend) for the walker's steady-state flow.

## Rationale

- History stays linear and readable — one commit per task, whose
  subject already describes the task. Reviewers browsing `git
  log` see N entries for N tasks, not 2N.
- SHA rewrite is contained: the walker amends immediately after
  the task's own commit, before any `git push`. Users who push
  mid-walk can already hit the well-documented "don't amend
  pushed commits" rule; the walker does not push on their
  behalf.
- GPG-signing repos pay a re-sign cost on the amend; this is
  the same cost a developer running the TDD loop manually would
  pay when fixing a typo in their commit message.

## Consequences

- Walkers in GPG-signed repos re-sign the task commit once per
  task (acceptable).
- Users who have pushed mid-walk before `--amend` happens must
  force-push (uncommon path; documented in the command body).
- If a future need arises for the plan-file flip to stand
  alone (e.g. for a CI status checker), switching to Strategy
  B is a one-line change in the command instructions. Listed
  here so the reversal cost is explicit.
```

- [ ] **Step 4: Commit the ADR**

```bash
git add docs/adr/
git commit -m "$(cat <<'EOF'
docs(adr): ${ADR_ID} — checkbox-flip commit strategy for plan walker

Decides Strategy A (git commit --amend --no-edit) folds the
checkbox flip into the task's own commit. Alternative
(separate commit) captured with its trade-offs so reversal
is cheap.

Co-authored-by: claude <claude@anthropic.com>
EOF
)"
```

Note the literal `${ADR_ID}` in the commit message should be substituted with the real value from Step 1 (e.g. `001`).

---

## Task 2: Failing structural tests

**Files:**
- Create: `tests/test_implement_plan_walker.sh`

- [ ] **Step 1: Write the full failing test file**

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_FILE="$SCRIPT_DIR/commands/implement.md"
ADR_DIR="$SCRIPT_DIR/docs/adr"

echo "Test 1: commands/implement.md documents --plan flag"
grep -q -- "--plan" "$CMD_FILE" \
  || { echo "FAIL: --plan flag missing from commands/implement.md"; exit 1; }
echo "PASS: --plan flag documented"

echo "Test 2: commands/implement.md documents --resume-from flag"
grep -q -- "--resume-from" "$CMD_FILE" \
  || { echo "FAIL: --resume-from flag missing"; exit 1; }
echo "PASS: --resume-from flag documented"

echo "Test 3: walker 4-step flow present"
for step in "Step 1 — Load plan" "Step 2 — Find starting task" "Step 3 — Main loop" "Step 4 — Completion"; do
  grep -q "$step" "$CMD_FILE" \
    || { echo "FAIL: walker step header '$step' missing"; exit 1; }
done
echo "PASS: walker 4-step flow documented"

echo "Test 4: review pause banner + prompt present"
grep -q "Task N complete" "$CMD_FILE" \
  || { echo "FAIL: 'Task N complete' banner anchor missing"; exit 1; }
grep -q "Continue / stop / redo-current" "$CMD_FILE" \
  || { echo "FAIL: 'Continue / stop / redo-current' prompt missing"; exit 1; }
echo "PASS: review pause documented"

echo "Test 5: HARD-GATE against push / PR / branch creation"
grep -q "HARD-GATE" "$CMD_FILE" \
  || { echo "FAIL: 'HARD-GATE' anchor missing"; exit 1; }
grep -qE "never pushes|never opens PRs|never creates branches" "$CMD_FILE" \
  || { echo "FAIL: walker HARD-GATE wording missing"; exit 1; }
echo "PASS: HARD-GATE documented"

echo "Test 6: ADR referenced from the command"
# Find the ADR file added in Task 1 (matches *-plan-walker-checkbox-commit.md)
adr_path=$(ls "$ADR_DIR"/*-plan-walker-checkbox-commit.md 2>/dev/null | head -1 || true)
[[ -n "$adr_path" ]] || { echo "FAIL: plan-walker checkbox-commit ADR missing"; exit 1; }
adr_basename=$(basename "$adr_path")
grep -q "$adr_basename" "$CMD_FILE" \
  || { echo "FAIL: commands/implement.md does not link the ADR ($adr_basename)"; exit 1; }
echo "PASS: ADR linked"
```

- [ ] **Step 2: Make executable and run**

```bash
chmod +x tests/test_implement_plan_walker.sh
bash tests/test_implement_plan_walker.sh
```

Expected: **FAIL at Test 1** (`--plan flag missing from commands/implement.md`).

- [ ] **Step 3: Commit the failing test**

```bash
git add tests/test_implement_plan_walker.sh
git commit -m "$(cat <<'EOF'
test(implement): add structural tests for /octopus:implement --plan walker

Covers: --plan and --resume-from flags, walker 4-step flow,
review pause banner + prompt, HARD-GATE wording, and
reference to the checkbox-commit ADR.

All tests fail until Task 3 lands the walker mode in
commands/implement.md.

Co-authored-by: claude <claude@anthropic.com>
EOF
)"
```

---

## Task 3: Extend `commands/implement.md` with walker mode

**Files:**
- Modify: `commands/implement.md`

- [ ] **Step 1: Inspect the current command body**

Run: `cat commands/implement.md`

Keep the existing frontmatter and single-task instructions unchanged. The walker mode is added as additional sections at the end.

- [ ] **Step 2: Append the walker-mode sections**

Append to `commands/implement.md`:

````markdown

## Walker Mode (plan file execution)

### Entry

```
/octopus:implement              → single-task mode (unchanged; see above)
/octopus:implement --plan PATH  → walker mode
/octopus:implement --plan PATH --resume-from TaskN
                                → walker mode, start at TaskN
```

When `--plan PATH` is supplied the command enters walker mode,
parses the plan file at `PATH`, and walks its `## Task N`
blocks top-to-bottom. If the path is relative and not found,
try `docs/plans/<PATH>.md` as a fallback.

### HARD-GATE

**HARD-GATE:** the walker never pushes, never opens PRs,
never creates branches. Per-task commits accumulate on the
branch the user started on; the user opens the PR manually
via `/octopus:pr-open` after the walker completes.

### Step 1 — Load plan

1. Resolve `PATH`. Abort with a clear error if missing.
2. Parse tasks: each block starts at `^## Task \d+:` and
   ends at the next `^## ` or EOF.
3. For each task, classify by checkbox state:
   - `done` — every `- [ ]`/`- [x]` step is `- [x]`.
   - `in-progress` — mixed.
   - `not-started` — every step is `- [ ]`.
4. Re-parse on every loop iteration (plans may drift between
   tasks).

### Step 2 — Find starting task

- If `--resume-from TaskN` is set: start there; abort if
  `TaskN` is already `done`.
- Otherwise: first task that is not `done`.
- If none remain: print `All tasks already complete.` and
  exit 0.

### Step 3 — Main loop

For each selected task:

1. Print: `Running Task N: <name>`.
2. Read the task block into memory.
3. **Dispatch** to the `implement` skill (single-task mode
   above) with the task block as the ticket. The skill runs
   its per-task TDD protocol and returns after its commit
   step.
4. Verify a commit landed via `git log -1 --format='%s'`. If
   none landed, abort with a message pointing at the task.
5. Flip every step inside the task block from `- [ ]` to
   `- [x]`, stage the plan file, and amend the task commit
   per ADR `<ADR_ID>-plan-walker-checkbox-commit.md`:

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
- Suggest `/octopus:pr-open` as the next step. Never open
  the PR automatically.

### Dispatch contract with `implement` (single-task mode)

- Input: a markdown block — the task header + its Files
  block + step list with code.
- Output: a commit matching the task's Step 5 (the TDD
  commit step).
- If the skill requires human input mid-task, pass it
  through untouched.

### Parsing rules

- Task header regex: `^## Task \d+:`.
- Checkbox toggle: inside a task block only, replace every
  `- [ ]` with `- [x]` (done) or vice versa (redo).
- Editing the plan **during** a running task is undefined
  behaviour; re-parse happens only between iterations.
````

Replace `<ADR_ID>` in Step 5 of the walker with the real ADR filename decided in Task 1 (e.g. `001-plan-walker-checkbox-commit`).

- [ ] **Step 3: Run the walker test**

Run: `bash tests/test_implement_plan_walker.sh`

Expected: all six tests PASS.

- [ ] **Step 4: Full regression**

```bash
for t in tests/test_*.sh; do
  if ! output=$(bash "$t" 2>&1); then
    echo "=== FAIL: $t ==="
    echo "$output" | tail -10
    exit 1
  fi
done
echo "=== ALL TESTS PASS ==="
```

Expected: `=== ALL TESTS PASS ===`.

- [ ] **Step 5: Commit**

```bash
git add commands/implement.md
git commit -m "$(cat <<'EOF'
feat(implement): add --plan walker mode

When invoked with --plan PATH, /octopus:implement walks the
plan file's ## Task N blocks top-to-bottom, dispatches the
existing single-task TDD protocol per task, pauses for
human review between tasks, and flips each task's
checkboxes in place. Per-task commits accumulate on the
current branch; walker never pushes, opens PRs, or creates
branches.

Checkbox-flip strategy (git amend vs separate commit)
captured in the ADR linked from the command body.

Co-authored-by: claude <claude@anthropic.com>
EOF
)"
```

---

## Task 4: Dog-food the walker on `bundle-diff-preview`

**Files:**
- Create: `docs/research/2026-04-21-plan-walker-dogfood.md`

- [ ] **Step 1: Produce a plan for `bundle-diff-preview`**

Run `/octopus:doc-plan bundle-diff-preview` (per the RM-036 command) to produce `docs/plans/bundle-diff-preview.md`. If `/octopus:doc-plan` is not yet registered as a slash command in the user's agent runtime, follow the plan-B pattern (read `commands/doc-plan.md` and execute the 7-step protocol inline). Commit the resulting plan on a dedicated `docs/bundle-diff-preview-plan` branch; do not merge it for this dog-food — the dog-food only consumes it.

- [ ] **Step 2: Switch to the plan's branch and run the walker for 2 tasks**

```bash
git checkout docs/bundle-diff-preview-plan
# /octopus:implement --plan docs/plans/bundle-diff-preview.md
# (the agent executes this via commands/implement.md walker mode)
```

Stop the walker at `s` after Task 2 finishes. Capture:

- The banner output printed between tasks.
- Files touched (`git log --name-only HEAD~2..HEAD`).
- Anything the walker did wrong or surprising (parsing bugs,
  wrong banner content, resume path).

- [ ] **Step 3: Write the dog-food report**

Create `docs/research/2026-04-21-plan-walker-dogfood.md` with:

```markdown
# Dog-food report — plan walker

**Date:** 2026-04-21
**Spec:** `docs/specs/implement-plan-walker.md` (RM-037)
**Plan exercised:** `docs/plans/bundle-diff-preview.md`
**Tasks executed:** 1 and 2 (of N)

## What worked

- <bullet list, filled from the session>

## What surfaced

- <issues, surprises, protocol gaps>

## Fixes applied before merging RM-037

- <list of command-file edits that went back into
  commands/implement.md, or 'none'>
```

- [ ] **Step 4: If the dog-food surfaced bugs, fix them now**

Edit `commands/implement.md` to address any issue. Re-run
`bash tests/test_implement_plan_walker.sh` (all tests PASS)
and the full suite to confirm no regression.

- [ ] **Step 5: Roll back the dog-food commits on the consumer branch**

The dog-food consumes `bundle-diff-preview` but does not
merge its implementation. Leave `docs/bundle-diff-preview-plan`
with its 2 walker commits intact — that branch is the
follow-up delivery for RM-027 and will be completed later.

Return to the RM-037 branch:

```bash
git checkout docs/implement-plan-walker-design
```

- [ ] **Step 6: Commit the dog-food report (plus any walker fixes)**

```bash
git add docs/research/2026-04-21-plan-walker-dogfood.md
# if commands/implement.md was fixed in Step 4:
git add commands/implement.md
git commit -m "$(cat <<'EOF'
docs(research): plan-walker dog-food against bundle-diff-preview

Captures the first two-task run of the walker. Any protocol
issues surfaced in the session are folded back into
commands/implement.md in the same commit.

Co-authored-by: claude <claude@anthropic.com>
EOF
)"
```

---

## Task 5: Move RM-037 to Completed + close Cluster 5

**Files:**
- Modify: `docs/roadmap.md`
- Modify: `docs/specs/implement-plan-walker.md`

- [ ] **Step 1: Remove RM-037 from the Cluster 5 Backlog**

Find and delete this block in `docs/roadmap.md`:

```markdown
- **RM-037** 🟡 Medium — extend `/octopus:implement` to
  consume a plan file (executing-plans equivalent). Today the
  skill codifies the TDD loop for a single task; this extends
  it to walk a checklist of tasks from `doc-plan`, with
  checkpoints for human review between tasks.
```

- [ ] **Step 2: Close Cluster 5 in the preamble**

Find the Cluster 5 entry-point paragraph and rewrite as:

```markdown
Cluster 5 is complete. All three legs of the
design → plan → execute loop ship inside Octopus: RM-035
(`/octopus:doc-design`), RM-036 (`/octopus:doc-plan`), and
RM-037 (`/octopus:implement --plan`).
```

- [ ] **Step 3: Append RM-037 to the Completed table**

Add at the bottom of `docs/roadmap.md`:

```markdown
| RM-037 | `/octopus:implement` gains a `--plan` walker mode that executes a plan file task-by-task, dispatching the existing single-task TDD loop per task, pausing for human review between tasks, flipping checkboxes in place for resume, and closing Cluster 5 | completed → [Spec](specs/implement-plan-walker.md) | 2026-04-21 |
```

- [ ] **Step 4: Flip the spec Status**

```bash
sed -i 's/\*\*Status\*\* | Draft/\*\*Status\*\* | Implemented (2026-04-21)/' docs/specs/implement-plan-walker.md
```

- [ ] **Step 5: Full regression**

```bash
for t in tests/test_*.sh; do
  if ! output=$(bash "$t" 2>&1); then
    echo "=== FAIL: $t ==="
    echo "$output" | tail -10
    exit 1
  fi
done
echo "=== ALL TESTS PASS ==="
```

Expected: `=== ALL TESTS PASS ===`.

- [ ] **Step 6: Commit**

```bash
git add docs/roadmap.md docs/specs/implement-plan-walker.md
git commit -m "$(cat <<'EOF'
docs(roadmap): mark RM-037 completed; close Cluster 5

/octopus:implement --plan walker shipped. Octopus now owns
the full design → plan → execute loop; superpowers parity
complete for Cluster 5.

Co-authored-by: claude <claude@anthropic.com>
EOF
)"
```
