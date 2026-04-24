# Agent Reply Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Enable replying to agents from the TUI by capturing Claude session IDs via `--output-format=stream-json` and launching resume sessions with `claude --resume`.

**Architecture:** `ProcessManager` gains a `_parse_jsonl()` helper that reads JSONL from Claude's stream-json output, extracts `session_id` to `.octopus/sessions/<role>.session`, and writes plain text to the log — all in a background daemon thread. `launch_resume()` appends to the existing log with a separator. The TUI gets a `[r]eply` keybinding that reads the session file and opens the command bar pre-filled with `↩ <role>: `.

**Tech Stack:** Python 3.11+, `threading`, `json` (stdlib), Textual (existing).

**Spec:** `docs/superpowers/specs/2026-04-24-agent-reply-design.md`

---

## File Structure

| File | Change | Responsibility |
|---|---|---|
| `cli/control/process_manager.py` | modify | `sessions_dir`, `_parse_jsonl()`, `_spawn_with_parser()`, `launch_resume()`, `has_session()` |
| `cli/control/app.py` | modify | `Binding("r")`, `action_reply_agent()`, `↩` indicator in roster, `↩` prefix in submit |
| `cli/control/ask.py` | modify | Print session file path at end of run |
| `tests/test_process_manager.py` | modify | Tests for `_parse_jsonl`, `has_session`, `launch_resume` |

---

## Task 1: ProcessManager — sessions directory + JSONL parser

Add `sessions_dir`, extract the parsing logic into a testable `_parse_jsonl()`, and wire it into `_run_claude` via `_spawn_with_parser()`.

**Files:**
- Modify: `cli/control/process_manager.py`
- Modify: `tests/test_process_manager.py`

- [ ] **Step 1: Write failing tests**

Append to `tests/test_process_manager.py`:

```python
import json
import io


def test_sessions_dir_created(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    assert (tmp_path / "sessions").is_dir()


def test_parse_jsonl_extracts_session_id(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    events = [
        json.dumps({"type": "system", "subtype": "init", "session_id": "abc-123"}),
        json.dumps({"type": "result", "result": "Hello"}),
    ]
    log = io.StringIO()
    pm._parse_jsonl("tech-writer", iter(events), log)
    assert (tmp_path / "sessions" / "tech-writer.session").read_text() == "abc-123"


def test_parse_jsonl_extracts_text(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    events = [
        json.dumps({"type": "assistant", "message": {"content": [
            {"type": "text", "text": "Hello world"}
        ]}}),
    ]
    log = io.StringIO()
    pm._parse_jsonl("tech-writer", iter(events), log)
    assert "Hello world" in log.getvalue()


def test_parse_jsonl_non_json_written_verbatim(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    log = io.StringIO()
    pm._parse_jsonl("tech-writer", iter(["not json at all\n"]), log)
    assert "not json at all" in log.getvalue()


def test_parse_jsonl_append_writes_separator(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    log = io.StringIO()
    pm._parse_jsonl("tech-writer", iter([]), log, append=True)
    assert "── reply ──" in log.getvalue()


def test_has_session_false_when_no_file(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    assert pm.has_session("tech-writer") is False


def test_has_session_true_when_file_exists(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    (tmp_path / "sessions").mkdir(exist_ok=True)
    (tmp_path / "sessions" / "tech-writer.session").write_text("abc-123")
    assert pm.has_session("tech-writer") is True
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `pytest tests/test_process_manager.py -v 2>&1 | tail -15`
Expected: FAIL — `AttributeError: 'ProcessManager' object has no attribute 'sessions_dir'` and similar

- [ ] **Step 3: Update `cli/control/process_manager.py`**

Replace the entire file with:

```python
import json as _json
import os
import signal
import subprocess
import threading
from pathlib import Path
from typing import IO, AsyncGenerator


