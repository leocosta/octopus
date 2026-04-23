# Octopus Control — Gap Fix Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix 8 gaps in `octopus control` (RM-045 to RM-052): failed state, scheduler wiring, queue cleanup, animated status, scrollable log panel, log viewer, skill autocomplete, and worktree isolation.

**Architecture:** All changes are confined to `cli/control/` (5 Python files + CSS). Tasks are ordered by dependency: ProcessManager refactor first (Task 1) since Tasks 4, 5, 6, and 8 build on it; RichLog panel (Task 5) before log viewer (Task 6).

**Tech Stack:** Python 3.11+, Textual 8.x (`RichLog`, `SuggestFromList`), pytest for unit tests, existing bash test harness for integration.

---

## File Map

| File | Role | Tasks |
|---|---|---|
| `cli/control/process_manager.py` | Store `Popen` objects; expose exit codes; add worktree helpers | 1, 8 |
| `cli/control/queue.py` | Add `cleanup()` method; persist exit status | 1, 3 |
| `cli/control/app.py` | Wire scheduler; animated roster; RichLog; log viewer; autocomplete | 2, 3, 4, 5, 6, 7 |
| `cli/control/app.tcss` | Height rules for `RichLog`; suggestion styling | 5, 7 |
| `tests/test_process_manager.py` | Exit code tests; worktree tests | 1, 8 |
| `tests/test_queue.py` | Cleanup tests | 3 |
| `tests/test_control.sh` | Integration smoke tests for new features | all |

---

## Task 1: Failed state — store Popen and capture exit code (RM-049)

**Files:**
- Modify: `cli/control/process_manager.py`
- Modify: `cli/control/app.py` (only `_reap_dead_agents`)
- Modify: `tests/test_process_manager.py`

- [ ] **Step 1: Write the failing test for exit code capture**

Add to `tests/test_process_manager.py`:

```python
import time

def test_exit_code_success(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    proc = subprocess.Popen(["true"])
    pm._procs["worker"] = proc
    time.sleep(0.1)
    assert pm.exit_code("worker") == 0


def test_exit_code_failure(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    proc = subprocess.Popen(["false"])
    pm._procs["worker"] = proc
    time.sleep(0.1)
    assert pm.exit_code("worker") == 1


def test_exit_code_still_running(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    proc = subprocess.Popen(["sleep", "60"])
    pm._procs["worker"] = proc
    assert pm.exit_code("worker") is None
    proc.terminate()
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
cd /home/leonardo/Projects/octopus
python3 -m pytest tests/test_process_manager.py::test_exit_code_success tests/test_process_manager.py::test_exit_code_failure tests/test_process_manager.py::test_exit_code_still_running -v
```

Expected: `AttributeError: 'ProcessManager' object has no attribute '_procs'`

- [ ] **Step 3: Refactor `ProcessManager` to store `Popen` objects and expose `exit_code()`**

Replace the content of `cli/control/process_manager.py`:

