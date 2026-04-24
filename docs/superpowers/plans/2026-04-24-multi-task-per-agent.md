# Multi-task Per Agent Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Allow dispatching multiple tasks to the same agent by always prefilling `@role:` in the command bar (even when the agent is busy) and showing a `+N queued` badge in the roster.

**Architecture:** Two isolated changes to `cli/control/app.py`: (1) remove the idle-only guard in `action_add_task` so the `@role:` prefill always fires; (2) count queued tasks per role in `_refresh_roster()` and append a dim badge to the status string. The dispatch engine already executes tasks sequentially — no backend changes needed.

**Tech Stack:** Python 3, Textual TUI, `cli/control/app.py`, `tests/test_control.sh`

---

## File Map

| File | Change |
|---|---|
| `cli/control/app.py:340-349` | Remove `not in self._agents` guard in `action_add_task` |
| `cli/control/app.py:246-270` | Add queued-count badge in `_refresh_roster()` |
| `tests/test_control.sh` | Two new static assertions |

---

### Task 1: Always prefill `@role:` in `action_add_task`

**Files:**
- Modify: `cli/control/app.py:340-349`
- Test: `tests/test_control.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_control.sh`:

```bash
echo "Test: action_add_task prefills @role: regardless of agent state"
grep -A 10 "def action_add_task" "$REPO_DIR/cli/control/app.py" | grep -q "selected_role not in self._agents" \
  && { echo "FAIL: idle-only guard still present in action_add_task"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | tail -4
```

Expected: `FAIL: idle-only guard still present in action_add_task`

- [ ] **Step 3: Remove the idle-only guard**

In `cli/control/app.py`, replace `action_add_task` (lines 340–349):

```python
    def action_add_task(self) -> None:
        cmd = self.query_one("#cmd", Input)
        selected_role = self._selected_role()
        cmd.remove_class("hidden")
        cmd.focus()
        if selected_role != "agent":
            prefill = f"@{selected_role}: "
            self.call_after_refresh(setattr, cmd, "value", prefill)
            self.call_after_refresh(setattr, cmd, "cursor_position", len(prefill))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_control.sh 2>&1 | tail -4
```

Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "feat(control): prefill @role: in command bar for busy agents too

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 2: Show `+N queued` badge in roster

**Files:**
- Modify: `cli/control/app.py:246-270`
- Test: `tests/test_control.sh`

- [ ] **Step 1: Write the failing test**

Append to `tests/test_control.sh`:

```bash
echo "Test: _refresh_roster shows queued badge"
grep -A 30 "def _refresh_roster" "$REPO_DIR/cli/control/app.py" | grep -q "queued" \
  || { echo "FAIL: _refresh_roster does not show queued badge"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | tail -4
```

Expected: `FAIL: _refresh_roster does not show queued badge`

- [ ] **Step 3: Add queued-count badge to `_refresh_roster()`**

In `cli/control/app.py`, replace `_refresh_roster()` (lines 246–270):

```python
    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        saved_row = table.cursor_row
        table.clear()
        frame = _SPINNER[self._spin_tick % len(_SPINNER)]
        tasks = self.queue.list_all()
        all_roles = list(dict.fromkeys(list(self._known_roles) + list(self._agents)))
        for role in all_roles:
            pending = sum(1 for t in tasks if t["role"] == role and t["status"] == "queued")
            badge = f"  [dim]+{pending} queued[/dim]" if pending else ""
            if role in self._agents:
                elapsed = int(time.time() - self._agent_started.get(role, time.time()))
                mins, secs = divmod(elapsed, 60)
                elapsed_str = f"{mins}m{secs:02d}s" if mins else f"{secs}s"
                last_line = self._last_log_line(role)
                if last_line:
                    truncated = last_line[:36] + "…" if len(last_line) > 36 else last_line
                    status = f"{frame} {elapsed_str}  [dim]{truncated}[/dim]{badge}"
                else:
                    status = f"{frame} {elapsed_str}{badge}"
            elif self.pm.has_session(role):
                status = f"[#ffd166]↩ awaiting reply[/#ffd166]{badge}"
            else:
                status = f"[dim]○ idle{badge}[/dim]"
            table.add_row(role, status, key=role)
        if saved_row is not None and saved_row < table.row_count:
            table.move_cursor(row=saved_row)
```

- [ ] **Step 4: Run full test suite**

```bash
bash tests/test_control.sh 2>&1 | tail -6
for t in tests/test_*.sh; do bash "$t" 2>&1 | grep "FAIL" || true; done
```

Expected: all control tests pass; no new failures in other suites.

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "feat(control): show +N queued badge in roster for pending tasks

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 3: Open PR

- [ ] **Step 1: Push and open PR**

```bash
git push
gh pr create \
  --title "feat(control): multi-task dispatch per agent" \
  --body "$(cat <<'EOF'
## Summary
- Pressing \`a\` on any agent (busy or idle) now prefills \`@role:\` in the command bar — tasks can be queued for a running agent without friction
- Roster shows \`+N queued\` badge for agents with pending tasks, so the backlog is visible at a glance
- The dispatch engine already ran tasks sequentially; these are pure UX improvements

## How to Test
1. \`octopus control\`
2. Dispatch a long-running task to \`tech-writer\` via \`a\`
3. While it runs, press \`a\` again → command bar prefills \`@tech-writer:\`
4. Submit a second task → roster shows \`+1 queued\` badge
5. When the first task finishes, the second starts automatically
EOF
)"
```
