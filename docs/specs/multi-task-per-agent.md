# Multi-task dispatch per agent

## Problem

Dispatching multiple tasks to the same agent is not possible through the UI. The dispatch engine already supports sequential execution (when an agent finishes, the next queued task for that role is dispatched automatically), but two UX gaps prevent users from using it:

1. Pressing `a` while an agent is running does not prefill `@role:` in the command bar — the user has no obvious way to add a task to a busy agent.
2. There is no visual indicator showing how many tasks are queued for a given agent, so users cannot tell whether their submissions were registered.

## Solution

Two isolated changes to `cli/control/app.py`:

### 1. Always prefill `@role:` in `action_add_task`

Remove the `selected_role not in self._agents` guard that prevents prefilling when the agent is active. The queue accepts tasks for busy roles already; the guard was only blocking the UX shortcut.

**Before:**
```python
if selected_role != "agent" and selected_role not in self._agents:
    prefill = f"@{selected_role}: "
    ...
```

**After:**
```python
if selected_role != "agent":
    prefill = f"@{selected_role}: "
    ...
```

### 2. Badge `+N queued` in the roster

In `_refresh_roster()`, count tasks with `status == "queued"` for each role from the queue. Append a dim badge to the status string when N > 0.

- Active agent with 2 pending: `⠋ 0m42s  Writing ADR…  [dim]+2 queued[/dim]`
- Idle agent with 1 pending: `[dim]○ idle  +1 queued[/dim]`
- Awaiting reply with 1 pending: `[#ffd166]↩ awaiting reply[/#ffd166]  [dim]+1 queued[/dim]`

## Out of scope

- Reordering queued tasks
- Cancelling individual queued tasks (use `Ctrl+D` to clean the full queue)
- Grouping the queue panel by role (Option B/C from brainstorm)

## Files changed

| File | Change |
|---|---|
| `cli/control/app.py` | Remove active-agent guard in `action_add_task`; add queued-count badge in `_refresh_roster()` |
| `tests/test_control.sh` | Static assertions for both changes |
