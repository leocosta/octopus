---
name: doc-plan
description: Turn a completed spec into a bite-sized, TDD-style implementation plan under docs/plans/<slug>.md
---

---
description: Turn a completed spec into a bite-sized, TDD-style implementation plan under docs/plans/<slug>.md
agent: code
---

# /octopus:doc-plan

## Purpose

Read `docs/specs/<slug>.md` (produced by `/octopus:doc-spec`
and filled via `/octopus:doc-design`) and write
`docs/plans/<slug>.md` — a bite-sized plan whose tasks follow
the `superpowers:writing-plans` vocabulary so existing
executors (`superpowers:executing-plans`,
`superpowers:subagent-driven-development`, and the future
`/octopus:implement --plan` walker in RM-037) consume it
directly.

## Usage

```
/octopus:doc-plan <slug>
```

- Chained from `/octopus:doc-design` — the design command
  suggests `/octopus:doc-plan <slug>` in its final message.
- Runs standalone against any spec whose `## Implementation
  Plan` section is populated.

## HARD-GATE

**HARD-GATE:** this command does not write production code,
does not write tests, does not create implementation
branches, and does not dispatch any implementation skill.
The terminal state is a committed plan file in
`docs/plans/<slug>.md`. Any request during the session that
drifts into implementation (writing code, writing tests,
creating a feature branch to code on) must be declined —
redirect the user to `/octopus:implement --plan` (RM-037)
once the plan is merged.

**Docs-only branches are permitted** (and expected when the
current branch is `main` or `master`). Step 6 creates
`docs/<slug>-plan` solely to carry the plan commit, so the
change still lands via PR rather than directly on `main`.

## Instructions

### Step 1 — Setup + coverage check

1. Resolve `<slug>`:
   - If `$ARGUMENTS` contains a slug, use it (kebab-case).
   - Otherwise ask: "What slug are we planning? (kebab-case)".
2. Resolve `docs/specs/<slug>.md`. If it does not exist,
   abort with:
   `Spec not found at docs/specs/<slug>.md. Run /octopus:doc-spec <slug> first.`
3. Read the spec's `## Implementation Plan` section. If the
   section is empty or still contains `<!--` placeholders,
   abort with:
   `Implementation Plan is empty in docs/specs/<slug>.md. Run /octopus:doc-design <slug> to populate it before planning.`
4. Count the high-level items as `P1..PN`. Store them in
   order.

### Step 2 — Context scan (silent)

Read silently, without asking the user a question:

- `git log --oneline -20` — recent activity.
- The spec's Metadata block (Roadmap, Author, Date).
- The spec's Overview, Detailed Design, Testing Strategy,
  and Implementation Plan — the header + file structure the
  plan will emit come from these.
- `skills/doc-plan/templates/plan-skeleton.md` — the frozen
  output format. Read it into memory; emit plan text that
  matches it structurally.

Report in one line: `"Scanned N commits + spec
(N Implementation Plan items). Let's plan."`

### Step 3 — Plan header + File Structure draft

