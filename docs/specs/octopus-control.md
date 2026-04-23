# Spec: Octopus Control

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-22 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **RFC** | N/A |
| **Roadmap** | RM-044 |

## Problem Statement

Teams running multiple AI agents today have no local coordination layer
without depending on external SaaS platforms (Paperclip, etc.) or GitHub
Actions. Octopus configures agents at setup-time but has no runtime
layer: there is no way to launch multiple agents in parallel, queue tasks
for them, schedule recurring runs, or observe their output — all from a
single terminal session without a web browser or cloud account.

## Goals

- `octopus control` opens a TUI dashboard showing all configured agents,
  their running status, and live output.
- Tasks can be submitted to any agent from the TUI and queued for
  execution.
- A scheduler triggers tasks on cron-style intervals or on git events
  (push, PR open) without manual invocation.
- Multiple agents run simultaneously in isolated git worktrees.
- All state (queue, schedule, logs) is stored locally in `.octopus/`
  and is git-trackable.
- No web server, no HTML, no GitHub Actions, no cloud account required.

## Non-Goals

- Multi-machine / distributed execution.
- A GUI or web dashboard.
- Budget tracking and hard cost limits (secondary, deferred to v2).
- Immutable audit log with cryptographic guarantees (secondary, deferred).
- Support for agents other than Claude Code in v1.
- Replacing `.octopus.yml` manifest or any existing delivery mechanism.

## Design

### Overview

`octopus control` is a TUI dashboard (Python/textual) that acts as a local
control plane for AI agents configured by Octopus.

Four panels share the screen: agent roster (left), task queue (top-right),
scheduler (bottom-right), and a live output strip (bottom). Navigation is
keyboard-only; no mouse required.

Each agent runs as an isolated Claude Code process in a dedicated git
worktree under `.octopus/worktrees/<role>/`. A PID file at
`.octopus/pids/<role>.pid` tracks the process; the TUI polls it every
second to update status.

The task queue persists as JSON files in `.octopus/queue/` (one file per
task, named `<timestamp>-<role>.json`). The scheduler runs as a background
thread inside the TUI process, reading `.octopus/schedule.yml` on startup
and re-reading it when the file changes (inotify / polling fallback).

On exit (`q`), if any agent is running the user is prompted:
`[s] stop agents and exit   [d] detach (keep running)   [c] cancel`.
Detached processes are reconnected automatically on the next
`octopus control` invocation by reading the existing PID files.

### Detailed Design

#### Task Submission

Pressing `[a]` opens an inline prompt bar at the bottom of the TUI.
Input is interpreted in three modes, evaluated in order:

1. **Slash command** — `/skill-name [args] [--model <model>]`
   e.g. `/audit-all`, `/security-scan src/auth/ --model opus`.
   Maps directly to the Octopus skill of that name. The skill's `SKILL.md`
   is injected as the Claude Code session prompt. `--model` overrides model
   resolution for this task only.

2. **Natural language** — free text run through the existing trigger-matching
   engine (same keyword + path scoring used in lazy skill activation).
   Matching rule: if exactly one skill has at least one keyword or path hit,
   it is proposed: `"Matched: security-scan — confirm? [y/n]"`. If two or
   more skills match, a fuzzy picker lists them. If none match, the text
   becomes a raw instruction. No numeric threshold — match presence is
   binary per skill.

3. **Raw instruction** — unmatched free text sent verbatim as the Claude Code
   prompt with no skill wrapper.

Model resolution runs before the task is queued, in priority order:

1. `--model <value>` flag on the slash command or NL input.
2. `model:` field in the skill's `SKILL.md` frontmatter (if present).
3. `model:` field in the role's frontmatter (already defined for most roles).
4. Global default: `sonnet`.

The resulting task is written to `.octopus/queue/<ts>-<role>.json`:

```json
{
  "id": "<ts>",
  "role": "backend-specialist",
  "skill": "security-scan",
  "model": "claude-sonnet-4-6",
  "prompt": "<resolved text>",
  "status": "queued",
  "created_at": "<iso8601>"
}
```

`model` is always stored as the resolved full model ID (e.g.
`claude-opus-4-7`) so the queue entry is self-contained and reproducible
regardless of later default changes.