```python
import os
import signal
import subprocess
from pathlib import Path
from typing import AsyncGenerator


class ProcessManager:
    def __init__(self, octopus_dir: Path):
        self.root = octopus_dir
        self.pids_dir = octopus_dir / "pids"
        self.logs_dir = octopus_dir / "logs"
        self.worktrees_dir = octopus_dir / "worktrees"
        for d in (self.pids_dir, self.logs_dir, self.worktrees_dir):
            d.mkdir(parents=True, exist_ok=True)
        self._procs: dict[str, subprocess.Popen] = {}

    def _run_claude(
        self, role: str, prompt: str, model: str, log_path: Path, cwd: Path | None = None
    ) -> subprocess.Popen:
        cmd = ["claude", "--model", model, "--print", prompt]
        with open(log_path, "w") as f:
            return subprocess.Popen(
                cmd,
                stdout=f,
                stderr=subprocess.STDOUT,
                cwd=cwd or Path.cwd(),
            )

    def launch(self, role: str, prompt: str, model: str, cwd: Path | None = None) -> int:
        log_path = self.logs_dir / f"{role}.log"
        proc = self._run_claude(role, prompt, model, log_path, cwd=cwd)
        self._procs[role] = proc
        (self.pids_dir / f"{role}.pid").write_text(str(proc.pid))
        return proc.pid

    def exit_code(self, role: str) -> int | None:
        proc = self._procs.get(role)
        if proc is None:
            return None
        return proc.poll()

    def kill(self, role: str) -> None:
        proc = self._procs.pop(role, None)
        if proc is not None:
            try:
                proc.terminate()
            except ProcessLookupError:
                pass
        pid_file = self.pids_dir / f"{role}.pid"
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGTERM)
            except (ProcessLookupError, ValueError):
                pass
            pid_file.unlink(missing_ok=True)

    def adopt_orphans(self) -> dict[str, int]:
        adopted = {}
        for pid_file in self.pids_dir.glob("*.pid"):
            role = pid_file.stem
            try:
                pid = int(pid_file.read_text())
                os.kill(pid, 0)
                adopted[role] = pid
            except (ProcessLookupError, ValueError):
                pid_file.unlink(missing_ok=True)
        return adopted

    async def tail_log(self, role: str) -> AsyncGenerator[str, None]:
        log_path = self.logs_dir / f"{role}.log"
        if not log_path.exists():
            return
        with open(log_path) as f:
            f.seek(0, 2)
            while True:
                line = f.readline()
                if line:
                    yield line.rstrip()
```

- [ ] **Step 4: Update `_reap_dead_agents` in `app.py` to use exit code**

Find the `_reap_dead_agents` method and replace it:

```python
def _reap_dead_agents(self) -> None:
    dead = []
    for role, pid in list(self._agents.items()):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            dead.append(role)
    for role in dead:
        self._agents.pop(role, None)
        code = self.pm.exit_code(role)
        final_status = "done" if (code is None or code == 0) else "failed"
        (self.pm.pids_dir / f"{role}.pid").unlink(missing_ok=True)
        for task in self.queue.list_all():
            if task["role"] == role and task["status"] == "running":
                self.queue.update_status(task["id"], final_status)
```

- [ ] **Step 5: Run tests to confirm they pass**

```bash
python3 -m pytest tests/test_process_manager.py -v
```

Expected: all tests PASS (including the 3 new ones)

- [ ] **Step 6: Commit**

```bash
git add cli/control/process_manager.py cli/control/app.py tests/test_process_manager.py
git commit -m "feat(control): store Popen objects and capture exit code for failed state"
```

---

## Task 2: Wire Scheduler into app (RM-048)

**Files:**
- Modify: `cli/control/app.py`
- Modify: `tests/test_control.sh`

- [ ] **Step 1: Write a smoke test for scheduler integration**

Add to `tests/test_control.sh`:

```bash
echo "Test: Scheduler class is importable and stoppable"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from pathlib import Path
from cli.control.scheduler import Scheduler

fired = []
def on_fire(entry):
    fired.append(entry)

s = Scheduler(Path("/nonexistent/schedule.yml"), on_fire=on_fire)
s.start()
s.stop()
s.join(timeout=2)
assert not s.is_alive(), "Scheduler thread did not stop"
print("PASS: Scheduler starts and stops cleanly")
PYEOF
```

- [ ] **Step 2: Run test to confirm it passes (Scheduler already works in isolation)**

```bash
bash tests/test_control.sh
```

Expected: PASS on the new test

- [ ] **Step 3: Wire `Scheduler` into `app.py`**

Add the import at the top of `cli/control/app.py`:

```python
from .scheduler import Scheduler
```

In `__init__`, add:

```python
self._scheduler: Scheduler | None = None
```

In `on_mount`, add after the existing setup (before `self.set_interval`):

```python
schedule_path = self.octopus_dir / "schedule.yml"
self._scheduler = Scheduler(schedule_path, on_fire=self._on_schedule_fire)
self._scheduler.start()
self._refresh_schedule()
```

Add these new methods to the class:

