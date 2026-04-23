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

    def _run_claude(self, role: str, prompt: str, model: str, log_path: Path) -> int:
        # --print runs a single non-interactive turn; cwd stays in project root
        cmd = ["claude", "--model", model, "--print", prompt]
        with open(log_path, "w") as f:
            p = subprocess.Popen(
                cmd,
                stdout=f,
                stderr=subprocess.STDOUT,
                cwd=Path.cwd(),
            )
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
