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
            "--dangerously-skip-permissions",
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
        with open(log_path, "a") as f:
            f.write(f"\n── you ──\n{reply}\n── agent ──\n")
        cmd = [
            "claude", "--model", model,
            "--print", "--output-format", "stream-json", "--verbose",
            "--dangerously-skip-permissions",
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