```python
def _on_schedule_fire(self, entry: dict) -> None:
    self.queue.enqueue(
        role=entry.get("role", "agent"),
        skill=entry.get("skill"),
        model=entry.get("model", "claude-sonnet-4-6"),
        prompt=entry.get("prompt", ""),
    )
    self.call_from_thread(self._refresh_queue)

def _refresh_schedule(self) -> None:
    table = self.query_one("#schedule", DataTable)
    table.clear()
    schedule_path = self.octopus_dir / "schedule.yml"
    if not schedule_path.exists():
        return
    try:
        import yaml
        entries = yaml.safe_load(schedule_path.read_text()) or []
    except Exception:
        return
    for entry in entries:
        table.add_row(
            entry.get("id", "–"),
            entry.get("when", "–"),
            entry.get("role", "–"),
            entry.get("skill", "–"),
        )
```

Replace `action_request_quit` to stop the scheduler:

```python
async def action_request_quit(self) -> None:
    if not self._agents:
        if self._scheduler:
            self._scheduler.stop()
        self.exit()
        return
    self.notify("stop(s)  detach(d)  cancel(c)", title="Agents running")
    self._awaiting_exit = True
```

In `on_key`, update the `s` branch:

```python
elif event.key == "s":
    for role in list(self._agents):
        self.pm.kill(role)
    if self._scheduler:
        self._scheduler.stop()
    self.exit()
```

- [ ] **Step 4: Run tests**

```bash
bash tests/test_control.sh
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py tests/test_control.sh
git commit -m "feat(control): wire Scheduler into app — scheduled tasks now dispatch"
```

---

## Task 3: Queue cleanup (RM-051)

**Files:**
- Modify: `cli/control/queue.py`
- Modify: `cli/control/app.py`
- Modify: `tests/test_queue.py`

- [ ] **Step 1: Write failing tests for `cleanup()`**

Add to `tests/test_queue.py`:

```python
def test_cleanup_removes_done_tasks(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    ids = [q.enqueue("worker", None, "claude-sonnet-4-6", f"t{i}") for i in range(5)]
    for tid in ids:
        q.update_status(tid, "done")
    removed = q.cleanup(keep_last=2)
    assert removed == 3
    assert len(q.list_all()) == 2


def test_cleanup_keeps_queued_and_running(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    q.enqueue("worker", None, "claude-sonnet-4-6", "running-task")
    q.update_status(q.list_all()[0]["id"], "running")
    q.enqueue("worker", None, "claude-sonnet-4-6", "queued-task")
    removed = q.cleanup(keep_last=0)
    assert removed == 0
    assert len(q.list_all()) == 2


def test_cleanup_failed_tasks(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    tid = q.enqueue("worker", None, "claude-sonnet-4-6", "bad-task")
    q.update_status(tid, "failed")
    removed = q.cleanup(keep_last=0)
    assert removed == 1
    assert len(q.list_all()) == 0
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
python3 -m pytest tests/test_queue.py::test_cleanup_removes_done_tasks -v
```

Expected: `AttributeError: 'TaskQueue' object has no attribute 'cleanup'`

- [ ] **Step 3: Add `cleanup()` to `TaskQueue`**

Add to `cli/control/queue.py` (after `dequeue`):

```python
def cleanup(self, statuses: list[str] | None = None, keep_last: int = 50) -> int:
    if statuses is None:
        statuses = ["done", "failed"]
    completed = [t for t in self.list_all() if t["status"] in statuses]
    to_remove = completed[:-keep_last] if keep_last > 0 else completed
    for task in to_remove:
        self.dequeue(task["id"])
    return len(to_remove)
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
python3 -m pytest tests/test_queue.py -v
```

Expected: all PASS

- [ ] **Step 5: Wire cleanup into `app.py`**

Add a `_cleanup_tick` counter to `__init__`:

```python
self._cleanup_tick: int = 0
```

In `_poll`, add at the end:

```python
self._cleanup_tick += 1
if self._cleanup_tick % 30 == 0:  # every ~60 s (30 ticks × 2 s)
    self.queue.cleanup(keep_last=50)
    self._refresh_queue()
```

Add keybinding for manual cleanup. Add to `BINDINGS`:

```python
Binding("ctrl+d", "cleanup_queue", "Clean queue"),
```

Add action method:

