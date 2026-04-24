# Design: Octopus Control & Run UX Overhaul

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-24 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **Roadmap** | RM-054 (proposed) |

## Problem Statement

`octopus run` and `octopus control` ship but don't feel usable in practice. Three concrete gaps:

1. **No streaming feedback** — `pipeline.py` emits nothing to stdout while running. Users stare at a blank terminal with no signal that anything is happening.
2. **Delegation is not natural** — there is no way to say "tech-writer, write this ADR" without navigating the agents table and manually selecting a role before typing a command. The `@role` concept doesn't exist.
3. **Multi-agent visibility** — when several agents run in parallel, only the most recently dispatched agent's log appears in the Output panel. There is no way to glance at what other agents are doing without losing focus on the current one.

## Goals

- `octopus ask <role> "<task>"` dispatches a task to a specific agent and streams its output live in the terminal — no TUI required.
- `Ctrl+C` during streaming offers kill or detach; detached agents are visible in `octopus control` immediately.
- In the TUI, selecting an agent and pressing Enter (or `a`) prefills the command bar with `@role:` so delegation is one gesture.
- `@role: task` syntax in the command bar is parsed and routes the task to that role regardless of cursor position.
- The agents table shows the last output line of each agent inline as a mini-feed, so users can monitor all parallel agents without switching panels.
- Clicking (or pressing Enter on) an agent in the roster focuses the Output panel on that agent's log.
- `pipeline.py` emits structured progress lines to stdout (`task started`, `task done`, `task failed`) so `octopus run` gives live feedback during pipeline execution.

## Non-Goals

- Split-view output (multiple Output panels side by side) — the mini-feed covers the monitoring need without the complexity.
- Real-time log merging across agents in a single stream — each agent keeps its own log.
- Replacing `octopus run` with a fully interactive pipeline wizard.
- Budget tracking or cost estimates per task.

## Design

### `octopus ask` — Terminal-First Delegation

New command: `octopus ask <role> "<task>" [--skill <skill>] [--model <model>]`

```bash
octopus ask tech-writer "write ADR for JWT authentication"
octopus ask backend-specialist "run security-scan on src/auth/"
octopus ask tech-writer "write ADR" --skill octopus:doc-adr
```

**Output format:**

```
◆ tech-writer · write ADR for JWT authentication
──────────────────────────────────────────────────
10:02:01  Reading docs/specs/user-auth.md...
10:02:04  Checking existing ADRs in docs/adr/...
10:02:07  Creating docs/adr/0012-jwt-authentication.md
10:02:09  Writing context section...
⠙ running  0m22s▋

──────────────────────────────────────────────────
✓ done  0m31s
  log: .octopus/logs/tech-writer.log
```

**Failure:**
```
✗ failed  0m18s  ·  exit code 1
  log: .octopus/logs/tech-writer.log
  → octopus ask tech-writer "..." --retry
```

**`Ctrl+C` behaviour:** prompts `[k]ill  [d]etach`. Detach leaves the agent running; its PID file remains at `.octopus/pids/tech-writer.pid` so `octopus control` adopts it on next launch.

**Implementation:** `cli/lib/ask.sh` — thin bash wrapper that:
1. Validates `<role>` is a known role (reads `agents/` directory).
2. Calls `ProcessManager.launch()` via a new Python helper `cli/control/ask.py`.
3. Tails `.octopus/logs/<role>.log` to stdout until the process exits.
4. Prints the summary line on completion.

### TUI: `@role` Delegation + Prefill

**`@role:` prefix in command bar:**

The `SkillMatcher.resolve()` method gains a pre-parse step: if input starts with `@<word>:`, extract the word as an explicit role override and strip it from the skill/NL resolution input. The resolved role overrides the cursor-selected role in the agents table.

```python
# Before: enqueue with _selected_role()
# After:  if text starts with @role:, parse and override
```

**Prefill on Enter in agents table:**

