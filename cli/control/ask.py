from __future__ import annotations

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