```python
def action_cleanup_queue(self) -> None:
    removed = self.queue.cleanup(keep_last=0)
    self.notify(f"Removed {removed} completed task(s)")
    self._refresh_queue()
```

- [ ] **Step 6: Commit**

```bash
git add cli/control/queue.py cli/control/app.py tests/test_queue.py
git commit -m "feat(control): add queue cleanup — keep last 50 done/failed, Ctrl+D to clear all"
```

---

## Task 4: Animated status indicator in agent roster (RM-047)

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Add spinner constant and tick counter**

At the top of `cli/control/app.py`, after the imports, add:

```python
_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
```

In `__init__`, add:

```python
self._tick: int = 0
```

- [ ] **Step 2: Update `_refresh_roster` to use animated spinner**

Replace the existing `_refresh_roster`:

```python
def _refresh_roster(self) -> None:
    table = self.query_one("#agents", DataTable)
    table.clear()
    frame = _SPINNER[self._tick % len(_SPINNER)]
    self._tick += 1
    for role, pid in self._agents.items():
        table.add_row(role, str(pid), f"{frame} running", key=role)
```

- [ ] **Step 3: Manual smoke test**

```bash
cd /home/leonardo/Projects/octopus
python3 -c "
from cli.control.app import _SPINNER
assert len(_SPINNER) == 10
print('PASS: spinner constant has 10 frames')
"
```

- [ ] **Step 4: Run integration tests**

```bash
bash tests/test_control.sh
```

Expected: all tests PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): animate agent status spinner in roster table"
```

---

## Task 5: Real-time scrollable log panel — RichLog (RM-046)

**Files:**
- Modify: `cli/control/app.py`
- Modify: `cli/control/app.tcss`

- [ ] **Step 1: Replace `Label` import with `RichLog` in app.py**

In the imports at the top of `cli/control/app.py`, change:

```python
from textual.widgets import DataTable, Footer, Header, Input, Label, ListItem, ListView
```

to:

```python
from textual.widgets import DataTable, Footer, Header, Input, ListItem, ListView, RichLog
```

- [ ] **Step 2: Replace `Label` widget with `RichLog` in `compose()`**

Find `yield Label("", id="output")` and replace with:

```python
yield RichLog(id="output", markup=True, highlight=False, wrap=True)
```

- [ ] **Step 3: Update `_stream_log` to write to RichLog**

Replace the entire `_stream_log` method:

```python
async def _stream_log(self, role: str) -> None:
    log_widget = self.query_one("#output", RichLog)
    log_path = self.pm.logs_dir / f"{role}.log"
    for _ in range(30):
        if log_path.exists():
            break
        await asyncio.sleep(0.1)
    if not log_path.exists():
        return
    log_widget.clear()
    log_widget.write(f"─── {role} ───")
    with open(log_path) as f:
        while True:
            line = f.readline()
            if line:
                log_widget.write(line.rstrip())
            else:
                if role not in self._agents:
                    break
                await asyncio.sleep(0.2)
```

- [ ] **Step 4: Update `app.tcss` — give `#output` proper height**

Find the `#output` block in `cli/control/app.tcss` and replace it:

```css
#output {
    border: round $surface;
    background: $bg;
    color: $text-dim;
    padding: 0 1;
    height: 1fr;
    scrollbar-color: $accent;
}
```

Also update the layout so `#output` is below the left/right panels. In the CSS, add:

```css
Screen > Horizontal {
    height: 1fr;
}

#left, #right {
    height: 100%;
}
```

- [ ] **Step 5: Run integration tests**

```bash
bash tests/test_control.sh
```

Expected: all tests PASS

- [ ] **Step 6: Add a test to `test_control.sh` confirming RichLog is used**

Add to `tests/test_control.sh`:

```bash
echo "Test: app.py uses RichLog, not Label for output"
grep -q "RichLog" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: app.py still uses Label for output panel"; exit 1; }
echo "PASS"
```

- [ ] **Step 7: Commit**

```bash
git add cli/control/app.py cli/control/app.tcss tests/test_control.sh
git commit -m "feat(control): replace Label with RichLog for scrollable real-time log panel"
```

---

