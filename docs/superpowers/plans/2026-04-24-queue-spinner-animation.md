# Queue Spinner Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Animate running tasks in the queue panel of `octopus control` with a braille spinner that updates at 0.3s, replacing the static `●`.

**Architecture:** Add a second Textual timer (`_spin_poll`) at 0.3s that owns only a shared `_spin_tick` counter and redraws the queue panel. The existing `_poll` at 2s keeps handling log reads, process checks, and dispatch. `_refresh_queue()` uses `_spin_tick` to select the spinner frame for running tasks.

**Tech Stack:** Python 3, Textual TUI framework, `cli/control/app.py`

---

## File Map

| File | Change |
|---|---|
| `cli/control/app.py` | Add `_spin_tick`, `_spin_poll()`, faster timer, update `_refresh_queue()` |
| `tests/test_control.sh` | Add static-analysis assertions for new method + timer |

---

### Task 1: Add `_spin_tick` attribute and `_spin_poll()` method

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write the failing test**

Add to the bottom of `tests/test_control.sh`:

```bash
echo "Test: app.py defines _spin_tick attribute"
grep -q "_spin_tick" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: _spin_tick not found in app.py"; exit 1; }
echo "PASS"

echo "Test: app.py defines _spin_poll method"
grep -q "def _spin_poll" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: _spin_poll method not found in app.py"; exit 1; }
echo "PASS"

echo "Test: app.py registers 0.3s interval"
grep -q "set_interval(0.3" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: 0.3s interval not registered in app.py"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | tail -10
```

Expected: `FAIL: _spin_tick not found in app.py`

- [ ] **Step 3: Add `_spin_tick` to `__init__`**

In `cli/control/app.py`, in `__init__` after `self._tick: int = 0` (line ~53), add:

```python
        self._spin_tick: int = 0
```

- [ ] **Step 4: Add `_spin_poll()` method**

In `cli/control/app.py`, after the `_poll` method (around line 116), add:

```python
    def _spin_poll(self) -> None:
        """Fast timer (0.3s) — advances spinner and redraws queue + roster if agents are active."""
        if not self._agents and not any(
            t["status"] == "running" for t in self.queue.list_all()
        ):
            return
        self._spin_tick += 1
        self._refresh_queue()
        self._refresh_roster()
```

- [ ] **Step 5: Register the 0.3s timer in `on_mount`**

In `on_mount` (around line 104), after `self.set_interval(2, self._poll)`, add:

```python
        self.set_interval(0.3, self._spin_poll)
```

- [ ] **Step 6: Run test to verify it passes**

```bash
bash tests/test_control.sh 2>&1 | tail -10
```

Expected: all three new assertions `PASS`

- [ ] **Step 7: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "feat(control): add fast spin timer and _spin_poll method

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 2: Use `_spin_tick` in `_refresh_queue()` for running tasks

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_control.sh`:

```bash
echo "Test: _refresh_queue uses _SPINNER for running tasks"
grep -A 10 "def _refresh_queue" "$REPO_DIR/cli/control/app.py" | grep -q "_spin_tick\|_SPINNER" \
  || { echo "FAIL: _refresh_queue does not use _spin_tick/_SPINNER for running tasks"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | grep -A1 "_refresh_queue uses"
```

Expected: `FAIL: _refresh_queue does not use _spin_tick/_SPINNER for running tasks`

- [ ] **Step 3: Update `_refresh_queue()` to animate running tasks**

Replace the body of `_refresh_queue()` in `cli/control/app.py` (lines ~254–270):

```python
    def _refresh_queue(self) -> None:
        lv = self.query_one("#queue", ListView)
        lv.clear()
        tasks = self.queue.list_all()
        running = sum(1 for t in tasks if t["status"] == "running")
        queued = sum(1 for t in tasks if t["status"] == "queued")
        title = "Queue"
        if running or queued:
            title = f"Queue  {running} running · {queued} waiting"
        lv.border_title = title
        frame = _SPINNER[self._spin_tick % len(_SPINNER)]
        for task in tasks:
            status = task["status"]
            role = task["role"]
            skill = task.get("skill") or "–"
            if status == "running":
                icon = frame
            else:
                icon = _STATUS_LABEL.get(status, "?")
            skill_short = skill[:22] + "…" if len(skill) > 22 else skill
            lv.append(ListItem(Label(f"{icon} {role}  [dim]{skill_short}[/dim]")))
```

- [ ] **Step 4: Run test to verify it passes**

```bash
bash tests/test_control.sh 2>&1 | grep -A1 "_refresh_queue uses"
```

Expected: `PASS`

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "feat(control): animate running queue tasks with braille spinner

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 3: Unify roster spinner to use `_spin_tick` and remove `_tick`

**Background:** `_refresh_roster()` currently has its own `_tick` counter that increments on each 2s poll call — meaning the roster spinner advances at 0.5 fps. Now that `_spin_poll` calls `_refresh_roster()` at 0.3s and owns `_spin_tick`, the roster can use `_spin_tick` too and `_tick` can be removed.

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write the failing test**

Add to `tests/test_control.sh`:

```bash
echo "Test: app.py does not define _tick attribute (replaced by _spin_tick)"
grep -q "self._tick: int" "$REPO_DIR/cli/control/app.py" \
  && { echo "FAIL: stale self._tick attribute still present in app.py"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

```bash
bash tests/test_control.sh 2>&1 | grep -A1 "does not define _tick"
```

Expected: `FAIL: stale self._tick attribute still present in app.py`

- [ ] **Step 3: Remove `_tick` from `__init__`**

In `cli/control/app.py` `__init__`, remove:

```python
        self._tick: int = 0
```

- [ ] **Step 4: Update `_refresh_roster()` to use `_spin_tick`**

In `_refresh_roster()`, replace:

```python
        frame = _SPINNER[self._tick % len(_SPINNER)]
        self._tick += 1
```

with:

```python
        frame = _SPINNER[self._spin_tick % len(_SPINNER)]
```

- [ ] **Step 5: Run full test suite**

```bash
bash tests/test_control.sh
for t in tests/test_*.sh; do bash "$t"; done
```

Expected: all tests pass

- [ ] **Step 6: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "refactor(control): unify spinner counter to _spin_tick, remove _tick

Co-authored-by: claude <claude@anthropic.com>"
```

---

### Task 4: Open PR

- [ ] **Step 1: Push branch and open PR**

```bash
git push -u origin HEAD
gh pr create \
  --title "feat(control): animate running tasks with braille spinner" \
  --body "$(cat <<'EOF'
## Summary
- Running tasks in the queue now show an animated braille spinner (⠋⠙⠹…) instead of a static ●
- A dedicated 0.3s timer (`_spin_poll`) drives the animation; the 2s poll keeps handling I/O
- Roster spinner unified to the same counter (`_spin_tick`); stale `_tick` removed

## How to Test
1. `octopus control`
2. Dispatch a task via `a` → observe the queue entry animates while running
3. Once done, spinner becomes ✓ / ✗ (static)

## Related
Closes RM-056 (if tracked)
EOF
)"
```
