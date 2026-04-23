import asyncio
import os
import signal
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.suggester import SuggestFromList
from textual.widgets import DataTable, Footer, Header, Input, Label, ListItem, ListView, RichLog

from .process_manager import ProcessManager
from .queue import TaskQueue
from .scheduler import Scheduler
from .skill_matcher import SkillMatcher

# Skills live in .claude/skills/ relative to the project root, not .octopus/
_SKILLS_DIR = Path(".claude") / "skills"

_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
_STATUS_LABEL = {"queued": "○", "running": "●", "done": "✓", "failed": "✗"}


class OctopusControl(App):
    TITLE = "Octopus Control"
    CSS_PATH = Path(__file__).parent / "app.tcss"
    BINDINGS = [
        Binding("a", "add_task", "Add task"),
        Binding("k", "kill_agent", "Kill"),
        Binding("ctrl+d", "cleanup_queue", "Clean queue"),
        Binding("tab", "focus_next", "Focus", show=False),
        Binding("q", "request_quit", "Quit"),
    ]

    def __init__(self, octopus_dir: Path):
        super().__init__()
        self.octopus_dir = octopus_dir
        self.pm = ProcessManager(octopus_dir)
        self.queue = TaskQueue(octopus_dir / "queue")
        self._matcher = SkillMatcher(skills_dir=_SKILLS_DIR)
        self._agents: dict[str, int] = {}
        self._awaiting_exit: bool = False
        self._scheduler: Scheduler | None = None
        self._cleanup_tick: int = 0
        self._tick: int = 0

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="left"):
                yield DataTable(id="agents")
            with Vertical(id="right"):
                yield ListView(id="queue")
                yield DataTable(id="schedule")
        yield RichLog(id="output", markup=True, highlight=False, wrap=True)
        yield Input(placeholder="[a] /skill args  or  natural language", id="cmd", classes="hidden")
        yield Footer()

    def on_mount(self) -> None:
        agents_table = self.query_one("#agents", DataTable)
        agents_table.add_columns("Role", "PID", "Status")
        schedule_table = self.query_one("#schedule", DataTable)
        schedule_table.add_columns("ID", "When", "Role", "Skill")
        self._agents = self.pm.adopt_orphans()
        self._refresh_roster()
        self._refresh_queue()
        skill_names = [f"/{s}" for s in self._matcher._catalog]
        self.query_one("#cmd", Input).suggester = SuggestFromList(skill_names, case_sensitive=False)
        schedule_path = self.octopus_dir / "schedule.yml"
        self._scheduler = Scheduler(schedule_path, on_fire=self._on_schedule_fire)
        self._scheduler.start()
        self._refresh_schedule()
        # Poll: refresh agent states + dispatch queued tasks
        self.set_interval(2, self._poll)

    # ── Polling ──────────────────────────────────────────────────────────────

    def _poll(self) -> None:
        self._reap_dead_agents()
        self._dispatch_next()
        self._refresh_roster()
        self._refresh_queue()
        self._cleanup_tick += 1
        if self._cleanup_tick % 30 == 0:
            self.queue.cleanup(keep_last=50)
            self._refresh_queue()

    def _reap_dead_agents(self) -> None:
        dead = []
        for role, pid in list(self._agents.items()):
            try:
                os.kill(pid, 0)
            except ProcessLookupError:
                dead.append(role)
        for role in dead:
            self._agents.pop(role, None)
            code = self.pm.exit_code(role)
            final_status = "done" if (code is None or code == 0) else "failed"
            (self.pm.pids_dir / f"{role}.pid").unlink(missing_ok=True)
            self.pm.remove_worktree(role)
            for task in self.queue.list_all():
                if task["role"] == role and task["status"] == "running":
                    self.queue.update_status(task["id"], final_status)

    def _dispatch_next(self) -> None:
        for task in self.queue.list_all():
            if task["status"] != "queued":
                continue
            role = task["role"]
            if role in self._agents:
                continue  # role already busy
            prompt = self._build_prompt(task)
            self.queue.update_status(task["id"], "running")
            pid = self.pm.launch(role=role, prompt=prompt, model=task["model"])
            self._agents[role] = pid
            self.run_worker(self._stream_log(role))
            break  # one dispatch per tick

    def _build_prompt(self, task: dict) -> str:
        skill = task.get("skill")
        prompt = task.get("prompt", "")
        if not skill:
            return prompt
        # Ensure the octopus: namespace prefix used by Claude Code slash commands
        cmd = skill if ":" in skill else f"octopus:{skill}"
        return f"/{cmd} {prompt}".strip()

    # ── Scheduler ────────────────────────────────────────────────────────────

    def _on_schedule_fire(self, entry: dict) -> None:
        self.queue.enqueue(
            role=entry.get("role", "agent"),
            skill=entry.get("skill"),
            model=entry.get("model", "claude-sonnet-4-6"),
            prompt=entry.get("prompt", ""),
        )
        self.call_from_thread(self._refresh_queue)

    def _refresh_schedule(self) -> None:
        table = self.query_one("#schedule", DataTable)
        table.clear()
        schedule_path = self.octopus_dir / "schedule.yml"
        if not schedule_path.exists():
            return
        try:
            import yaml
            entries = yaml.safe_load(schedule_path.read_text()) or []
        except Exception:
            return
        for entry in entries:
            table.add_row(
                entry.get("id", "–"),
                entry.get("when", "–"),
                entry.get("role", "–"),
                entry.get("skill", "–"),
            )

    # ── Log streaming ─────────────────────────────────────────────────────────

    async def _stream_log(self, role: str) -> None:
        log_widget = self.query_one("#output", RichLog)
        log_path = self.pm.logs_dir / f"{role}.log"
        for _ in range(30):
            if log_path.exists():
                break
            await asyncio.sleep(0.1)
        if not log_path.exists():
            return
        log_widget.clear()
        log_widget.write(f"─── {role} ───")
        with open(log_path) as f:
            while True:
                line = f.readline()
                if line:
                    log_widget.write(line.rstrip())
                else:
                    if role not in self._agents:
                        break
                    await asyncio.sleep(0.2)

    # ── UI refresh ────────────────────────────────────────────────────────────

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.clear()
        frame = _SPINNER[self._tick % len(_SPINNER)]
        self._tick += 1
        for role, pid in self._agents.items():
            table.add_row(role, str(pid), f"{frame} running", key=role)

    def _refresh_queue(self) -> None:
        lv = self.query_one("#queue", ListView)
        lv.clear()
        for task in self.queue.list_all():
            status = task["status"]
            role = task["role"]
            skill = task.get("skill") or "–"
            icon = _STATUS_LABEL.get(status, "?")
            lv.append(ListItem(Label(f"{icon} [{status}] {role} / {skill}")))

    def _selected_role(self) -> str:
        table = self.query_one("#agents", DataTable)
        if table.cursor_row is not None and table.row_count > 0:
            return str(table.get_cell_at((table.cursor_row, 0)))
        return "agent"

    def on_list_view_selected(self, event: ListView.Selected) -> None:
        tasks = self.queue.list_all()
        idx = event.list_view.index
        if idx is None or idx >= len(tasks):
            return
        task = tasks[idx]
        if task["status"] not in ("done", "failed"):
            return
        log_widget = self.query_one("#output", RichLog)
        log_widget.clear()
        role = task["role"]
        log_path = self.pm.logs_dir / f"{role}.log"
        status_label = "[green]done[/green]" if task["status"] == "done" else "[red]failed[/red]"
        log_widget.write(f"─── {role} ({status_label}) ───")
        if log_path.exists():
            for line in log_path.read_text().splitlines():
                log_widget.write(line)
        else:
            log_widget.write("[dim]No log file found[/dim]")

    # ── Command bar ───────────────────────────────────────────────────────────

    def action_add_task(self) -> None:
        cmd = self.query_one("#cmd", Input)
        cmd.remove_class("hidden")
        cmd.focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        cmd_widget = self.query_one("#cmd", Input)
        cmd_widget.value = ""
        cmd_widget.add_class("hidden")
        if not text:
            return
        result = self._matcher.resolve(text, role_model="claude-sonnet-4-6")
        if result.ambiguous:
            options = ", ".join(f"/{s}" for s in result.ambiguous)
            self.notify(f"Ambiguous match: {options}", severity="warning", timeout=5)
            return
        if result.needs_confirm:
            self.notify(
                f"Matched /{result.skill} — re-submit to confirm",
                severity="information",
                timeout=4,
            )
            cmd_widget.value = f"/{result.skill} {result.raw_prompt}".strip()
            cmd_widget.remove_class("hidden")
            cmd_widget.focus()
            return
        self.queue.enqueue(
            role=self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
        self._refresh_queue()

    def action_cleanup_queue(self) -> None:
        removed = self.queue.cleanup(keep_last=0)
        self.notify(f"Removed {removed} completed task(s)")
        self._refresh_queue()

    # ── Kill ──────────────────────────────────────────────────────────────────

    def action_kill_agent(self) -> None:
        role = self._selected_role()
        if role in self._agents:
            self.pm.kill(role)
            self._agents.pop(role, None)
            self._refresh_roster()

    # ── Quit ──────────────────────────────────────────────────────────────────

    async def action_request_quit(self) -> None:
        if not self._agents:
            if self._scheduler:
                self._scheduler.stop()
            self.exit()
            return
        self.notify("stop(s)  detach(d)  cancel(c)", title="Agents running")
        self._awaiting_exit = True

    def on_key(self, event) -> None:
        if not self._awaiting_exit:
            return
        if event.key == "s":
            for role in list(self._agents):
                self.pm.kill(role)
            if self._scheduler:
                self._scheduler.stop()
            self.exit()
        elif event.key == "d":
            self.exit()
        elif event.key == "c":
            self._awaiting_exit = False


def main() -> None:
    octopus_dir = Path(".octopus")
    octopus_dir.mkdir(exist_ok=True)
    OctopusControl(octopus_dir).run()


if __name__ == "__main__":
    main()