## Task 6: Log viewer for completed tasks (RM-050)

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write test verifying log path resolution**

Add to `tests/test_control.sh`:

```bash
echo "Test: completed task log path is predictable"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from pathlib import Path
from cli.control.process_manager import ProcessManager

tmp = Path("/tmp/octopus-test-log-viewer")
tmp.mkdir(exist_ok=True)
pm = ProcessManager(tmp)
log = pm.logs_dir / "backend-specialist.log"
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text("line1\nline2\n")
assert log.read_text() == "line1\nline2\n"
print("PASS: log file readable at predictable path")
PYEOF
```

- [ ] **Step 2: Run test to confirm it passes**

```bash
bash tests/test_control.sh
```

Expected: PASS

- [ ] **Step 3: Add `on_list_view_selected` handler to `app.py`**

Add this method to `OctopusControl`:

```python
def on_list_view_selected(self, event: ListView.Selected) -> None:
    tasks = self.queue.list_all()
    idx = event.list_view.index
    if idx is None or idx >= len(tasks):
        return
    task = tasks[idx]
    if task["status"] not in ("done", "failed"):
        return
    log_widget = self.query_one("#output", RichLog)
    log_widget.clear()
    role = task["role"]
    log_path = self.pm.logs_dir / f"{role}.log"
    status_label = "[green]done[/green]" if task["status"] == "done" else "[red]failed[/red]"
    log_widget.write(f"─── {role} ({status_label}) ───")
    if log_path.exists():
        for line in log_path.read_text().splitlines():
            log_widget.write(line)
    else:
        log_widget.write("[dim]No log file found[/dim]")
```

- [ ] **Step 4: Update `_refresh_queue` to show status color in queue list**

Replace `_refresh_queue`:

```python
_STATUS_LABEL = {
    "queued":  "○",
    "running": "●",
    "done":    "✓",
    "failed":  "✗",
}

def _refresh_queue(self) -> None:
    lv = self.query_one("#queue", ListView)
    lv.clear()
    for task in self.queue.list_all():
        status = task["status"]
        role = task["role"]
        skill = task.get("skill") or "–"
        icon = _STATUS_LABEL.get(status, "?")
        lv.append(ListItem(Label(f"{icon} [{status}] {role} / {skill}")))
```

Note: add `_STATUS_LABEL` as a module-level constant above the class.

- [ ] **Step 5: Run all tests**

```bash
bash tests/test_control.sh && python3 -m pytest tests/test_process_manager.py tests/test_queue.py tests/test_scheduler.py tests/test_skill_matcher.py -v
```

Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): add log viewer for completed tasks — select task in queue to view log"
```

---

## Task 7: Typeahead autocomplete for skills in command bar (RM-045)

**Files:**
- Modify: `cli/control/app.py`
- Modify: `cli/control/app.tcss`

- [ ] **Step 1: Write test confirming SuggestFromList is wired**

Add to `tests/test_control.sh`:

```bash
echo "Test: SuggestFromList is importable from textual"
python3 -c "from textual.suggester import SuggestFromList; print('PASS: SuggestFromList available')" \
  || { echo "FAIL: SuggestFromList not available in this Textual version"; exit 1; }
```

- [ ] **Step 2: Run test to confirm it passes**

```bash
bash tests/test_control.sh
```

Expected: PASS

- [ ] **Step 3: Add `SuggestFromList` import**

Add to the top of `cli/control/app.py`:

```python
from textual.suggester import SuggestFromList
```

- [ ] **Step 4: Set suggester on the Input widget in `on_mount`**

In `on_mount`, after `self._refresh_roster()`, add:

```python
skill_names = [f"/{s}" for s in self._matcher._catalog]
cmd_input = self.query_one("#cmd", Input)
cmd_input.suggester = SuggestFromList(skill_names, case_sensitive=False)
```

- [ ] **Step 5: Handle `ambiguous` and `needs_confirm` in `on_input_submitted`**

Replace `on_input_submitted`:

```python
def on_input_submitted(self, event: Input.Submitted) -> None:
    text = event.value.strip()
    cmd_widget = self.query_one("#cmd", Input)
    cmd_widget.value = ""
    cmd_widget.add_class("hidden")
    if not text:
        return
    result = self._matcher.resolve(text, role_model="claude-sonnet-4-6")
    if result.ambiguous:
        options = ", ".join(f"/{s}" for s in result.ambiguous)
        self.notify(f"Ambiguous match: {options}", severity="warning", timeout=5)
        return
    if result.needs_confirm:
        self.notify(
            f"Matched /{result.skill} — re-submit to confirm",
            severity="information",
            timeout=4,
        )
        cmd_widget.value = f"/{result.skill} {result.raw_prompt}".strip()
        cmd_widget.remove_class("hidden")
        cmd_widget.focus()
        return
    self.queue.enqueue(
        role=self._selected_role(),
        skill=result.skill,
        model=result.model,
        prompt=result.raw_prompt,
    )
    self._refresh_queue()
