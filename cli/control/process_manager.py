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

    def launch(self, role: str, prompt: str, model: str, cwd: Path | None = None, isolate: bool = False) -> int:
        log_path = self.logs_dir / f"{role}.log"
        effective_cwd = self.create_worktree(role) if isolate else (cwd or Path.cwd())
        proc = self._run_claude(role, prompt, model, log_path, cwd=effective_cwd)
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