class ProcessManager:
    def __init__(self, octopus_dir: Path):
        self.root = octopus_dir
        self.pids_dir = octopus_dir / "pids"
        self.logs_dir = octopus_dir / "logs"
        self.worktrees_dir = octopus_dir / "worktrees"
        self.sessions_dir = octopus_dir / "sessions"
        for d in (self.pids_dir, self.logs_dir, self.worktrees_dir, self.sessions_dir):
            d.mkdir(parents=True, exist_ok=True)
        self._procs: dict[str, subprocess.Popen] = {}

    # ── JSONL parsing ──────────────────────────────────────────────────────────

    def _parse_jsonl(
        self,
        role: str,
        lines,
        log_file: IO[str],
        append: bool = False,
    ) -> None:
        """Read JSONL lines, write session_id to sessions dir, write text to log_file."""
        if append:
            log_file.write("\n── reply ──\n")
            log_file.flush()
        for raw in lines:
            try:
                obj = _json.loads(raw)
                sid = obj.get("session_id")
                if sid:
                    (self.sessions_dir / f"{role}.session").write_text(sid)
                if obj.get("type") == "assistant":
                    for block in obj.get("message", {}).get("content", []):
                        if block.get("type") == "text":
                            log_file.write(block["text"])
                            log_file.flush()
            except _json.JSONDecodeError:
                log_file.write(raw)
                log_file.flush()

    def _spawn_with_parser(
        self,
        role: str,
        cmd: list[str],
        log_path: Path,
        cwd: Path | None = None,
        append: bool = False,
    ) -> subprocess.Popen:
        """Launch cmd, parse JSONL stdout in background thread, write text to log_path."""
        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            cwd=cwd or Path.cwd(),
            text=True,
        )

        def _run():
            with open(log_path, "a" if append else "w") as f:
                self._parse_jsonl(role, proc.stdout, f, append=append)

        threading.Thread(target=_run, daemon=True).start()
        return proc

    # ── Launch ─────────────────────────────────────────────────────────────────

    def _run_claude(
        self, role: str, prompt: str, model: str, log_path: Path, cwd: Path | None = None
    ) -> subprocess.Popen:
        cmd = [
            "claude", "--model", model,
            "--print", "--output-format", "stream-json", "--verbose",
            prompt,
        ]
        return self._spawn_with_parser(role, cmd, log_path, cwd=cwd)

    def launch(
        self,
        role: str,
        prompt: str,
        model: str,
        cwd: Path | None = None,
        isolate: bool = False,
    ) -> int:
        log_path = self.logs_dir / f"{role}.log"
        effective_cwd = self.create_worktree(role) if isolate else (cwd or Path.cwd())
        proc = self._run_claude(role, prompt, model, log_path, cwd=effective_cwd)
        self._procs[role] = proc
        (self.pids_dir / f"{role}.pid").write_text(str(proc.pid))
        return proc.pid

    def launch_resume(self, role: str, session_id: str, reply: str, model: str) -> int:
        """Resume a previous Claude session with a new reply. Appends to existing log."""
        log_path = self.logs_dir / f"{role}.log"
        cmd = [
            "claude", "--model", model,
            "--print", "--output-format", "stream-json", "--verbose",
            "--resume", session_id,
            reply,
        ]
        proc = self._spawn_with_parser(role, cmd, log_path, append=True)
        self._procs[role] = proc
        (self.pids_dir / f"{role}.pid").write_text(str(proc.pid))
        return proc.pid

    # ── Session helpers ────────────────────────────────────────────────────────

    def has_session(self, role: str) -> bool:
        """Return True if a resumable session file exists for this role."""
        f = self.sessions_dir / f"{role}.session"
        return f.exists() and bool(f.read_text().strip())

    def session_id(self, role: str) -> str | None:
        """Return the last captured session ID for this role, or None."""
        f = self.sessions_dir / f"{role}.session"
        if not f.exists():
            return None
        sid = f.read_text().strip()
        return sid or None

    # ── Exit code + kill ───────────────────────────────────────────────────────

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

    # ── Orphan adoption ────────────────────────────────────────────────────────

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

    # ── Worktree ───────────────────────────────────────────────────────────────

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

- [ ] **Step 4: Run all process manager tests**

Run: `pytest tests/test_process_manager.py -v 2>&1 | tail -20`
Expected: all tests PASS (existing 7 + new 7 = 14 total)

- [ ] **Step 5: Run full suite to confirm no regression**

Run: `pytest tests/ -q --tb=short 2>&1 | tail -5`
Expected: all PASS