1. Derive from the spec:
   - **Goal** — one sentence, from the spec's Overview.
   - **Architecture** — 2–3 sentences, from the spec's
     Detailed Design.
   - **Tech Stack** — from the spec's Context for Agents
     `Constraints` block (e.g. "Pure bash, no external
     deps").
   - **Spec link** — `docs/specs/<slug>.md`.
   - **File Structure table** — one row per file mentioned
     across the spec's Implementation Plan items.
2. Show the header + File Structure table draft.
3. Ask: `"Looks right? (y / revise / skip)"`.
4. On `y` — write into the in-memory plan buffer.
5. On `revise` — ask a clarifying question, redraft.
6. On `skip` — emit a minimal header (Goal + Spec link
   only), no File Structure table.

### Step 3b — Pipeline frontmatter generation

After the user approves the File Structure (Step 3), generate the `pipeline:` frontmatter block:

1. Assign each plan item an `id`: `t1`, `t2`, ... in order.
2. Infer `agent` from task keywords:
   - migration, schema, model, query, endpoint, API, service → `backend-specialist`
   - component, screen, page, UI, form, style → `frontend-specialist`
   - doc, spec, README, changelog, ADR → `tech-writer`
   - review, audit, security, check → `reviewer`
   - (no match) → `backend-specialist`
3. Infer `depends_on` using these rules:
   - Sequential tasks of the same agent always depend on their immediate predecessor (e.g., if backend-specialist has t1 and t3, then t3 depends on t1).
   - Cross-agent: if a task consumes the output of another agent's task (e.g., a UI task that builds on a completed API), it depends on that agent's last task. When unsure, leave `depends_on: []` and let the user adjust.
   - Tasks with no shared context with any previous task start with `depends_on: []`.
4. Show the generated frontmatter block. Ask: `"Pipeline routing looks right? (y / revise)"`.
5. On `y` — prepend the frontmatter to the plan buffer before writing.
6. Inline each task `id` into the plan body as `**t1**`, `**t2**`, etc. in the checkbox lines: `- [ ] **t1** — <original task description>`.

Agent inference is a starting point — users are expected to adjust `agent` and `depends_on` in the plan file before running `octopus control --plan`.

### Step 4 — Task decomposition (adaptive)

For each `P_i` in `P1..PN`:

1. Default mapping — one `Task_i` with 5 steps:
   - Step 1: Write the failing test (code block shown).
   - Step 2: Run test to verify it fails (`Run:` + `Expected: FAIL`).
   - Step 3: Write minimal implementation (code block shown).
   - Step 4: Run test to verify it passes (`Run:` + `Expected: PASS`).
   - Step 5: Commit (`git add` + `git commit -m`).
2. Heuristic "**too big**" — trigger when either:
   - `P_i` touches ≥ 3 files, OR
   - `P_i` description mentions `rewrite`, `refactor`,
     `full`, `introduce`, or ≥ 3 distinct verbs.

   When triggered: ask `"P_i looks big (<signal>); break into
   <N> tasks? (y/n/custom)"`. On `y`, propose a split
   (usually by file or by logical unit); user confirms per
   sub-task.
3. Heuristic "**too small**" — trigger when all:
   - `P_i` touches exactly 1 file, AND
   - `P_i` description is ≤ 10 words, AND
   - the previous task already touches related code.

   When triggered: ask `"P_i is trivial — fold into
   previous task? (y/n)"`. On `y`, append `P_i`'s change as
   an extra step in `Task_{i-1}`.
4. Produce the task(s) following the skeleton. Show the
   draft. Approve / revise.

### Step 5 — Self-review (silent)

Scan the buffered plan for:

- Placeholder red flags: `TBD`, `TODO`, `handle edge cases`,
  `add validation appropriately`, `similar to Task N`.
  Rewrite inline.
- Name / type consistency — a function or flag mentioned in
  one task must appear with identical spelling in all
  others.
- **Spec coverage** — every item in the spec's
  Implementation Plan has at least one task. If a coverage
  gap is detected, emit a warning to stderr naming the
  uncovered item (do NOT abort — the user may have
  intentionally folded or dropped it).
- **Plan size** — when total task count exceeds 15, emit a
  warning suggesting a split:
  `Plan has <N> tasks; consider splitting into
  docs/plans/<slug>-part1.md / -part2.md.` The user decides.

### Step 6 — Ensure docs-only branch + write + commit

1. Ensure `docs/plans/` exists; create it if missing.
2. Write the buffered plan to `docs/plans/<slug>.md`. If
   the file already exists, prompt:
   `docs/plans/<slug>.md exists. Overwrite? (y/N)`.
   On `N`, abort with no changes.
3. Before committing — if the current branch is `main` or
   `master`, create `docs/<slug>-plan`:

   ```bash
   current_branch=$(git rev-parse --abbrev-ref HEAD)
   if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
     git checkout -b "docs/<slug>-plan"
   fi
   ```

   Never commit the plan directly onto `main` or `master`.
4. Commit:

   ```bash
   git add docs/plans/<slug>.md
   git commit -m "docs(plans): <slug> — bite-sized plan from /octopus:doc-plan

   Co-authored-by: claude <claude@anthropic.com>"
   ```

### Step 7 — Close

Print:

```
Plan ready at docs/plans/<slug>.md
(branch: docs/<slug>-plan).

Open a PR for review, then — once merged — execute with:
  /octopus:implement --plan docs/plans/<slug>.md
    (available once RM-037 ships)

Or run superpowers:executing-plans or
superpowers:subagent-driven-development against
docs/plans/<slug>.md.
```

STOP. Do not execute the plan, do not open the PR
automatically, do not dispatch another skill. See the
HARD-GATE section above.

## Idempotency

Re-running `/octopus:doc-plan <slug>` on a spec whose plan
already exists prompts before overwriting (Step 6.2). The
user can run the session again to refine a plan without
risking an accidental overwrite.