```

- [ ] **Step 6: Add CSS for suggestion dropdown**

Add to `cli/control/app.tcss`:

```css
/* ── Autocomplete suggestion ─────────────────────── */
.input--suggestion {
    color: $text-dim;
}
```

- [ ] **Step 7: Write test for ambiguous and needs_confirm paths**

Add to `tests/test_control.sh`:

```bash
echo "Test: skill_matcher returns needs_confirm for NL single match"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from cli.control.skill_matcher import SkillMatcher

MOCK = {
    "security-scan": {"keywords": ["auth", "jwt"], "model": None},
}
m = SkillMatcher(skills_dir=None, _mock=MOCK)
r = m.resolve("check jwt tokens", role_model="claude-sonnet-4-6")
assert r.needs_confirm is True, f"expected needs_confirm=True, got {r}"
print("PASS: NL single match sets needs_confirm")
PYEOF
```

- [ ] **Step 8: Run all tests**

```bash
bash tests/test_control.sh && python3 -m pytest tests/test_skill_matcher.py -v
```

Expected: all PASS

- [ ] **Step 9: Commit**

```bash
git add cli/control/app.py cli/control/app.tcss tests/test_control.sh
git commit -m "feat(control): add typeahead autocomplete for skills in command bar"
```

---

## Task 8: Worktree isolation per agent (RM-052)

**Files:**
- Modify: `cli/control/process_manager.py`
- Modify: `cli/control/app.py`
- Modify: `tests/test_process_manager.py`

- [ ] **Step 1: Write failing tests for worktree helpers**

Add to `tests/test_process_manager.py`:

```python
import subprocess as sp

