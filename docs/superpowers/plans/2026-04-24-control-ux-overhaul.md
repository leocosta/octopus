# Control & Run UX Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `octopus control` and `octopus run` feel usable — add `octopus ask <role> "task"` for terminal-first delegation with live streaming, wire `@role:` syntax into the TUI command bar, add mini-feed inline in the agents roster, focus output on cursor navigation, and emit structured progress from the pipeline runner.

**Architecture:** Three independent layers share the same `.octopus/` backend: (1) `ask.py` — a new Python module that launches an agent and tails its log to stdout; (2) `skill_matcher.py` gains `@role:` prefix parsing; (3) `app.py` gets three targeted event handlers for mini-feed, cursor-focus, and Enter-to-delegate. `pipeline.py` gets `print()` calls at task boundaries so `octopus run` gives live feedback.

**Tech Stack:** Python 3.11+, Textual (existing), bash, `ProcessManager` and `TaskQueue` (existing).

**Spec:** `docs/superpowers/specs/2026-04-24-control-ux-overhaul-design.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `cli/control/ask.py` | create | Launch agent, tail log to stdout, Ctrl+C kill/detach |
| `cli/lib/ask.sh` | create | `octopus ask` bash entry point |
| `cli/octopus.sh` | modify | Add `ask` to help text |
| `cli/control/skill_matcher.py` | modify | Pre-parse `@role:` prefix; add `role_override` to `MatchResult` |
| `cli/control/app.py` | modify | Mini-feed, cursor-focus-output, Enter-to-delegate prefill, `@role:` routing |
| `cli/control/pipeline.py` | modify | Structured `print()` at task start/end/pipeline-end |
| `tests/test_skill_matcher.py` | modify | Tests for `@role:` parsing and `role_override` field |
| `tests/test_ask.py` | create | Unit tests for `ask.py` (dry-run, output format) |
| `tests/test_control.sh` | modify | `octopus ask --help` integration test |

---

## Task 1: `@role:` prefix parsing in SkillMatcher

Add `role_override` to `MatchResult` and pre-parse `@role:` prefix in `resolve()`.

**Files:**
- Modify: `cli/control/skill_matcher.py`
- Modify: `tests/test_skill_matcher.py`

- [ ] **Step 1: Write failing tests**

Append to `tests/test_skill_matcher.py`:

```python
def test_at_role_prefix_extracted(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@tech-writer: write the ADR", role_model="claude-sonnet-4-6")
    assert r.role_override == "tech-writer"
    assert r.raw_prompt == "write the ADR"


def test_at_role_prefix_with_slash_skill(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@backend-specialist: /security-scan src/auth/", role_model="claude-sonnet-4-6")
    assert r.role_override == "backend-specialist"
    assert r.skill == "security-scan"


def test_no_at_role_prefix_unchanged(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("write the ADR", role_model="claude-sonnet-4-6")
    assert r.role_override is None


def test_at_role_with_hyphen(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@frontend-specialist: build the login screen", role_model="claude-sonnet-4-6")
    assert r.role_override == "frontend-specialist"
    assert r.raw_prompt == "build the login screen"
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_skill_matcher.py -v 2>&1 | tail -10`
Expected: FAIL with `AttributeError: 'MatchResult' object has no attribute 'role_override'`

- [ ] **Step 3: Add `role_override` to `MatchResult` and pre-parse in `resolve()`**

Edit `cli/control/skill_matcher.py`:

```python
@dataclass
class MatchResult:
    skill: str | None
    model: str
    raw_prompt: str
    needs_confirm: bool = False
    ambiguous: list[str] | None = None
    role_override: str | None = None  # set when input starts with @role:
```

In `resolve()`, add before the existing `if text.startswith("/"):` block:

```python
    def resolve(self, text: str, role_model: str) -> MatchResult:
        text = text.strip()

        # Pre-parse @role: prefix
        role_override = None
        at_match = re.match(r'^@([\w-]+):\s*', text)
        if at_match:
            role_override = at_match.group(1)
            text = text[at_match.end():]

        if text.startswith("/"):
            parts = text[1:].split()
            skill = parts[0] if parts else None
            model_flag = None
            if "--model" in parts:
                idx = parts.index("--model")
                model_flag = parts[idx + 1] if idx + 1 < len(parts) else None
                parts = [p for i, p in enumerate(parts) if i not in (idx, idx + 1)]
            raw = " ".join(parts[1:]) if len(parts) > 1 else ""
            return MatchResult(
                skill=skill,
                raw_prompt=raw,
                model=self._resolve_model(model_flag, skill, role_model),
                role_override=role_override,
            )
        matched = [
            s for s, meta in self._catalog.items()
            if any(kw in text.lower() for kw in meta["keywords"])
        ]
        if len(matched) == 1:
            skill = matched[0]
            return MatchResult(
                skill=skill,
                raw_prompt=text,
                needs_confirm=True,
                model=self._resolve_model(None, skill, role_model),
                role_override=role_override,
            )
        if len(matched) > 1:
            return MatchResult(
                skill=None,
                raw_prompt=text,
                ambiguous=matched,
                model=self._resolve_model(None, None, role_model),
                role_override=role_override,
            )
        return MatchResult(
            skill=None,
            raw_prompt=text,
            model=self._resolve_model(None, None, role_model),
            role_override=role_override,
        )
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_skill_matcher.py -v 2>&1 | tail -15`
Expected: all 12 tests PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/skill_matcher.py tests/test_skill_matcher.py
git commit -m "feat(control): @role: prefix parsing in SkillMatcher

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 2: `cli/control/ask.py` — core ask module

New Python module that launches an agent and streams its log to stdout.

**Files:**
- Create: `cli/control/ask.py`
- Create: `tests/test_ask.py`

- [ ] **Step 1: Write failing tests**

Create `tests/test_ask.py`:

```python
import sys
import textwrap
import subprocess
sys.path.insert(0, ".")
from pathlib import Path
from unittest.mock import patch, MagicMock
from cli.control.ask import ask, build_full_prompt


def test_build_full_prompt_no_skill():
    assert build_full_prompt("write the ADR", None) == "write the ADR"


def test_build_full_prompt_with_namespaced_skill():
    assert build_full_prompt("write the ADR", "octopus:doc-adr") == "/octopus:doc-adr write the ADR"


def test_build_full_prompt_with_bare_skill():
    assert build_full_prompt("scan auth/", "security-scan") == "/octopus:security-scan scan auth/"


def test_dry_run_exits_zero(tmp_path):
    result = subprocess.run(
        [sys.executable, "-m", "cli.control.ask", "tech-writer", "write ADR", "--dry-run"],
        capture_output=True, text=True
    )
    assert result.returncode == 0
    assert "dry-run" in result.stdout


def test_dry_run_prints_role_and_task(tmp_path):
    result = subprocess.run(
        [sys.executable, "-m", "cli.control.ask", "backend-specialist", "scan auth/", "--dry-run"],
        capture_output=True, text=True
    )
    assert "backend-specialist" in result.stdout
    assert "scan auth/" in result.stdout
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_ask.py -v 2>&1 | tail -10`
Expected: FAIL with `ModuleNotFoundError: No module named 'cli.control.ask'`

- [ ] **Step 3: Create `cli/control/ask.py`**

```python
from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path

from .process_manager import ProcessManager

_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
_TAIL_POLL = 0.15
_LOG_WAIT_POLLS = 50


def build_full_prompt(task: str, skill: str | None) -> str:
    if not skill:
        return task
    cmd = skill if ":" in skill else f"octopus:{skill}"
    return f"/{cmd} {task}".strip()


def ask(
    role: str,
    task: str,
    model: str,
    octopus_dir: Path,
    skill: str | None = None,
) -> int:
    """Launch an agent and stream its log to stdout. Returns the exit code."""
    pm = ProcessManager(octopus_dir)
    full_prompt = build_full_prompt(task, skill)

    print(f"◆ {role} · {task[:80]}")
    print("─" * 50)

    started = time.time()
    pm.launch(role=role, prompt=full_prompt, model=model)

    log_path = pm.logs_dir / f"{role}.log"
    detached = [False]

    original_sigint = signal.getsignal(signal.SIGINT)

    def _handle_sigint(sig, frame):
        sys.stdout.write("\n[k]ill  [d]etach  [c]ancel: ")
        sys.stdout.flush()
        choice = sys.stdin.readline().strip().lower()
        if choice == "k":
            pm.kill(role)
            signal.signal(signal.SIGINT, original_sigint)
            sys.exit(1)
        elif choice == "d":
            detached[0] = True

    signal.signal(signal.SIGINT, _handle_sigint)

    # Wait for log file to appear
    for _ in range(_LOG_WAIT_POLLS):
        if log_path.exists():
            break
        time.sleep(0.1)

    tick = 0
    try:
        with open(log_path) as f:
            while True:
                if detached[0]:
                    print(f"\n[detached]  log: {log_path}")
                    signal.signal(signal.SIGINT, original_sigint)
                    return 0
                line = f.readline()
                if line:
                    ts = time.strftime("%H:%M:%S")
                    # Clear spinner line before writing log output
                    sys.stdout.write(f"\r{' ' * 30}\r")
                    print(f"{ts}  {line.rstrip()}")
                else:
                    code = pm.exit_code(role)
                    if code is not None:
                        break
                    frame = _SPINNER[tick % len(_SPINNER)]
                    elapsed = int(time.time() - started)
                    sys.stdout.write(f"\r{frame} running  {elapsed}s")
                    sys.stdout.flush()
                    tick += 1
                    time.sleep(_TAIL_POLL)
    finally:
        signal.signal(signal.SIGINT, original_sigint)

    elapsed = int(time.time() - started)
    code = pm.exit_code(role) or 0
    sys.stdout.write(f"\r{' ' * 30}\r")
    print("─" * 50)
    if code == 0:
        print(f"✓ done  {elapsed}s")
    else:
        print(f"✗ failed  {elapsed}s  ·  exit code {code}")
        escaped = task.replace('"', '\\"')
        print(f'  → octopus ask {role} "{escaped}" --retry')
    print(f"  log: {log_path}")
    return code


def main() -> None:
    import argparse

    p = argparse.ArgumentParser(prog="octopus-ask")
    p.add_argument("role", help="Agent role (e.g. tech-writer)")
    p.add_argument("task", help="Task description")
    p.add_argument("--skill", default=None, help="Octopus skill to invoke")
    p.add_argument("--model", default="claude-sonnet-4-6")
    p.add_argument("--dry-run", action="store_true")
    args = p.parse_args()

    octopus_dir = Path(".octopus")
    octopus_dir.mkdir(exist_ok=True)

    if args.dry_run:
        prompt = build_full_prompt(args.task, args.skill)
        print(f"[dry-run] ask {args.role}: {prompt}")
        sys.exit(0)

    sys.exit(ask(
        role=args.role,
        task=args.task,
        model=args.model,
        octopus_dir=octopus_dir,
        skill=args.skill,
    ))


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pytest tests/test_ask.py -v 2>&1 | tail -10`
Expected: all 5 tests PASS

- [ ] **Step 5: Commit**

```bash
git add cli/control/ask.py tests/test_ask.py
git commit -m "feat(control): ask.py — terminal-first agent delegation with live log tail

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 3: `octopus ask` bash wiring

Create `cli/lib/ask.sh` and add `ask` to `cli/octopus.sh`.

**Files:**
- Create: `cli/lib/ask.sh`
- Modify: `cli/octopus.sh`
- Modify: `tests/test_control.sh`

- [ ] **Step 1: Create `cli/lib/ask.sh`**

```bash
#!/usr/bin/env bash
set -euo pipefail
source "$CLI_DIR/lib/ui.sh"

if [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: octopus ask <role> "<task>" [--skill <skill>] [--model <model>] [--dry-run]

Dispatch a task to a specific agent and stream its output live in the terminal.
Ctrl+C during streaming offers [k]ill, [d]etach (keep running in background), or [c]ancel.

Examples:
  octopus ask tech-writer "write ADR for JWT authentication"
  octopus ask backend-specialist "run security audit on src/auth/"
  octopus ask tech-writer "write ADR" --skill octopus:doc-adr
  octopus ask tech-writer "write ADR" --dry-run
EOF
  exit 0
fi

ROLE="${1:-}"
TASK="${2:-}"

if [[ -z "$ROLE" ]]; then
  ui_error "Role is required. Usage: octopus ask <role> \"<task>\""
  exit 1
fi

if [[ -z "$TASK" ]]; then
  ui_error "Task is required. Usage: octopus ask <role> \"<task>\""
  exit 1
fi

PYTHONPATH="$(dirname "$CLI_DIR")" python3 -m cli.control.ask "$ROLE" "$TASK" "${@:3}"
```

- [ ] **Step 2: Add `ask` to `cli/octopus.sh` help text**

Read `cli/octopus.sh` to find the Commands section, then add after the `control` line:

```bash
  echo "  ask            Dispatch a task to a specific agent with live streaming output"
```

- [ ] **Step 3: Add bash integration test**

Append to `tests/test_control.sh`:

```bash
# Test: octopus ask --help shows usage
test_ask_help() {
  local output
  output=$(bash cli/octopus.sh ask --help 2>&1)
  if echo "$output" | grep -q "Usage: octopus ask"; then
    echo "PASS: octopus ask --help"
  else
    echo "FAIL: octopus ask --help — output was:"
    echo "$output"
    return 1
  fi
}
test_ask_help

# Test: octopus ask --dry-run exits 0 and prints role
test_ask_dry_run() {
  local output
  output=$(bash cli/octopus.sh ask tech-writer "write the ADR" --dry-run 2>&1)
  if echo "$output" | grep -q "tech-writer"; then
    echo "PASS: octopus ask --dry-run"
  else
    echo "FAIL: octopus ask --dry-run — output was:"
    echo "$output"
    return 1
  fi
}
test_ask_dry_run
```

- [ ] **Step 4: Run bash tests**

Run: `bash tests/test_control.sh 2>&1 | grep -E "PASS|FAIL"`
Expected: `PASS: octopus ask --help` and `PASS: octopus ask --dry-run`

- [ ] **Step 5: Commit**

```bash
git add cli/lib/ask.sh cli/octopus.sh tests/test_control.sh
git commit -m "feat(control): octopus ask bash entry point and help text

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 4: TUI mini-feed — last log line inline in agents roster

Add `_last_log_line()` helper and use it in `_refresh_roster()`.

**Files:**
- Modify: `cli/control/app.py` (lines ~193-203 in `_refresh_roster`)

- [ ] **Step 1: Add `_last_log_line()` method to `OctopusControl`**

Add this method after `_refresh_roster` in `app.py`:

```python
def _last_log_line(self, role: str) -> str:
    log_path = self.pm.logs_dir / f"{role}.log"
    if not log_path.exists():
        return ""
    try:
        stat = log_path.stat()
        if stat.st_size == 0:
            return ""
        with open(log_path, "rb") as f:
            f.seek(max(0, stat.st_size - 300))
            tail = f.read().decode("utf-8", errors="replace")
        lines = [ln.strip() for ln in tail.splitlines() if ln.strip()]
        return lines[-1] if lines else ""
    except OSError:
        return ""
```

- [ ] **Step 2: Update `_refresh_roster()` to show mini-feed**

Replace the current `_refresh_roster` method:

```python
def _refresh_roster(self) -> None:
    table = self.query_one("#agents", DataTable)
    table.clear()
    frame = _SPINNER[self._tick % len(_SPINNER)]
    self._tick += 1
    for role in self._agents:
        elapsed = int(time.time() - self._agent_started.get(role, time.time()))
        mins, secs = divmod(elapsed, 60)
        elapsed_str = f"{mins}m{secs:02d}s" if mins else f"{secs}s"
        last_line = self._last_log_line(role)
        if last_line:
            truncated = last_line[:38] + "…" if len(last_line) > 38 else last_line
            status = f"{frame} {elapsed_str}  [dim]{truncated}[/dim]"
        else:
            status = f"{frame} {elapsed_str}"
        table.add_row(role, status, key=role)
```

- [ ] **Step 3: Verify import works and existing tests pass**

Run: `python3 -c "from cli.control.app import OctopusControl; print('ok')"` in project root
Expected: `ok`

Run: `pytest tests/test_process_manager.py tests/test_queue.py -q 2>&1 | tail -5`
Expected: all PASS

- [ ] **Step 4: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): mini-feed — last log line inline in agents roster

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 5: TUI — focus Output on cursor navigation

Add `on_data_table_row_highlighted` to switch the Output panel when navigating the agents table.

**Files:**
- Modify: `cli/control/app.py` (add new event handler after `_selected_role`)

- [ ] **Step 1: Add `on_data_table_row_highlighted` handler**

Add this method after `_selected_role` in `app.py`:

```python
def on_data_table_row_highlighted(self, event: DataTable.RowHighlighted) -> None:
    if event.data_table.id != "agents":
        return
    if event.row_key is None:
        return
    role = str(event.row_key.value)
    log_widget = self.query_one("#output", RichLog)
    log_path = self.pm.logs_dir / f"{role}.log"
    log_widget.clear()
    if role in self._agents:
        log_widget.border_title = f"Output · {role} · live"
    else:
        log_widget.border_title = f"Output · {role}"
    if log_path.exists():
        # Show last 50 lines to avoid flooding the widget
        lines = log_path.read_text().splitlines()
        for line in lines[-50:]:
            log_widget.write(line)
```

- [ ] **Step 2: Verify import still works**

Run: `python3 -c "from cli.control.app import OctopusControl; print('ok')"`
Expected: `ok`

- [ ] **Step 3: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): focus Output panel on agents table cursor navigation

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 6: TUI — Enter on idle agent prefills `@role:` + `@role:` routing on submit

Two changes in `app.py`: (1) `action_add_task` prefills command bar; (2) `on_input_submitted` uses `role_override`.

**Files:**
- Modify: `cli/control/app.py` (`action_add_task` and `on_input_submitted`)

- [ ] **Step 1: Update `action_add_task` to prefill `@role:` for idle agents**

Replace the current `action_add_task` method:

```python
def action_add_task(self) -> None:
    cmd = self.query_one("#cmd", Input)
    selected_role = self._selected_role()
    # Idle agent (not currently running) → prefill @role: as delegation shortcut
    if selected_role != "agent" and selected_role not in self._agents:
        cmd.value = f"@{selected_role}: "
        cmd.cursor_position = len(cmd.value)
    cmd.remove_class("hidden")
    cmd.focus()
```

- [ ] **Step 2: Update `on_input_submitted` to use `role_override`**

Find the `self.queue.enqueue(` call inside `on_input_submitted` and replace:

```python
        self.queue.enqueue(
            role=self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
```

with:

```python
        self.queue.enqueue(
            role=result.role_override or self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
```

- [ ] **Step 3: Verify import and existing skill_matcher tests pass**

Run: `python3 -c "from cli.control.app import OctopusControl; print('ok')"`
Expected: `ok`

Run: `pytest tests/test_skill_matcher.py -q 2>&1 | tail -5`
Expected: all 12 PASS

- [ ] **Step 4: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): prefill @role: on Enter for idle agents, route @role: on submit

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 7: Pipeline.py — structured progress output

Add `print()` calls at task dispatch, task completion, and pipeline end so `octopus run` gives live feedback.

**Files:**
- Modify: `cli/control/pipeline.py` (the `run()` method)

- [ ] **Step 1: Add `pipeline_start` tracking and progress prints to `run()`**

Replace the `run()` method in `cli/control/pipeline.py`:

```python
def run(self) -> bool:
    """Drive the pipeline to completion. Returns True if all tasks succeeded."""
    model = self._meta.get("model", "claude-sonnet-4-6")
    pipeline_start = time.time()
    task_started: dict[str, float] = {}

    while True:
        busy_agents = self._running_agents()

        for task in self._ready_tasks():
            if task.agent in busy_agents:
                continue
            prompt = self._build_prompt(task)
            self.pm.launch(role=task.agent, prompt=prompt, model=model, isolate=True)
            task.status = "running"
            task_started[task.id] = time.time()
            busy_agents.add(task.agent)
            print(f"  → {task.id}  {task.agent}  {task.body[:60]}", flush=True)

        for task in [t for t in self._tasks if t.status == "running"]:
            code = self.pm.exit_code(task.agent)
            if code is None:
                continue
            elapsed = int(time.time() - task_started.get(task.id, time.time()))
            task.status = "done" if code == 0 else "failed"
            if task.status == "done":
                self._update_checkbox(task.id)
                print(f"  ✓ {task.id}  {task.agent}  {elapsed}s", flush=True)
            else:
                print(f"  ✗ {task.id}  {task.agent}  {elapsed}s", flush=True)

        all_terminal = all(
            t.status in ("done", "skipped", "failed") for t in self._tasks
        )
        if all_terminal:
            break

        still_running = any(t.status == "running" for t in self._tasks)
        has_ready = bool(self._ready_tasks())
        if not still_running and not has_ready:
            break

        time.sleep(_POLL_INTERVAL)

    pipeline_ok = all(t.status in ("done", "skipped") for t in self._tasks)
    total_elapsed = int(time.time() - pipeline_start)

    if pipeline_ok:
        print(f"\n✓ pipeline done  {total_elapsed}s", flush=True)
    else:
        failed_ids = [t.id for t in self._tasks if t.status == "failed"]
        print(f"\n✗ pipeline failed  {total_elapsed}s  ({', '.join(failed_ids)} failed)", flush=True)

    if not pipeline_ok:
        return False

    return self.run_review_gate()
```

- [ ] **Step 2: Run all pipeline tests to confirm no regression**

Run: `pytest tests/test_pipeline.py tests/test_pipeline_format.py -q 2>&1 | tail -8`
Expected: all 17 tests PASS

- [ ] **Step 3: Smoke test progress output via dry-run**

```bash
cat > /tmp/progress-test.md <<'EOF'
---
slug: smoke
pipeline:
  pr_on_success: false
tasks:
  - id: t1
    agent: backend-specialist
    depends_on: []
  - id: t2
    agent: frontend-specialist
    depends_on: [t1]
---

- [ ] **t1** — create schema
- [ ] **t2** — build UI
EOF
PYTHONPATH=. python3 -m cli.control.pipeline /tmp/progress-test.md --dry-run
```

Expected:
```
[dry-run] Pipeline: /tmp/progress-test.md
  t1  agent=backend-specialist  depends_on=[]
  t2  agent=frontend-specialist  depends_on=['t1']
```

Note: progress `print()` calls only fire during actual `run()`, not in `--dry-run`. This is correct.

- [ ] **Step 4: Commit**

```bash
git add cli/control/pipeline.py
git commit -m "feat(pipeline): structured progress output — task start/done/failed + pipeline summary

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 8: Full test suite + roadmap update

Run everything, mark RM-054 in the roadmap.

**Files:**
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Run full Python test suite**

Run: `pytest tests/ -q --tb=short 2>&1 | tail -10`
Expected: all tests PASS (41 existing + 5 new ask tests + 4 new skill_matcher tests = 50 total)

- [ ] **Step 2: Run bash integration tests**

Run: `bash tests/test_control.sh 2>&1 | grep -E "PASS|FAIL"`
Expected: all PASS including `octopus ask --help` and `octopus ask --dry-run`

- [ ] **Step 3: Add RM-054 to roadmap backlog**

In `docs/roadmap.md`, after Cluster 7, add:

```markdown
### Cluster 8 — Control & Run UX Overhaul

| Item | Description |
|---|---|
| **RM-054** | `octopus ask <role> "task"` — terminal-first delegation with live streaming; `@role:` syntax in TUI command bar; mini-feed (last log line inline) in agents roster; focus Output on cursor navigation; structured progress output from `pipeline.py` |
```

- [ ] **Step 4: Commit roadmap**

```bash
git add docs/roadmap.md
git commit -m "chore(roadmap): add RM-054 control & run UX overhaul

Co-authored-by: claude <claude@anthropic.com>"
```