- [ ] **Step 6: Commit**

```bash
git add cli/control/process_manager.py tests/test_process_manager.py
git commit -m "feat(control): session capture — JSONL parser thread + launch_resume + has_session

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 2: TUI — `[r]eply` keybinding + roster indicator + submit routing

Three changes to `app.py`: new binding, `↩` in roster, `↩ role:` prefix detection.

**Files:**
- Modify: `cli/control/app.py`

- [ ] **Step 1: Add `Binding("r", "reply_agent", "Reply")` to BINDINGS**

In `app.py`, find the `BINDINGS` list and add the `r` binding after `k`:

```python
    BINDINGS = [
        Binding("a", "add_task", "Add task"),
        Binding("k", "kill_agent", "Kill"),
        Binding("r", "reply_agent", "Reply"),
        Binding("ctrl+d", "cleanup_queue", "Clean queue"),
        Binding("tab", "focus_next", "Focus", show=False),
        Binding("q", "request_quit", "Quit"),
    ]
```

- [ ] **Step 2: Add `action_reply_agent()` method**

Add this method after `action_add_task` in `app.py`:

```python
    def action_reply_agent(self) -> None:
        role = self._selected_role()
        if role == "agent" or not self.pm.has_session(role):
            self.notify(f"No resumable session for {role}", severity="warning", timeout=3)
            return
        cmd = self.query_one("#cmd", Input)
        cmd.value = f"↩ {role}: "
        cmd.cursor_position = len(cmd.value)
        cmd.remove_class("hidden")
        cmd.focus()
```

- [ ] **Step 3: Update `_refresh_roster()` to show `↩` when session exists**

Replace the current `_refresh_roster()` method:

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
            resumable = " [dim]↩[/dim]" if self.pm.has_session(role) else ""
            if last_line:
                truncated = last_line[:36] + "…" if len(last_line) > 36 else last_line
                status = f"{frame} {elapsed_str}{resumable}  [dim]{truncated}[/dim]"
            else:
                status = f"{frame} {elapsed_str}{resumable}"
            table.add_row(role, status, key=role)
```

- [ ] **Step 4: Add `↩ role:` prefix detection to `on_input_submitted()`**

In `on_input_submitted`, add the reply pre-parse BEFORE the existing `@role:` handling (i.e., before `result = self._matcher.resolve(...)`):

```python
    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        cmd_widget = self.query_one("#cmd", Input)
        cmd_widget.value = ""
        cmd_widget.add_class("hidden")
        if not text:
            return

        # Pre-parse ↩ role: prefix (resume/reply flow)
        import re as _re
        reply_match = _re.match(r'^↩\s*([\w-]+):\s*(.*)', text, _re.DOTALL)
        if reply_match:
            role = reply_match.group(1)
            reply_text = reply_match.group(2).strip()
            session_id = self.pm.session_id(role)
            if not session_id:
                self.notify(f"No session found for {role}", severity="warning", timeout=3)
                return
            if not reply_text:
                self.notify("Reply text cannot be empty", severity="warning", timeout=3)
                return
            pid = self.pm.launch_resume(
                role=role,
                session_id=session_id,
                reply=reply_text,
                model="claude-sonnet-4-6",
            )
            self._agents[role] = pid
            self._agent_started[role] = time.time()
            self.run_worker(self._stream_log(role))
            self._refresh_roster()
            return

        result = self._matcher.resolve(text, role_model="claude-sonnet-4-6")
        # ... rest of existing code unchanged ...
```

- [ ] **Step 5: Verify import works**

Run: `python3 -c "from cli.control.app import OctopusControl; print('ok')"`
Expected: `ok`

- [ ] **Step 6: Run full test suite**

Run: `pytest tests/ -q --tb=short 2>&1 | tail -5`
Expected: all PASS

- [ ] **Step 7: Commit**