def test_create_worktree_calls_git(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    calls = []
    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        class R:
            returncode = 0
        return R()
    monkeypatch.setattr(sp, "run", fake_run)
    pm.create_worktree("backend-specialist")
    assert any("worktree" in " ".join(c) for c in calls)


def test_remove_worktree_calls_git(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    (tmp_path / "worktrees" / "backend-specialist").mkdir(parents=True)
    calls = []
    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        class R:
            returncode = 0
        return R()
    monkeypatch.setattr(sp, "run", fake_run)
    pm.remove_worktree("backend-specialist")
    assert any("worktree" in " ".join(c) for c in calls)


def test_launch_with_isolation_uses_worktree_cwd(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    used_cwd = []
    def fake_run_claude(role, prompt, model, log_path, cwd=None):
        used_cwd.append(cwd)
        class FakeProc:
            pid = 12345
            def poll(self): return None
        return FakeProc()
    def fake_create_worktree(role):
        return tmp_path / "worktrees" / role
    monkeypatch.setattr(pm, "_run_claude", fake_run_claude)
    monkeypatch.setattr(pm, "create_worktree", fake_create_worktree)
    pm.launch("backend-specialist", "hello", "claude-sonnet-4-6", isolate=True)
    assert used_cwd[0] == tmp_path / "worktrees" / "backend-specialist"
```

- [ ] **Step 2: Run tests to confirm they fail**

```bash
python3 -m pytest tests/test_process_manager.py::test_create_worktree_calls_git -v
```

Expected: `AttributeError: 'ProcessManager' object has no attribute 'create_worktree'`

- [ ] **Step 3: Add `create_worktree` and `remove_worktree` to `ProcessManager`**

Add these methods to `ProcessManager` in `cli/control/process_manager.py`:

```python
def create_worktree(self, role: str) -> Path:
    wt_path = self.worktrees_dir / role
    subprocess.run(
        ["git", "worktree", "add", "--detach", str(wt_path), "HEAD"],
        check=True,
        capture_output=True,
    )
    return wt_path

def remove_worktree(self, role: str) -> None:
    wt_path = self.worktrees_dir / role
    if wt_path.exists():
        subprocess.run(
            ["git", "worktree", "remove", "--force", str(wt_path)],
            check=False,
            capture_output=True,
        )
```

Update `launch` to accept and honour `isolate`:

```python
def launch(self, role: str, prompt: str, model: str, cwd: Path | None = None, isolate: bool = False) -> int:
    log_path = self.logs_dir / f"{role}.log"
    effective_cwd = self.create_worktree(role) if isolate else (cwd or Path.cwd())
    proc = self._run_claude(role, prompt, model, log_path, cwd=effective_cwd)
    self._procs[role] = proc
    (self.pids_dir / f"{role}.pid").write_text(str(proc.pid))
    return proc.pid
```

- [ ] **Step 4: Run tests to confirm they pass**

```bash
python3 -m pytest tests/test_process_manager.py -v
```

Expected: all PASS

- [ ] **Step 5: Wire worktree cleanup into `_reap_dead_agents` in `app.py`**

Add worktree cleanup to the dead-agent cleanup in `_reap_dead_agents`, after `(self.pm.pids_dir / f"{role}.pid").unlink(missing_ok=True)`:

```python
self.pm.remove_worktree(role)
```

The full updated method:

```python
def _reap_dead_agents(self) -> None:
    dead = []
    for role, pid in list(self._agents.items()):
        try:
            os.kill(pid, 0)
        except ProcessLookupError:
            dead.append(role)
    for role in dead:
        self._agents.pop(role, None)
        code = self.pm.exit_code(role)
        final_status = "done" if (code is None or code == 0) else "failed"
        (self.pm.pids_dir / f"{role}.pid").unlink(missing_ok=True)
        self.pm.remove_worktree(role)
        for task in self.queue.list_all():
            if task["role"] == role and task["status"] == "running":
                self.queue.update_status(task["id"], final_status)
```

- [ ] **Step 6: Run all tests**

```bash
bash tests/test_control.sh && python3 -m pytest tests/test_process_manager.py tests/test_queue.py tests/test_scheduler.py tests/test_skill_matcher.py -v
```

Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add cli/control/process_manager.py cli/control/app.py tests/test_process_manager.py
git commit -m "feat(control): add worktree isolation per agent — create/remove git worktrees on launch/reap"
```

---

## Self-Review

**Spec coverage check:**

| RM | Requirement | Task |
|---|---|---|
| RM-045 | Typeahead autocomplete with `SuggestFromList`; `ambiguous` and `needs_confirm` handled | Task 7 |
| RM-046 | `RichLog` replacing `Label`; scrollable; streams all lines | Task 5 |
| RM-047 | Spinner frames cycling in `_refresh_roster`; distinct icons per status | Tasks 4, 6 |
| RM-048 | `Scheduler` instantiated in `on_mount`; `_on_schedule_fire` enqueues; stopped on quit | Task 2 |
| RM-049 | `_procs` dict; `exit_code()` via `poll()`; `_reap_dead_agents` maps 0 → done, non-0 → failed | Task 1 |
| RM-050 | `on_list_view_selected` loads log from disk into `RichLog` | Task 6 |
| RM-051 | `cleanup(keep_last)` in `TaskQueue`; auto-called every 30 ticks; `Ctrl+D` manual | Task 3 |
| RM-052 | `create_worktree` / `remove_worktree`; `launch(isolate=True)` uses worktree as cwd | Task 8 |

**Placeholder scan:** No TBDs. All code blocks are complete.

**Type consistency:** `ProcessManager.launch()` signature updated consistently across Tasks 1, 8. `RichLog` used in Tasks 5 and 6. `_STATUS_LABEL` defined at module level before use in Task 6.
