# Design: Agent Reply — Bidirectional Agent Interaction via Session Resume

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-24 |
| **Author** | Leonardo Costa |
| **Status** | Draft |
| **Roadmap** | RM-055 (proposed) |

## Problem Statement

Agents launched by `octopus control` and `octopus ask` run with `claude --print`, which is non-interactive. When an agent asks a clarifying question mid-task — e.g. "What tone should I use?" — the user cannot respond. The agent either stalls or exits without completing the work.

## Goals

- Any agent that has completed a turn can be replied to from the TUI with a single keybinding.
- The reply launches a new Claude session that resumes from the exact point where the previous turn ended, with the full conversation context intact.
- The log viewer in the TUI shows the entire conversation across all turns, not just the last one.
- Session files persist across TUI restarts — a session started yesterday can be replied to today (within Claude's session TTL).
- The change is backward-compatible: agents that complete without asking anything behave identically to today.

## Non-Goals

- Automatic detection of whether an agent asked a question — the `[r]eply` keybinding is always available for any completed agent with a session file.
- Real-time interactive PTY (type-as-you-go) — that requires significantly more complexity and is deferred.
- Multi-turn reply chains in `octopus ask` (terminal mode) — TUI only for now; `ask` gets `--reply` flag in a follow-up.
- Reply from within the pipeline runner.

## Design

### Session ID Capture

`ProcessManager._run_claude()` switches from direct stdout redirection to a `subprocess.PIPE` with a background parser thread. The command gains `--output-format=stream-json --verbose`:

```bash
# Before
claude --model <model> --print <prompt>

# After
claude --model <model> --print --output-format=stream-json --verbose <prompt>
```

The parser thread reads JSONL lines and:
1. Extracts `session_id` from the first event where it appears (`type: "system", subtype: "init"`) and writes it to `.octopus/sessions/<role>.session`.
2. Extracts text content from `type: "assistant"` events (`message.content[].text`) and writes plain text to `.octopus/logs/<role>.log` — identical to today's format, preserving all existing streaming/viewing behaviour.
3. Ignores `type: "result"` events (text already captured via assistant events).

Session files live at `.octopus/sessions/<role>.session` (plain text, one UUID per file). The directory is created on first write.

### Resume Launch

A new `ProcessManager.launch_resume(role, session_id, reply, model)` method:

```bash
claude --model <model> --print --output-format=stream-json --verbose \
       --resume <session_id> "<reply>"
```

Output is **appended** to the existing `.octopus/logs/<role>.log` (with a separator line `── reply ──`) so the full conversation is visible in one scroll. The new turn also writes a new `session_id` back to the session file (Claude may issue a new ID per turn).

### Task Queue Changes

Two new optional fields on queue task JSON:

```json
{
  "id": "...",
  "role": "tech-writer",
  "session_id": "abc-123-def-456",
  "resumable": true
}
```

`session_id` is set when the parser thread captures it. `resumable` is derived at read-time: `True` when `.octopus/sessions/<role>.session` exists and is non-empty.

### TUI Changes

**Agents roster** — `_refresh_roster()` appends `↩` to the status of any idle/done role that has a session file:

```
✓ tech-writer    0m31s  ↩  What tone should I use?…
```

The last log line (mini-feed) is still shown; the `↩` appears before it.

**New keybinding `r`** — `Binding("r", "reply_agent", "Reply")` — active only when the selected agent has a session file. Opens the command bar pre-filled with `↩ <role>: `:

```
↩ tech-writer: accessible to non-engineers
```

**Command bar prefix detection** — `on_input_submitted` gains a pre-parse step alongside the existing `@role:` step: if input starts with `↩ <word>: `, extract `role` and `reply_text`, call `pm.launch_resume()`.

**`action_reply_agent()`** — new action method that reads the session file for the selected role and opens the command bar. If no session file exists, shows a notification: `"No resumable session for <role>"`.

### `octopus ask` — future extension

`--reply <session_id>` flag on `octopus ask` will enable terminal-mode replies (deferred). The session file path is printed at the end of every `octopus ask` run so users can retrieve the ID manually if needed before the TUI feature ships.

## Implementation Plan

1. **`ProcessManager` parser thread** — switch to `--output-format=stream-json --verbose`; background thread extracts `session_id` and writes text log.
2. **`ProcessManager.launch_resume()`** — new method using `--resume`; appends to log with separator.
3. **`.octopus/sessions/` directory** — created by `ProcessManager.__init__`.
4. **`app.py`: `action_reply_agent()` + `Binding("r")`** — reads session file, opens command bar.
5. **`app.py`: `_refresh_roster()` update** — shows `↩` when session file exists.
6. **`app.py`: `on_input_submitted` update** — detect `↩ role:` prefix and call `launch_resume()`.
7. **`ask.py`** — print session file path at end of run (prep for future `--reply` flag).
8. **Tests** — unit tests for parser thread (session_id extraction, text extraction); integration test for `launch_resume` dry-run.

## Risks

1. **Claude session TTL** — Sessions expire after some period (likely hours to days). If a session is too old, `--resume` may fail. Mitigation: catch non-zero exit from `launch_resume` and show `"Session expired — start a new task"` notification.

2. **Parser thread overhead** — One thread per agent adds memory. Mitigation: thread is daemon and exits when process exits; overhead is negligible for typical agent counts (≤10).

3. **JSONL parsing breaking on malformed output** — Claude may occasionally emit non-JSON lines (e.g., during errors). Mitigation: `try/except json.JSONDecodeError` writes the raw line to the log as-is.

4. **Session file stale after worktree removal** — If a worktree is pruned but the session file remains, `--resume` succeeds but runs in the main worktree. Mitigation: acceptable for now; the resumed session runs from `cwd`.

5. **`--output-format=stream-json` requires `--verbose`** — verified during design. This adds some overhead (system events), but they are discarded by the parser.

## Changelog

- **2026-04-24** — Initial design from brainstorming session