#### Process Manager

Each agent session is a Claude Code subprocess launched in a dedicated worktree:

```bash
git worktree add .octopus/worktrees/<role> -b octopus/<role>/<ts>
claude --model <resolved-model> --print "<prompt>" \
  > .octopus/logs/<role>.log 2>&1 &
echo $! > .octopus/pids/<role>.pid
```

`<resolved-model>` comes from the task's `model` field (already resolved
at enqueue time via the priority chain above).

stdout/stderr are tailed into the TUI output panel via a background reader
thread. On task completion (process exits 0), status is updated to `done`;
non-zero exit → `failed`. The worktree is pruned after success; kept on
failure for inspection.

On TUI exit with running agents the user is prompted:
`[s] stop agents and exit   [d] detach (keep running)   [c] cancel`.
Detached processes are reconnected on the next `octopus control` invocation
by reading existing PID files.

#### Scheduler

`.octopus/schedule.yml` schema:

```yaml
- id: s1
  when: "daily 09:00"       # cron-style or "on: push"
  role: backend-specialist
  skill: security-scan      # or prompt: "..."
  enabled: true
```

The scheduler thread evaluates `when` expressions using a pure-Python cron
parser (no external lib). Git-event triggers (`on: push`) hook into the
existing pre-push git hook installed by Octopus.

#### TUI Layout (textual)

```
┌─ Agents ──────────┐ ┌─ Queue ──────────────────────┐
│ ● backend-spec    │ │ ▶ security-scan       2m     │
│ ○ tech-writer     │ │ ○ doc-design          queued │
└───────────────────┘ └──────────────────────────────┘
┌─ Output ── backend-specialist ───────────────────────┐
│ 10:42:01  Reading src/auth/middleware.ts...          │
│ 10:42:07  ✓ 4 tests passed                          │
└──────────────────────────────────────────────────────┘
┌─ Schedule ───────────────────────────────────────────┐
│ ◷ daily 09:00   security-scan   backend-specialist  │
└──────────────────────────────────────────────────────┘
[a]dd  [p]ause  [k]ill  [tab] focus  [q]uit
```

Components: `AgentRoster` (DataTable), `TaskQueue` (ListView),
`OutputPanel` (RichLog), `SchedulePanel` (DataTable),
`CommandBar` (Input, shown on `[a]`).

### Migration / Backward Compatibility

`octopus control` is an entirely new subcommand. All existing Octopus
commands, manifests, and delivery artifacts are untouched. Users who do
not invoke `octopus control` see no change.

The only shared state is `.octopus/` directory, which already exists for
the CLI lock file. New subdirectories (`queue/`, `schedule.yml`, `logs/`)
are added inside it.

## Implementation Plan

1. **`cli/lib/control.sh` + `cli/octopus.sh` routing**
   New `octopus control` subcommand sourced by `octopus.sh`. Checks for
   Python 3 and `textual`; offers `--install-deps` to install via pip.
   Dependencies: none.

2. **`cli/control/process_manager.py`**
   Functions: `launch(role, prompt)`, `kill(role)`, `adopt_orphans()`,
   `tail_log(role) → AsyncGenerator`. Manages worktrees, PID files, and
   log files under `.octopus/`.
   Dependencies: step 1.

3. **`cli/control/queue.py`**
   `TaskQueue`: `enqueue()`, `dequeue()`, `list_all()`, `update_status()`.
   Persists to `.octopus/queue/<ts>-<role>.json`.
   Dependencies: step 2.

4. **`cli/control/skill_matcher.py`**
   Reads `triggers:` and `model:` from each `SKILL.md` frontmatter; scores
   user input by keyword/path match. Resolves slash commands (`/skill-name
   [--model <m>]`) and natural language → skill + confirmation prompt.
   Runs model resolution (explicit flag → skill frontmatter → role
   frontmatter → `sonnet` default) and returns the full model ID alongside
   the resolved prompt.
   Dependencies: step 3.

5. **`cli/control/scheduler.py`**
   Background thread reading `.octopus/schedule.yml`; pure-Python cron
   parser. Emits tasks to queue on schedule; supports `on: push` via a
   flag file written by the existing pre-push hook.
   Dependencies: steps 3–4.

