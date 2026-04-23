import subprocess
import sys
import os
sys.path.insert(0, ".")
from cli.control.process_manager import ProcessManager


def test_adopt_orphans(tmp_path):
    pm = ProcessManager(octopus_dir=tmp_path)
    proc = subprocess.Popen(["sleep", "60"])
    pid_file = tmp_path / "pids" / "backend-specialist.pid"
    pid_file.parent.mkdir(parents=True, exist_ok=True)
    pid_file.write_text(str(proc.pid))
    adopted = pm.adopt_orphans()
    assert "backend-specialist" in adopted
    proc.terminate()


def test_launch_creates_pid(tmp_path, monkeypatch):
    pm = ProcessManager(octopus_dir=tmp_path)
    monkeypatch.setattr(pm, "_run_claude", lambda *a, **kw: 99999)
    pm.launch("tech-writer", prompt="hello", model="claude-sonnet-4-6")
    assert (tmp_path / "pids" / "tech-writer.pid").exists()