`on_data_table_row_selected` (new handler) checks if the selected agent is idle. If idle, opens the command bar and prefills `@<role>: ` (with cursor positioned after the colon). If running, focuses the Output panel on that agent's log (existing select behaviour).

**Result:** the user presses `↑↓` to navigate agents, then `Enter` to either delegate (idle) or focus output (running) — no mode confusion.

### TUI: Mini-Feed in Agents Table

The agents table gains a fourth visual column (no DataTable column — rendered via markup in the Status cell) showing the last line of the agent's log file, truncated to fit the panel width.

`_refresh_roster()` reads the last line of `.octopus/logs/<role>.log` on each poll cycle and appends it dimmed after the elapsed time:

```
⠙ tech-writer    0m22s  [dim]Writing ADR decision rationale…[/dim]
⠋ backend-spc    1m50s  [dim]Found 3 issues in auth/[/dim]
```

On focus, the Output panel switches to that agent's full log.

### TUI: Click Agent → Focus Output

`on_data_table_row_highlighted` (Textual event fired on cursor move) updates the Output panel to stream the highlighted agent's log. The output panel `border_title` updates to `Output · <role> · live` or `Output · <role> · ✓ done` accordingly.

This replaces the current model where output only updates when a new task is dispatched — now navigating the roster changes the visible log in real time.

### Pipeline Progress Lines

`pipeline.py` gains structured stdout output throughout `run()`:

```python
# On task dispatch:
print(f"  → {task.id}  {task.agent}  {task.body[:60]}")

# On task completion:
elapsed = int(time.time() - start)
icon = "✓" if task.status == "done" else "✗"
print(f"  {icon} {task.id}  {task.agent}  {elapsed}s")

# On pipeline complete:
print(f"\n{'✓ pipeline done' if success else '✗ pipeline failed'}  {total_elapsed}s")
```

`octopus run` passes these through to the terminal, so the user sees task-level progress without opening the TUI:

```
→ t1  backend-specialist  Create users table and migration
✓ t1  backend-specialist  42s
→ t2  backend-specialist  Implement auth endpoints
→ t3  frontend-specialist  Login screen and registration form
✓ t3  frontend-specialist  78s
✓ t2  backend-specialist  94s
→ t4  tech-writer  Document auth API
✓ t4  tech-writer  31s

✓ pipeline done  245s
```

## Implementation Plan

1. **`cli/control/ask.py` + `cli/lib/ask.sh`** — new `octopus ask` command with live tail and Ctrl+C handler.
2. **`SkillMatcher.resolve()` — `@role:` prefix parsing** — pre-parse step before NL matching.
3. **`app.py` — prefill on Enter in agents table** — `on_data_table_row_selected` handler + command bar prefill.
4. **`app.py` — mini-feed in roster** — `_refresh_roster()` reads last log line per agent.
5. **`app.py` — focus output on cursor move** — `on_data_table_row_highlighted` updates Output panel.
6. **`pipeline.py` — structured progress lines** — `print()` calls at dispatch, completion, and pipeline end.
7. **`cli/octopus.sh`** — add `ask` to command list.
8. **Tests** — unit tests for `@role:` parsing; integration test for `octopus ask --dry-run`.

## Risks

1. **Log tail race condition** — `ask.py` starts tailing before the log file exists. Mitigation: same 30-poll wait as `_stream_log()` in `app.py`.
2. **Mini-feed performance** — reading last line of log on every poll (every 2s) per agent adds file I/O. Mitigation: cache the file offset; only re-read if file size changed (via `os.stat`).
3. **`@role:` collision with skill names** — if a skill is named `@something`, parsing breaks. Mitigation: `@` is not a valid skill name character, so no collision.
4. **Prefill on running agent** — Enter on a running agent should focus output, not open delegation bar. Spec is explicit: idle → prefill, running → focus output.

## Changelog

- **2026-04-24** — Initial design from brainstorming session
