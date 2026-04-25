# Design: Natural Language Pipeline Builder

| Field | Value |
|---|---|
| **Date** | 2026-04-25 |
| **Author** | Leonardo Costa |
| **Status** | Approved |
| **Roadmap** | TBD (new RM) |

## Problem Statement

Octopus can run multi-agent pipelines via `octopus run <plan.md>`, but defining a pipeline requires manually writing YAML frontmatter with `agent:`, `depends_on:`, and `skill:` fields. This creates friction for ad-hoc, exploratory workflows — especially when the user wants to describe a sequence like "tech-writer creates a spec, product-manager reviews it, then two specialists implement it, and staff-engineer does a final review before merging."

There is no way to express this intent naturally from the TUI without leaving it to write a plan file.

## Goals

- Allow users to define a multi-agent pipeline directly in the `octopus control` TUI using an interactive visual builder.
- Support pre-filling the builder from natural language input with `@mentions`.
- Support parallel steps (same step number = same dependency tier).
- Support human-approval gates (`wait=true`) per step, inferred semantically or set explicitly.
- Support system actions (`@system`) for git operations like merge-to-develop.
- Introduce a new `staff-engineer` role (architect + code reviewer).
- Persist pipeline state to `.octopus/pipelines/` for resumability after TUI restart.

## Non-Goals

- A fully autonomous NL-to-pipeline system with no human review (approach rejected in favour of interactive builder).
- Multi-machine or distributed pipeline execution.
- `@system` deploy actions beyond git operations (deploy is handled by CI/CD automatically after push).
- Replacing `octopus run <plan.md>` for pre-defined, committed pipelines.

## Design

### 1. Activation

The pipeline builder is opened from the TUI command bar in two ways:

- **Keybinding:** pressing `[p]` while the command bar is focused opens the builder in empty state.
- **`@` trigger:** typing `@` as the first character of the command bar input displays a hint: `"Pipeline mode? [p] to open builder"`. If the user continues typing a full `@mention`-rich description and presses `[p]`, the builder opens pre-filled.

The builder replaces the output panel in the TUI layout while active. Pressing `[Esc]` cancels and restores the output panel.

### 2. Pipeline Builder UI

The builder renders a list of editable step rows:

```
┌─ Pipeline Builder ──────────────────────────────────────────────────┐
│  #  Agent               Wait  Prompt                                │
│  1  @tech-writer        [ ]   create a spec for lesson plans        │
│  2  @product-manager    [x]   review and validate the spec          │
│  3  @frontend-spec      [ ]   implement UI                          │
│  3  @backend-spec       [ ]   implement API          ← parallel     │
│  4  @staff-engineer     [x]   architecture + code review            │
│  5  @system             [ ]   merge to develop                      │
│                                                                     │
│  [a]dd  [d]elete  [j/k] move  [tab] next field  [p]ush to queue    │
└─────────────────────────────────────────────────────────────────────┘
```

**Step fields:**

| Field | Type | Description |
|---|---|---|
| `#` | integer | Execution tier. Same number = parallel. |
| `Agent` | string | `@role-name` or `@system` |
| `Wait` | bool | Pause for human approval before next tier executes |
| `Prompt` | string | Task description sent to the agent |