6. **`cli/control/app.py`** (TUI — textual)
   `App` with `AgentRoster`, `TaskQueue`, `OutputPanel`, `SchedulePanel`,
   `CommandBar`. PID polling every 1 s via `set_interval`; log tailing via
   async worker. Keybindings: `a p k tab q`. Exit prompt (`s/d/c`) when
   agents are running.
   Dependencies: steps 2–5.

7. **`tests/test_control.sh` + `tests/test_skill_matcher.py`**
   Bash: subcommand routing, `--install-deps`, PID adopt-orphans.
   Python: unit tests for skill_matcher (slash, NL, raw), queue
   round-trip, scheduler cron parser.
   Dependencies: steps 1–6.

## Context for Agents

**Knowledge modules**: none new
**Implementing roles**: `backend-specialist` (process manager, scheduler — bash/Python), `tech-writer` (docs)
**Related ADRs**: N/A
**Skills needed**: `implement`, `debugging`
**Bundle**: `starter` (existing) — no new bundle needed; `octopus control` is a CLI feature, not a skill

**Constraints**:
- Python 3 only (already an Octopus dependency); `textual` is the single new pip dependency
- Pure local execution — no network calls from the TUI itself
- `.octopus/queue/` and `.octopus/schedule.yml` must be git-trackable (text formats)
- Process manager must clean up orphan processes on TUI exit
- Must work in terminals without mouse support (keyboard-only navigation)

## Testing Strategy

**Unit (Python):**
- `skill_matcher`: slash → skill, NL → match + confirm, NL → no match → raw,
  ambiguous → picker shown. Model resolution: explicit flag wins, then skill
  frontmatter, then role frontmatter, then default. Input: mock `SKILL.md`
  frontmatter; no Claude call.
- `queue`: enqueue/dequeue round-trip, status transitions, concurrent writes
  (two enqueues at same millisecond → distinct files).
- `scheduler`: cron parser (`"daily 09:00"`, `"Mon 08:00"`, `"on: push"`),
  next-fire-time calculation, `enabled: false` → no emit.

**Integration (bash — `tests/test_control.sh`):**
- Subcommand routes correctly (`octopus control --help` exits 0).
- `--install-deps` installs textual into a venv without error.
- `adopt_orphans` picks up a manually written PID file pointing to a live
  sleep process.
- Queue file is created on enqueue and removed on dequeue.

**Manual / dog-food:**
- Run `octopus control` in the Octopus repo itself; submit `/security-scan`
  via `[a]`; verify Claude Code launches in a worktree and output appears
  in the panel.
- Schedule a task for "in 1 minute"; verify it fires.
- Kill TUI mid-run with `[q]` → choose detach; reopen → agent reconnects.

## Risks

1. **Orphan processes** — if the TUI crashes before writing the detach flag,
   Claude Code processes remain running with no reconnect handle.
   Mitigation: write `.octopus/pids/<role>.pid` before launching; on
   startup, always scan PIDs and adopt any live processes found.

2. **NL confidence threshold** — natural language matching may select the
   wrong skill silently. Mitigation: always show the matched skill and
   require explicit confirmation before submitting; never auto-submit
   without `y/n`.

3. **Worktree accumulation** — failed tasks keep their worktree for
   inspection, but users may forget to clean them up.
   Mitigation: TUI shows worktree count and size; `[k]ill` prompts to
   prune the associated worktree.

4. **textual version coupling** — textual is a fast-moving library; API
   breaks between minor versions are common.
   Mitigation: pin textual version in a requirements file;
   expose `octopus control --install-deps` for first-run setup.

5. **Single-agent-per-role constraint** — the process manager runs one
   Claude Code session per role. A second task for the same role is
   queued, not parallelised.
   Mitigation: document clearly; v2 can add role instance numbering
   (`backend-specialist-1`, `backend-specialist-2`).

## Changelog

- **2026-04-22** — Initial stub created
- **2026-04-22** — Design session completed
- **2026-04-22** — Added flexible model resolution (explicit flag → skill frontmatter → role frontmatter → default)
