from __future__ import annotations

import re
import time
from dataclasses import dataclass, field
from pathlib import Path

import yaml

from .process_manager import ProcessManager
from .queue import TaskQueue

_POLL_INTERVAL = 2  # seconds between agent status checks


@dataclass
class PipelineTask:
    id: str
    agent: str
    depends_on: list[str]
    skill: str | None
    body: str
    status: str = "waiting"  # waiting | running | done | skipped | failed


def parse_pipeline_frontmatter(plan_path: Path) -> tuple[dict, list[PipelineTask]]:
    """Read plan Markdown and return (meta dict, list of PipelineTask).

    Raises ValueError if the plan has no pipeline: frontmatter block.
    """
    text = plan_path.read_text()
    if not text.startswith("---"):
        raise ValueError(f"{plan_path}: no YAML frontmatter found — pipeline: block required")

    end = text.index("---", 3)
    meta = yaml.safe_load(text[3:end].strip()) or {}

    if "tasks" not in meta:
        raise ValueError(
            f"{plan_path}: frontmatter has no 'tasks' block — pipeline: block required. "
            "Run /octopus:doc-plan with pipeline support to generate it."
        )

    # Extract task bodies from lines like: - [ ] **t1** — description
    body_pattern = re.compile(r"- \[[ x]\] \*\*(\w+)\*\*\s*[—\-]\s*(.+)")
    bodies: dict[str, str] = {
        m.group(1): m.group(2).strip()
        for m in body_pattern.finditer(text)
    }

    tasks = [
        PipelineTask(
            id=t["id"],
            agent=t.get("agent", "backend-specialist"),
            depends_on=t.get("depends_on") or [],
            skill=t.get("skill"),
            body=bodies.get(t["id"], t["id"]),
        )
        for t in meta["tasks"]
    ]
    return meta, tasks


class PipelineRunner:
    def __init__(self, plan_path: Path, octopus_dir: Path):
        self.plan_path = plan_path
        self.pm = ProcessManager(octopus_dir)
        self._meta, self._tasks = parse_pipeline_frontmatter(plan_path)

    # ── DAG helpers ────────────────────────────────────────────────────────

    def _ready_tasks(self) -> list[PipelineTask]:
        done_ids = {t.id for t in self._tasks if t.status in ("done", "skipped")}
        return [
            t for t in self._tasks
            if t.status == "waiting"
            and all(dep in done_ids for dep in t.depends_on)
        ]

    def _running_agents(self) -> set[str]:
        return {t.agent for t in self._tasks if t.status == "running"}

    # ── Plan file mutation ─────────────────────────────────────────────────

    def _update_checkbox(self, task_id: str) -> None:
        text = self.plan_path.read_text()
        updated = re.sub(
            rf"- \[ \] (\*\*{re.escape(task_id)}\*\*)",
            r"- [x] \1",
            text,
        )
        self.plan_path.write_text(updated)

    # ── Prompt construction ────────────────────────────────────────────────

    def _build_prompt(self, task: PipelineTask) -> str:
        if not task.skill:
            return task.body
        cmd = task.skill if ":" in task.skill else f"octopus:{task.skill}"
        return f"/{cmd} {task.body}".strip()

    # ── Execution loop ─────────────────────────────────────────────────────

    def run(self) -> bool:
        """Drive the pipeline to completion. Returns True if all tasks succeeded."""
        model = self._meta.get("model", "claude-sonnet-4-6")

        while True:
            busy_agents = self._running_agents()

            for task in self._ready_tasks():
                if task.agent in busy_agents:
                    continue
                prompt = self._build_prompt(task)
                self.pm.launch(role=task.agent, prompt=prompt, model=model, isolate=True)
                task.status = "running"
                busy_agents.add(task.agent)

            for task in [t for t in self._tasks if t.status == "running"]:
                code = self.pm.exit_code(task.agent)
                if code is None:
                    continue
                task.status = "done" if code == 0 else "failed"
                if task.status == "done":
                    self._update_checkbox(task.id)

            all_terminal = all(
                t.status in ("done", "skipped", "failed") for t in self._tasks
            )
            if all_terminal:
                break

            still_running = any(t.status == "running" for t in self._tasks)
            has_ready = bool(self._ready_tasks())
            if not still_running and not has_ready:
                # Deadlock: remaining tasks blocked by failed deps
                break

            time.sleep(_POLL_INTERVAL)

        pipeline_ok = all(t.status in ("done", "skipped") for t in self._tasks)
        if not pipeline_ok:
            return False

        return self.run_review_gate()

    def run_review_gate(self) -> bool:
        """Dispatch reviewer agent if review_skill is configured. Returns True if passed."""
        pipeline_cfg = self._meta.get("pipeline", {})
        review_skill = pipeline_cfg.get("review_skill")
        if not review_skill:
            return True

        model = self._meta.get("model", "claude-sonnet-4-6")
        cmd = review_skill if ":" in review_skill else f"octopus:{review_skill}"
        prompt = f"/{cmd}"
        self.pm.launch(role="reviewer", prompt=prompt, model=model, isolate=False)

        while True:
            code = self.pm.exit_code("reviewer")
            if code is not None:
                return code == 0
            time.sleep(_POLL_INTERVAL)
