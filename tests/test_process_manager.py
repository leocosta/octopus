import subprocess
import subprocess as sp
import sys
import os
import time
sys.path.insert(0, ".")
from cli.control.process_manager import ProcessManager


def test_adopt_orphans(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    proc = subprocess.Popen(["sleep", "60"])
    pid_file = tmp_path / "pids" / "backend-developer.pid"
    pid_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.write_text(str(proc.pid))
    adopted = pm.adopt_orphans()
    assert "backend-developer" in adopted
    proc.terminate()


def test_launch_creates_pid(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    class FakeProc:
        pid = 99999
        def poll(self): return None
    monkeypatch.setattr(pm, "_run_claude", lambda *a, **kw: FakeProc())
    pm.launch("writer", prompt="hello", model="claude-sonnet-4-6")
    assert (tmp_path / "pids" / "writer.pid").exists()


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


def test_create_worktree_calls_git(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    calls = []
    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        class R:
            returncode = 0
        return R()
    monkeypatch.setattr(sp, "run", fake_run)
    pm.create_worktree("backend-developer")
    assert any("worktree" in " ".join(c) for c in calls)


def test_remove_worktree_calls_git(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    (tmp_path / "worktrees" / "backend-developer").mkdir(parents=True)
    calls = []
    def fake_run(cmd, **kwargs):
        calls.append(cmd)
        class R:
            returncode = 0
        return R()
    monkeypatch.setattr(sp, "run", fake_run)
    pm.remove_worktree("backend-developer")
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
    pm.launch("backend-developer", "hello", "claude-sonnet-4-6", isolate=True)
    assert used_cwd[0] == tmp_path / "worktrees" / "backend-developer"


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
    pm._parse_jsonl("writer", iter(events), log)
    assert (tmp_path / "sessions" / "writer.session").read_text() == "abc-123"


def test_parse_jsonl_extracts_text(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    events = [
        json.dumps({"type": "assistant", "message": {"content": [
            {"type": "text", "text": "Hello world"}
        ]}}),
    ]
    log = io.StringIO()
    pm._parse_jsonl("writer", iter(events), log)
    assert "Hello world" in log.getvalue()


def test_parse_jsonl_non_json_written_verbatim(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    log = io.StringIO()
    pm._parse_jsonl("writer", iter(["not json at all\n"]), log)
    assert "not json at all" in log.getvalue()


def test_parse_jsonl_append_writes_separator(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    log = io.StringIO()
    pm._parse_jsonl("writer", iter([]), log, append=True)
    assert "── reply ──" in log.getvalue()


def test_has_session_false_when_no_file(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    assert pm.has_session("writer") is False


def test_has_session_true_when_file_exists(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    (tmp_path / "sessions").mkdir(exist_ok=True)
    (tmp_path / "sessions" / "writer.session").write_text("abc-123")
    assert pm.has_session("writer") is True