**Navigation:**
- `j / k` — move cursor between steps
- `a` — append new step (copies current step's `#` + 1)
- `d` — delete focused step
- `Enter` — edit the focused field
- `Tab` — advance to next field in current step
- `Shift+Tab` — previous field
- `p` — confirm and push pipeline to queue
- `Esc` — cancel, return to normal TUI

Steps sharing the same `#` are dispatched in parallel via the existing `PipelineRunner` DAG executor. Steps with a higher `#` only start after all steps of the previous tier are `done`.

### 3. NL Pre-fill

When the user pastes a natural language description with `@mentions` into the command bar and opens the builder with `[p]`, the system pre-fills steps using a **deterministic regex parser** (no API call):

**Parser rules:**

1. Split input on `@role-name` boundaries.
2. Each segment following a `@mention` becomes that step's prompt.
3. **`wait` inference:** if the segment contains any of `["revise", "review", "valide", "validate", "approve", "aprove", "aprova"]`, set `wait=true`.
4. **Parallelism inference:** if two consecutive `@mentions` are joined by `["e", "and", "simultane", "em paralelo", "in parallel"]`, assign them the same `#`.
5. **Ambiguous steps:** steps where the parser cannot resolve the step number are highlighted in yellow with `?` in the `#` field, indicating the user should set it manually.

**Haiku fallback:** Ambiguous steps (yellow `?`) show an `[i]nfer with AI` action. Pressing it sends only the ambiguous segment to `claude-haiku-4-5-20251001` with a structured prompt asking for step number and wait inference. The model can be overridden in `.octopus.yml`:

```yaml
pipeline_model: claude-haiku-4-5-20251001
```

### 4. `@system` Action

`@system` is a special agent that runs a configured shell script instead of launching a Claude Code process. Octopus ships a built-in `merge_to_develop` action. Additional actions can be defined or overridden in `.octopus.yml`:

```yaml
system_actions:
  merge_to_develop: "git checkout develop && git merge --no-ff {branch} && git push origin develop"
  # additional custom actions here
```

If `system_actions` is absent from `.octopus.yml`, only the built-in actions are available. Referencing an undefined action name pauses the pipeline with an error before execution.

`{branch}` is replaced at runtime with the worktree branch of the last agent that ran in the pipeline.

The `PipelineRunner` detects `agent: system`, skips `ProcessManager.launch()`, and executes the script via `subprocess.run()`. Exit code 0 = success; non-zero = pipeline pauses with an error state (no `[s]kip` available for system actions).

### 5. Failure Handling

When a step fails (agent exit code ≠ 0, or user rejects a `wait` gate):

- The pipeline pauses and the failed step is highlighted in red.
- The TUI shows: `[r]etry  [s]kip  [a]bort`
  - `[r]etry` — re-enqueues the same step from the beginning.
  - `[s]kip` — marks the step as `skipped` and advances to the next tier (not available for `@system` steps).
  - `[a]bort` — cancels the entire pipeline; remaining steps are set to `cancelled`.
- Pipeline state is persisted after each step transition. On TUI restart, in-progress pipelines are listed and can be resumed.

### 6. Role: `staff-engineer`

New role file: `roles/staff-engineer.md`

**Persona:** Staff Engineer and Software Architect. Responsible for architectural integrity, code quality, and technical decision-making on high-impact changes.

**Responsibilities:**
- Code review focused on architecture, cohesion, coupling, and project patterns
- Challenges design decisions that create technical debt or contradict existing ADRs
- Validates that spec acceptance criteria are met by the implementation
- Cross-stack perspective: reviews contracts between frontend and backend, not just individual layers

**Approval criteria (all must pass before signing off):**
- Tests pass and meaningful coverage exists for the changed paths
- No critical security issues (auth bypass, injection, secrets in code)
- Architecture is coherent with existing patterns and ADRs
- No god objects, premature abstractions, or copy-paste code in changed files

**Default model:** `claude-opus-4-7` — architectural review justifies the most capable model.

**Distinction from other roles:**
- `backend-specialist` / `frontend-specialist` — implement; `staff-engineer` — reviews and questions
- `product-manager` — validates product behaviour; `staff-engineer` — validates technical quality

### 7. Pipeline Persistence

Each pipeline is written to `.octopus/pipelines/<timestamp>-<name>.yml` with full step state:

```yaml
id: "20260425-143012"
name: "lesson-plans-feature"
created_at: "2026-04-25T14:30:12Z"
status: running  # waiting | running | paused | done | aborted
tasks:
  - id: t1
    tier: 1
    agent: tech-writer
    prompt: "create a spec for lesson plans..."
    wait: false
    status: done   # waiting | running | done | skipped | failed | cancelled
  - id: t2
    tier: 2
    agent: product-manager
    prompt: "review and validate the spec"
    wait: true
    status: waiting
```

`.octopus/pipelines/` is added to `.gitignore` (runtime state, not committed).

### 8. Data Flow

```
User types NL in command bar
         │
         ▼
   NL Parser (regex)
   ├── clear cases → pre-filled steps
   └── ambiguous   → yellow ? + [i]nfer option (Haiku 4.5)
         │
         ▼
  Pipeline Builder TUI
  (user reviews, edits, confirms)
         │
         ▼
  Serialize to .octopus/pipelines/<ts>.yml
         │
         ▼
  PipelineRunner (existing DAG executor)
  ├── @role steps  → ProcessManager.launch()
  └── @system steps → subprocess.run(script)
         │
         ▼
  Per-step: done → advance tier | failed → pause + retry/skip/abort
```

## Implementation Plan (high-level)

1. `roles/staff-engineer.md` — new role file
2. `cli/control/nl_parser.py` — regex-based `@mention` + wait + parallelism parser
3. `cli/control/pipeline_builder.py` — Textual widget: step list, keyboard nav, field editing
4. `cli/control/app.py` — wire `[p]` keybinding to open `PipelineBuilder` widget
5. `cli/control/pipeline.py` — extend `PipelineRunner` to handle `agent: system` steps
6. `tests/test_nl_parser.py` — unit tests for all parser rules and edge cases
7. `tests/test_pipeline_builder.py` — unit tests for step serialization and YAML output
8. `tests/test_pipeline_runner_system.sh` — integration test for `@system` step execution

## Testing

**Unit (Python):**
- `test_nl_parser.py`: `@mention` detection, prompt extraction, `wait` inference (positive and negative vocabulary), parallelism inference, ambiguous step marking
- `test_pipeline_builder.py`: add/remove steps, wait toggle, step renumbering, YAML serialization round-trip

**Integration (bash):**
- `test_pipeline_runner_system.sh`: `@system` step runs correct script; non-zero exit pauses pipeline
- `test_staff_engineer_role.sh`: role loaded correctly by `ProcessManager`, model resolves to opus

**TUI snapshots (Textual pilot):**
- Builder empty state
- Builder pre-filled from NL input
- Step in error state (red highlight)
- Merge confirmation step
