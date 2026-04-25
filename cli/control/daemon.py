"""Headless queue dispatch loop — runs without the Textual TUI."""
from __future__ import annotations

import os
import signal
import sys
import time
from pathlib import Path

from .process_manager import ProcessManager
from .queue import TaskQueue
from .scheduler import Scheduler
from .skill_matcher import SkillMatcher

_POLL_INTERVAL = 2  # seconds
_SKILLS_DIR = Path(".claude") / "skills"
_PID_FILE = Path(".octopus") / "daemon.pid"


def _build_prompt(task: dict) -> str:
    skill = task.get("skill")
    prompt = task.get("prompt", "")
    if not skill:
        return prompt
    cmd = skill if ":" in skill else f"octopus:{skill}"
    return f"/{cmd} {prompt}".strip()


def run(octopus_dir: Path) -> None:
    pm = ProcessManager(octopus_dir)
    queue = TaskQueue(octopus_dir / "queue")
    agents: dict[str, int] = pm.adopt_orphans()
    scheduler = Scheduler(
        octopus_dir / "schedule.yml",
        on_fire=lambda entry: queue.enqueue(
            role=entry["role"],
            skill=entry.get("skill"),
            model=entry.get("model", "claude-sonnet-4-6"),
            prompt=entry.get("skill") or "",
        ),
    )
    scheduler.start()

    _PID_FILE.write_text(str(os.getpid()))

    def _shutdown(sig, frame):
        print(f"\n[daemon] shutting down (signal {sig})")
        scheduler.stop()
        _PID_FILE.unlink(missing_ok=True)
        sys.exit(0)

    signal.signal(signal.SIGTERM, _shutdown)
    signal.signal(signal.SIGINT, _shutdown)

    print(f"[daemon] started  pid={os.getpid()}  queue={octopus_dir / 'queue'}")

    while True:
        # Reap dead agents
        for role, pid in list(agents.items()):
            code = pm.exit_code(role)
            if code is None:
                try:
                    os.kill(pid, 0)
                    continue
                except ProcessLookupError:
                    pass
            agents.pop(role)
            final_status = "done" if (code is None or code == 0) else "failed"
            (pm.pids_dir / f"{role}.pid").unlink(missing_ok=True)
            pm.remove_worktree(role)
            for task in queue.list_all():
                if task["role"] == role and task["status"] == "running":
                    queue.update_status(task["id"], final_status)
            print(f"[daemon] {role} {final_status}")

        # Dispatch next queued task
        for task in queue.list_all():
            if task["status"] != "queued":
                continue
            role = task["role"]
            if role in agents:
                continue
            prompt = _build_prompt(task)
            queue.update_status(task["id"], "running")
            pid = pm.launch(role=role, prompt=prompt, model=task["model"], task_id=task["id"])
            agents[role] = pid
            print(f"[daemon] dispatched {role}  task={task['id'][:12]}")
            break

        time.sleep(_POLL_INTERVAL)


def stop() -> None:
    if not _PID_FILE.exists():
        print("daemon is not running")
        return
    pid = int(_PID_FILE.read_text().strip())
    try:
        os.kill(pid, signal.SIGTERM)
        print(f"[daemon] sent SIGTERM to pid {pid}")
    except ProcessLookupError:
        print(f"[daemon] pid {pid} not found — removing stale pid file")
        _PID_FILE.unlink(missing_ok=True)


def status() -> None:
    if not _PID_FILE.exists():
        print("daemon: not running")
        return
    pid = int(_PID_FILE.read_text().strip())
    try:
        os.kill(pid, 0)
        print(f"daemon: running  pid={pid}")
    except ProcessLookupError:
        print(f"daemon: stale pid file (pid={pid} not found)")
        _PID_FILE.unlink(missing_ok=True)


def main() -> None:
    import argparse
    p = argparse.ArgumentParser(prog="octopus-daemon")
    p.add_argument("command", choices=["start", "stop", "status"],
                   help="start | stop | status")
    args = p.parse_args()

    octopus_dir = Path(".octopus")
    octopus_dir.mkdir(exist_ok=True)

    if args.command == "start":
        run(octopus_dir)
    elif args.command == "stop":
        stop()
    elif args.command == "status":
        status()


if __name__ == "__main__":
    main()
