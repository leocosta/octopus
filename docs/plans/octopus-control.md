# Octopus Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add `octopus control` — a TUI dashboard (Python/textual) that lets users launch, queue, schedule, and monitor multiple Claude Code agent sessions locally without external dependencies.

**Architecture:** Each agent runs as a Claude Code subprocess in an isolated git worktree under `.octopus/worktrees/<role>/`, tracked by a PID file. A task queue (`.octopus/queue/*.json`) feeds the process manager; a scheduler thread reads `.octopus/schedule.yml` and fires tasks on cron-style intervals or git events. The TUI polls PID state every second and tails log files asynchronously across four panels: agent roster, task queue, output, and schedule.

**Tech Stack:** Python 3 (textual for TUI, pure stdlib cron parser), Bash (CLI routing, worktree management), JSON (task queue), YAML (schedule), git worktrees (agent isolation).

**Spec:** `docs/specs/octopus-control.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `cli/lib/control.sh` | create | CLI entry point, dependency check, `--install-deps` |
| `cli/octopus.sh` | modify | Route `control` subcommand |
| `cli/control/__init__.py` | create | Package marker |
| `cli/control/process_manager.py` | create | `launch`, `kill`, `adopt_orphans`, `tail_log` |
| `cli/control/queue.py` | create | `TaskQueue`: `enqueue`, `dequeue`, `list_all`, `update_status` |
| `cli/control/skill_matcher.py` | create | Slash/NL → skill + model resolution |
| `cli/control/scheduler.py` | create | Cron thread, `schedule.yml` parser, `on:push` flag |
| `cli/control/app.py` | create | textual `App`: 4 panels, keybindings, exit prompt |
| `cli/control/app.tcss` | create | Textual CSS — palette, borders, status colors, ASCII octopus header |
| `.octopus/schedule.yml` | create (example) | Template for user schedules |
| `tests/test_control.sh` | create | Bash integration tests |
| `tests/test_skill_matcher.py` | create | Python unit tests |

---

## Task 1: CLI Routing

**Files:**
- Create: `cli/lib/control.sh`
- Modify: `cli/octopus.sh`

- [ ] **Step 1: Write the failing test**

```bash
# tests/test_control.sh (bootstrap)
echo "Test: octopus control --help exits 0"
bash cli/octopus.sh control --help \
  || { echo "FAIL: control --help returned non-zero"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_control.sh`
Expected: FAIL — `Unknown command: control`

- [ ] **Step 3: Write minimal implementation**

```bash
# cli/lib/control.sh
source "$CLI_DIR/lib/ui.sh"

_check_python_deps() {
  python3 -c "import textual" 2>/dev/null && return 0
  if [[ "${1:-}" == "--install-deps" ]]; then
    pip3 install "textual>=0.80" && return 0
  fi
  ui_error "textual not found. Run: octopus control --install-deps"
  exit 1
}

[[ "${1:-}" == "--help" ]] && {
  echo "Usage: octopus control [--install-deps]"
  echo "  Open the TUI agent dashboard."
  exit 0
}

_check_python_deps "$@"
python3 -m cli.control.app "$@"
```

Add to `cli/octopus.sh` usage block:
```bash
echo "  control        Open the TUI agent dashboard"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_control.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/lib/control.sh cli/octopus.sh tests/test_control.sh
git commit -m "feat(control): add octopus control subcommand routing"
```

---

## Task 2: Process Manager

**Files:**
- Create: `cli/control/__init__.py`
- Create: `cli/control/process_manager.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_process_manager.py
import subprocess, time, os, sys
sys.path.insert(0, ".")
from cli.control.process_manager import ProcessManager

def test_adopt_orphans(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    # plant a live PID
    proc = subprocess.Popen(["sleep", "60"])
    pid_file = tmp_path / "pids" / "backend-specialist.pid"
    pid_file.parent.mkdir(parents=True)
    pid_file.write_text(str(proc.pid))
    adopted = pm.adopt_orphans()
    assert "backend-specialist" in adopted
    proc.terminate()

def test_launch_creates_pid(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    monkeypatch.setattr(pm, "_run_claude", lambda *a, **kw: 99999)
    pm.launch("tech-writer", prompt="hello", model="claude-sonnet-4-6")
    assert (tmp_path / "pids" / "tech-writer.pid").exists()
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_process_manager.py -x`
Expected: FAIL — `ModuleNotFoundError: cli.control.process_manager`

- [ ] **Step 3: Write minimal implementation**

```python
# cli/control/__init__.py  (empty)

# cli/control/process_manager.py
import os, subprocess, signal
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

    def _run_claude(self, role, prompt, model, log_path):
        cmd = ["claude", "--model", model, "--print", prompt]
        with open(log_path, "w") as f:
            p = subprocess.Popen(cmd, stdout=f, stderr=subprocess.STDOUT)
        return p.pid

    def launch(self, role: str, prompt: str, model: str) -> int:
        log_path = self.logs_dir / f"{role}.log"
        pid = self._run_claude(role, prompt, model, log_path)
        (self.pids_dir / f"{role}.pid").write_text(str(pid))
        return pid

    def kill(self, role: str) -> None:
        pid_file = self.pids_dir / f"{role}.pid"
        if pid_file.exists():
            try:
                os.kill(int(pid_file.read_text()), signal.SIGTERM)
            except ProcessLookupError:
                pass
            pid_file.unlink(missing_ok=True)

    def adopt_orphans(self) -> dict[str, int]:
        adopted = {}
        for pid_file in self.pids_dir.glob("*.pid"):
            role = pid_file.stem
            try:
                pid = int(pid_file.read_text())
                os.kill(pid, 0)   # probe — raises if dead
                adopted[role] = pid
            except (ProcessLookupError, ValueError):
                pid_file.unlink(missing_ok=True)
        return adopted

    async def tail_log(self, role: str) -> AsyncGenerator[str, None]:
        log_path = self.logs_dir / f"{role}.log"
        if not log_path.exists():
            return
        with open(log_path) as f:
            f.seek(0, 2)   # seek to end
            while True:
                line = f.readline()
                if line:
                    yield line.rstrip()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_process_manager.py -x`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/__init__.py cli/control/process_manager.py \
        tests/test_process_manager.py
git commit -m "feat(control): add process manager (launch, kill, adopt_orphans)"
```

---

## Task 3: Task Queue

**Files:**
- Create: `cli/control/queue.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_queue.py
import sys; sys.path.insert(0, ".")
from cli.control.queue import TaskQueue
from pathlib import Path

def test_enqueue_dequeue(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    tid = q.enqueue(role="backend-specialist", skill="security-scan",
                    model="claude-sonnet-4-6", prompt="scan auth/")
    tasks = q.list_all()
    assert len(tasks) == 1 and tasks[0]["id"] == tid
    q.update_status(tid, "running")
    assert q.list_all()[0]["status"] == "running"

def test_concurrent_enqueue(tmp_path):
    q = TaskQueue(tmp_path / "queue")
    ids = {q.enqueue("tech-writer", None, "claude-sonnet-4-6", f"t{i}") for i in range(5)}
    assert len(ids) == 5          # all distinct filenames
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_queue.py -x`
Expected: FAIL — `ModuleNotFoundError: cli.control.queue`

- [ ] **Step 3: Write minimal implementation**

```python
# cli/control/queue.py
import json, time
from pathlib import Path

class TaskQueue:
    def __init__(self, queue_dir: Path):
        self.dir = queue_dir
        self.dir.mkdir(parents=True, exist_ok=True)

    def enqueue(self, role: str, skill: str | None,
                model: str, prompt: str) -> str:
        tid = f"{int(time.time() * 1000):016d}"
        task = {"id": tid, "role": role, "skill": skill,
                "model": model, "prompt": prompt,
                "status": "queued",
                "created_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
        (self.dir / f"{tid}-{role}.json").write_text(json.dumps(task, indent=2))
        return tid

    def list_all(self) -> list[dict]:
        tasks = []
        for f in sorted(self.dir.glob("*.json")):
            tasks.append(json.loads(f.read_text()))
        return tasks

    def update_status(self, tid: str, status: str) -> None:
        for f in self.dir.glob(f"{tid}-*.json"):
            data = json.loads(f.read_text())
            data["status"] = status
            f.write_text(json.dumps(data, indent=2))
            return

    def dequeue(self, tid: str) -> None:
        for f in self.dir.glob(f"{tid}-*.json"):
            f.unlink()
            return
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_queue.py -x`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/queue.py tests/test_queue.py
git commit -m "feat(control): add task queue (enqueue, dequeue, update_status)"
```

---

## Task 4: Skill Matcher

**Files:**
- Create: `cli/control/skill_matcher.py`

- [ ] **Step 1: Write the failing test**

```python
# tests/test_skill_matcher.py
import sys; sys.path.insert(0, ".")
from cli.control.skill_matcher import SkillMatcher
from pathlib import Path

MOCK_SKILLS = {
    "security-scan": {"keywords": ["auth", "jwt", "secret"], "model": None},
    "money-review":  {"keywords": ["payment", "stripe"],     "model": "claude-opus-4-7"},
}

def make_matcher(tmp_path):
    return SkillMatcher(skills_dir=tmp_path, _mock=MOCK_SKILLS)

def test_slash_command(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/security-scan src/auth/", role_model="claude-sonnet-4-6")
    assert r.skill == "security-scan"
    assert r.model == "claude-sonnet-4-6"   # no skill-level model → role default

def test_slash_with_model_flag(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/security-scan --model opus", role_model="claude-sonnet-4-6")
    assert r.model == "claude-opus-4-7"

def test_nl_single_match(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("check jwt tokens", role_model="claude-sonnet-4-6")
    assert r.skill == "security-scan" and r.needs_confirm is True

def test_nl_no_match(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("refactor the database layer", role_model="claude-sonnet-4-6")
    assert r.skill is None and r.raw_prompt == "refactor the database layer"

def test_skill_model_wins_over_role(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/money-review", role_model="claude-sonnet-4-6")
    assert r.model == "claude-opus-4-7"    # skill frontmatter wins
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_skill_matcher.py -x`
Expected: FAIL — `ModuleNotFoundError: cli.control.skill_matcher`

- [ ] **Step 3: Write minimal implementation**

```python
# cli/control/skill_matcher.py
import re
from dataclasses import dataclass
from pathlib import Path

MODEL_ALIASES = {"opus": "claude-opus-4-7", "sonnet": "claude-sonnet-4-6",
                 "haiku": "claude-haiku-4-5-20251001"}

@dataclass
class MatchResult:
    skill: str | None
    model: str
    raw_prompt: str
    needs_confirm: bool = False
    ambiguous: list[str] | None = None

class SkillMatcher:
    def __init__(self, skills_dir: Path, _mock: dict | None = None):
        self._catalog = _mock if _mock is not None else self._load(skills_dir)

    def _load(self, skills_dir: Path) -> dict:
        catalog = {}
        for skill_md in skills_dir.glob("*/SKILL.md"):
            skill = skill_md.parent.name
            text = skill_md.read_text()
            kw = re.findall(r"keywords:\s*\[([^\]]+)\]", text)
            keywords = [w.strip().strip('"') for w in kw[0].split(",")] if kw else []
            model_m = re.search(r"^model:\s*(\S+)", text, re.MULTILINE)
            catalog[skill] = {"keywords": keywords,
                              "model": model_m.group(1) if model_m else None}
        return catalog

    def _resolve_model(self, flag: str | None, skill: str | None,
                       role_model: str) -> str:
        if flag:
            return MODEL_ALIASES.get(flag, flag)
        if skill and self._catalog.get(skill, {}).get("model"):
            m = self._catalog[skill]["model"]
            return MODEL_ALIASES.get(m, m)
        return MODEL_ALIASES.get(role_model, role_model)

    def resolve(self, text: str, role_model: str) -> MatchResult:
        text = text.strip()
        # slash command
        if text.startswith("/"):
            parts = text[1:].split()
            skill = parts[0] if parts else None
            model_flag = None
            raw = text
            if "--model" in parts:
                idx = parts.index("--model")
                model_flag = parts[idx + 1] if idx + 1 < len(parts) else None
                parts = [p for i, p in enumerate(parts) if i not in (idx, idx+1)]
            raw = " ".join(parts[1:]) if len(parts) > 1 else ""
            return MatchResult(skill=skill, raw_prompt=raw,
                               model=self._resolve_model(model_flag, skill, role_model))
        # natural language
        matched = [s for s, meta in self._catalog.items()
                   if any(kw in text.lower() for kw in meta["keywords"])]
        if len(matched) == 1:
            skill = matched[0]
            return MatchResult(skill=skill, raw_prompt=text, needs_confirm=True,
                               model=self._resolve_model(None, skill, role_model))
        if len(matched) > 1:
            return MatchResult(skill=None, raw_prompt=text, ambiguous=matched,
                               model=self._resolve_model(None, None, role_model))
        return MatchResult(skill=None, raw_prompt=text,
                           model=self._resolve_model(None, None, role_model))
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_skill_matcher.py -x`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/skill_matcher.py tests/test_skill_matcher.py
git commit -m "feat(control): add skill matcher (slash, NL, model resolution)"
```

---

## Task 5: Scheduler

**Files:**
- Create: `cli/control/scheduler.py`
- Create: `.octopus/schedule.yml` (example)

- [ ] **Step 1: Write the failing test**

```python
# tests/test_scheduler.py
import sys; sys.path.insert(0, ".")
from cli.control.scheduler import CronParser
from datetime import datetime

def test_daily(monkeypatch):
    cp = CronParser()
    now = datetime(2026, 4, 22, 8, 59, 0)
    assert cp.fires_at("daily 09:00", now) is False
    now = datetime(2026, 4, 22, 9, 0, 0)
    assert cp.fires_at("daily 09:00", now) is True

def test_weekly(monkeypatch):
    cp = CronParser()
    # 2026-04-20 is a Monday
    assert cp.fires_at("Mon 08:00", datetime(2026, 4, 20, 8, 0)) is True
    assert cp.fires_at("Mon 08:00", datetime(2026, 4, 21, 8, 0)) is False

def test_disabled(monkeypatch):
    cp = CronParser()
    assert cp.fires_at("daily 09:00", datetime(2026, 4, 22, 9, 0),
                       enabled=False) is False
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python3 -m pytest tests/test_scheduler.py -x`
Expected: FAIL — `ModuleNotFoundError: cli.control.scheduler`

- [ ] **Step 3: Write minimal implementation**

```python
# cli/control/scheduler.py
import threading, time, yaml
from datetime import datetime
from pathlib import Path

DAYS = {"mon": 0, "tue": 1, "wed": 2, "thu": 3, "fri": 4, "sat": 5, "sun": 6}

class CronParser:
    def fires_at(self, when: str, now: datetime, enabled: bool = True) -> bool:
        if not enabled:
            return False
        parts = when.strip().lower().split()
        if parts[0] == "daily":
            h, m = map(int, parts[1].split(":"))
            return now.hour == h and now.minute == m
        if parts[0] in DAYS:
            h, m = map(int, parts[1].split(":"))
            return now.weekday() == DAYS[parts[0]] and now.hour == h and now.minute == m
        return False

class Scheduler(threading.Thread):
    def __init__(self, schedule_path: Path, on_fire):
        super().__init__(daemon=True)
        self.path = schedule_path
        self.on_fire = on_fire   # callback(entry: dict)
        self._stop = threading.Event()
        self._parser = CronParser()

    def run(self):
        while not self._stop.wait(timeout=30):
            if not self.path.exists():
                continue
            entries = yaml.safe_load(self.path.read_text()) or []
            now = datetime.now().replace(second=0, microsecond=0)
            for entry in entries:
                if self._parser.fires_at(entry.get("when", ""),
                                         now, entry.get("enabled", True)):
                    self.on_fire(entry)

    def stop(self):
        self._stop.set()
```

```yaml
# .octopus/schedule.yml (example)
- id: s1
  when: "daily 09:00"
  role: backend-specialist
  skill: security-scan
  enabled: true
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python3 -m pytest tests/test_scheduler.py -x`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/scheduler.py tests/test_scheduler.py .octopus/schedule.yml
git commit -m "feat(control): add scheduler (cron parser + background thread)"
```

---

## Task 6a: TUI Visual Design — Stylesheet + Theme

**Files:**
- Create: `cli/control/app.tcss`

- [ ] **Step 1: Write the failing test**

```bash
echo "Test: app.tcss exists and defines accent color"
grep -q "7B2FBE" cli/control/app.tcss \
  || { echo "FAIL: accent color missing from app.tcss"; exit 1; }
grep -q "1a1a2e" cli/control/app.tcss \
  || { echo "FAIL: background color missing from app.tcss"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_control.sh`
Expected: FAIL — `app.tcss` does not exist

- [ ] **Step 3: Write minimal implementation**

```css
/* cli/control/app.tcss */

/* ── Palette ─────────────────────────────────────── */
$accent:   #7B2FBE;
$ocean:    #00B4D8;
$bg:       #1a1a2e;
$surface:  #16213e;
$text-dim: #6c757d;
$green:    #06d6a0;
$red:      #ef476f;

/* ── App shell ───────────────────────────────────── */
Screen {
    background: $bg;
    color: white;
}

Header {
    background: $surface;
    color: $ocean;
    text-style: bold;
}

Footer {
    background: $surface;
    color: $text-dim;
}

/* ── Panels ──────────────────────────────────────── */
#agents, #queue, #schedule {
    border: round $surface;
    background: $surface;
    padding: 0 1;
}

#agents:focus-within, #queue:focus-within,
#output:focus-within, #schedule:focus-within {
    border: heavy $accent;
}

#output {
    border: round $surface;
    background: $bg;
    color: $text-dim;
    padding: 0 1;
}

/* ── Command bar ─────────────────────────────────── */
#cmd {
    dock: bottom;
    background: $surface;
    border: heavy $ocean;
    color: white;
    margin: 0 1;
}

#cmd.hidden {
    display: none;
}

/* ── Status colors ───────────────────────────────── */
.status-running { color: $green; }
.status-idle    { color: $text-dim; }
.status-failed  { color: $red; }
.status-queued  { color: $ocean; }
.status-done    { color: $green; text-style: dim; }
```

The ASCII octopus header is rendered in `on_mount` via a `Static` widget
with `$text-dim` markup:

```python
# in app.py compose():
yield Static(
    "[dim]  (\\/)\n ( oo)\n  ||||[/dim]  "
    f"[bold {self.CSS_VARIABLES['ocean']}]🐙 Octopus Control[/bold]",
    id="logo"
)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_control.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.tcss tests/test_control.sh
git commit -m "feat(control): TUI visual design — palette, borders, ASCII octopus header"
```

---

## Task 6b: TUI Scaffold — App Shell + AgentRoster

**Files:**
- Create: `cli/control/app.py` (skeleton)

- [ ] **Step 1: Write the failing test**

```bash
# in tests/test_control.sh
echo "Test: octopus control --help mentions TUI"
bash cli/octopus.sh control --help | grep -q "dashboard" \
  || { echo "FAIL: --help missing 'dashboard'"; exit 1; }
echo "PASS"
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_control.sh`
Expected: FAIL — `dashboard` not in help output

- [ ] **Step 3: Write minimal implementation**

```python
# cli/control/app.py
from textual.app import App, ComposeResult
from textual.widgets import DataTable, Header, Footer
from textual.binding import Binding
from pathlib import Path
from .process_manager import ProcessManager
from .queue import TaskQueue

class OctopusControl(App):
    TITLE = "Octopus Control"
    BINDINGS = [
        Binding("a", "add_task",   "Add task"),
        Binding("p", "pause",      "Pause"),
        Binding("k", "kill_agent", "Kill"),
        Binding("tab", "focus_next", "Focus", show=False),
        Binding("q", "request_quit", "Quit"),
    ]

    def __init__(self, octopus_dir: Path):
        super().__init__()
        self.octopus_dir = octopus_dir
        self.pm = ProcessManager(octopus_dir)
        self.queue = TaskQueue(octopus_dir / "queue")
        self._agents: dict[str, int] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        yield DataTable(id="agents")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.add_columns("Role", "Status", "Task")
        self._agents = self.pm.adopt_orphans()
        self._refresh_roster()
        self.set_interval(1, self._refresh_roster)

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.clear()
        for role, pid in self._agents.items():
            table.add_row(role, "● running", "–", key=role)
```

Update `cli/lib/control.sh` help text to include "dashboard".

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_control.sh`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py cli/lib/control.sh tests/test_control.sh
git commit -m "feat(control): TUI scaffold — App shell + AgentRoster panel"
```

---

## Task 6c: TUI Panels — TaskQueue, SchedulePanel, CommandBar

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write the failing test**

```bash
echo "Test: python import of app has TaskQueue and SchedulePanel"
python3 -c "
from cli.control.app import OctopusControl
import inspect, textual.widgets as w
src = inspect.getsource(OctopusControl.compose)
assert 'queue' in src.lower() and 'schedule' in src.lower(), 'panels missing'
print('PASS')
"</p>
```

- [ ] **Step 2: Run test to verify it fails**

Run: the python3 command above
Expected: FAIL — `AssertionError: panels missing`

- [ ] **Step 3: Write minimal implementation**

Extend `compose()` and add `CommandBar` input + `action_add_task()`:

```python
from textual.widgets import Input, ListView, ListItem, Label
from textual.containers import Horizontal, Vertical
from .skill_matcher import SkillMatcher
from .scheduler import Scheduler

# in compose():
    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="left"):
                yield DataTable(id="agents")
            with Vertical(id="right"):
                yield ListView(id="queue")
                yield DataTable(id="schedule")
        yield Label("", id="output")
        yield Input(placeholder="[a] add task…", id="cmd", classes="hidden")
        yield Footer()

    def action_add_task(self) -> None:
        cmd = self.query_one("#cmd", Input)
        cmd.remove_class("hidden")
        cmd.focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        self.query_one("#cmd", Input).add_class("hidden")
        if not text:
            return
        # resolve skill and enqueue
        result = self._matcher.resolve(text, role_model="claude-sonnet-4-6")
        self.queue.enqueue(
            role=self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
        self._refresh_queue()
```

- [ ] **Step 4: Run test to verify it passes**

Run: the python3 command above
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): TUI panels — TaskQueue, SchedulePanel, CommandBar"
```

---

## Task 6d: TUI Live Output + Exit Prompt

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Write the failing test**

```bash
echo "Test: app source has exit prompt s/d/c logic"
python3 -c "
import inspect
from cli.control.app import OctopusControl
src = inspect.getsource(OctopusControl)
assert 'detach' in src and 'stop' in src, 'exit prompt missing'
print('PASS')
"
```

- [ ] **Step 2: Run test to verify it fails**

Run: the python3 command above
Expected: FAIL — `AssertionError: exit prompt missing`

- [ ] **Step 3: Write minimal implementation**

```python
# add to OctopusControl:
    async def action_request_quit(self) -> None:
        if not self._agents:
            self.exit()
            return
        # Show exit prompt
        self.notify("[s]top  [d]etach  [c]ancel", title="Agents running")
        self._awaiting_exit = True

    def on_key(self, event) -> None:
        if not getattr(self, "_awaiting_exit", False):
            return
        if event.key == "s":
            for role in list(self._agents):
                self.pm.kill(role)
            self.exit()
        elif event.key == "d":
            self.exit()   # detach: leave PIDs alive
        elif event.key == "c":
            self._awaiting_exit = False

    # async log tailer wired to OutputPanel via worker
    def watch_agent_output(self, role: str) -> None:
        async def _tail():
            async for line in self.pm.tail_log(role):
                self.query_one("#output", Label).update(line)
        self.run_worker(_tail())
```

- [ ] **Step 4: Run test to verify it passes**

Run: the python3 command above
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): TUI live output tail + exit prompt (stop/detach/cancel)"
```

---

## Task 7: Integration Tests

**Files:**
- Modify: `tests/test_control.sh`
- Modify: `tests/test_skill_matcher.py` (add edge cases)

- [ ] **Step 1: Write the failing test**

```bash
echo "Test: adopt_orphans integration"
python3 - << 'PYEOF'
import subprocess, sys, time
from pathlib import Path
sys.path.insert(0, ".")
from cli.control.process_manager import ProcessManager

tmp = Path("/tmp/octopus-test-adopt")
tmp.mkdir(exist_ok=True)
pm = ProcessManager(tmp)
proc = subprocess.Popen(["sleep", "60"])
(tmp / "pids").mkdir(exist_ok=True)
(tmp / "pids" / "backend-specialist.pid").write_text(str(proc.pid))
adopted = pm.adopt_orphans()
assert "backend-specialist" in adopted, f"not adopted: {adopted}"
proc.terminate()
(tmp / "pids" / "backend-specialist.pid").unlink(missing_ok=True)
print("PASS: adopt_orphans")
PYEOF
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bash tests/test_control.sh`
Expected: FAIL on the new adopt_orphans test block

- [ ] **Step 3: Write minimal implementation**

Add the adopt_orphans integration block to `tests/test_control.sh`.
Add edge-case tests to `tests/test_skill_matcher.py`:
- NL input with two matching skills → `ambiguous` list returned
- Slash command with unknown skill → `MatchResult(skill="unknown-skill", ...)`
- Empty input → `MatchResult(skill=None, raw_prompt="")`

- [ ] **Step 4: Run test to verify it passes**

Run: `bash tests/test_control.sh && python3 -m pytest tests/test_skill_matcher.py -v`
Expected: all PASS

- [ ] **Step 5: Commit**

```bash
git add tests/test_control.sh tests/test_skill_matcher.py
git commit -m "test(control): integration + edge-case tests for process manager and skill matcher"
```