```bash
git add cli/control/app.py
git commit -m "feat(control): [r]eply keybinding — resume agent session from TUI

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 3: `ask.py` — print session file path at end of run

Add the session file path to `ask()`'s summary output so users can use it for manual `--resume`.

**Files:**
- Modify: `cli/control/ask.py`

- [ ] **Step 1: Update `ask()` summary output**

In `cli/control/ask.py`, find the final summary block (after the `─` separator line that prints `✓ done` or `✗ failed`) and add the session file path line:

Find this block:
```python
    print("─" * 50)
    if code == 0:
        print(f"✓ done  {elapsed}s")
    else:
        print(f"✗ failed  {elapsed}s  ·  exit code {code}")
        escaped = task.replace('"', '\\"')
        print(f'  → octopus ask {role} "{escaped}" --retry')
    print(f"  log: {log_path}")
    return code
```

Replace with:
```python
    print("─" * 50)
    if code == 0:
        print(f"✓ done  {elapsed}s")
    else:
        print(f"✗ failed  {elapsed}s  ·  exit code {code}")
        escaped = task.replace('"', '\\"')
        print(f'  → octopus ask {role} "{escaped}" --retry')
    print(f"  log: {log_path}")
    session_file = octopus_dir / "sessions" / f"{role}.session"
    if session_file.exists() and session_file.read_text().strip():
        print(f"  session: {session_file}  (reply via TUI [r])")
    return code
```

- [ ] **Step 2: Run ask tests to confirm no regression**

Run: `pytest tests/test_ask.py -v 2>&1 | tail -10`
Expected: all 5 PASS (dry-run tests don't reach the summary block)

- [ ] **Step 3: Commit**

```bash
git add cli/control/ask.py
git commit -m "feat(control): print session file path after octopus ask completes

Co-authored-by: claude <claude@anthropic.com>"
```

---

## Task 4: Roadmap + full verification

Add RM-055 to the roadmap, run the full suite, smoke-test the session capture.

**Files:**
- Modify: `docs/roadmap.md`

- [ ] **Step 1: Run full Python + bash test suite**

Run: `pytest tests/ -q --tb=short 2>&1 | tail -8`
Expected: all PASS

Run: `bash tests/test_control.sh 2>&1 | grep -E "PASS|FAIL"`
Expected: all PASS

- [ ] **Step 2: Smoke-test session capture**

```bash
# Verify stream-json output format works
claude --print --output-format=stream-json --verbose "say hello in one word" 2>&1 \
  | python3 -c "
import sys, json
for line in sys.stdin:
    line = line.strip()
    if not line: continue
    try:
        obj = json.loads(line)
        if obj.get('session_id'):
            print('session_id captured:', obj['session_id'][:8], '...')
            break
    except: pass
"
```

Expected output: `session_id captured: <uuid prefix> ...`

- [ ] **Step 3: Verify ProcessManager session path logic**

```bash
python3 -c "
import sys; sys.path.insert(0, '.')
from pathlib import Path
from cli.control.process_manager import ProcessManager
import tempfile, os, json, io

with tempfile.TemporaryDirectory() as d:
    pm = ProcessManager(Path(d))
    events = [
        json.dumps({'type': 'system', 'session_id': 'test-session-id-123'}),
        json.dumps({'type': 'assistant', 'message': {'content': [{'type': 'text', 'text': 'Hello!'}]}}),
    ]
    log = io.StringIO()
    pm._parse_jsonl('tech-writer', iter(events), log)
    sid = (Path(d) / 'sessions' / 'tech-writer.session').read_text()
    print('session_id:', sid)
    print('log text:', log.getvalue().strip())
    print('has_session:', pm.has_session('tech-writer'))
"
```

Expected:
```
session_id: test-session-id-123
log text: Hello!
has_session: True
```

- [ ] **Step 4: Add RM-055 to roadmap**

In `docs/roadmap.md`, add after the Cluster 8 block:

```markdown
### Cluster 9 — Agent Reply (bidirectional interaction)

| Item | Description |
|---|---|
| **RM-055** | Agent reply via `--resume` — `ProcessManager` captures `session_id` from `--output-format=stream-json`, stores in `.octopus/sessions/`; TUI `[r]eply` keybinding opens command bar pre-filled with `↩ role:`; `launch_resume()` continues session; `octopus ask` prints session path at end |
```

- [ ] **Step 5: Commit roadmap**

```bash
git add docs/roadmap.md
git commit -m "chore(roadmap): add RM-055 agent reply via session resume

Co-authored-by: claude <claude@anthropic.com>"
```
