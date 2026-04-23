import asyncio
import os
import signal
from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import DataTable, Footer, Header, Input, Label, ListItem, ListView

from .process_manager import ProcessManager
from .queue import TaskQueue
from .skill_matcher import SkillMatcher

# Skills live in .claude/skills/ relative to the project root, not .octopus/
_SKILLS_DIR = Path(".claude") / "skills"


class OctopusControl(App):
    TITLE = "Octopus Control"
    CSS_PATH = Path(__file__).parent / "app.tcss"
    BINDINGS = [
        Binding("a", "add_task", "Add task"),
        Binding("k", "kill_agent", "Kill"),
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

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal():
            with Vertical(id="left"):
                yield DataTable(id="agents")
            with Vertical(id="right"):
                yield ListView(id="queue")
                yield DataTable(id="schedule")
        yield Label("", id="output")
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
        # Poll: refresh agent states + dispatch queued tasks
        self.set_interval(2, self._poll)

    # ── Polling ──────────────────────────────────────────────────────────────

    def _poll(self) -> None:
        self._reap_dead_agents()
        self._dispatch_next()
        self._refresh_roster()
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
            pid_file = self.pm.pids_dir / f"{role}.pid"
            pid_file.unlink(missing_ok=True)
            # Mark matching running tasks as done
            for task in self.queue.list_all():
                if task["role"] == role and task["status"] == "running":
                    self.queue.update_status(task["id"], "done")

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

    # ── Log streaming ─────────────────────────────────────────────────────────

    async def _stream_log(self, role: str) -> None:
        log_path = self.pm.logs_dir / f"{role}.log"
        # Wait up to 3 s for the log file to appear
        for _ in range(30):
            if log_path.exists():
                break
            await asyncio.sleep(0.1)
        if not log_path.exists():
            return
        with open(log_path) as f:
            while True:
                line = f.readline()
                if line:
                    self.query_one("#output", Label).update(line.rstrip())
                else:
                    # Stop tailing when the agent process is gone
                    if role not in self._agents:
                        break
                    await asyncio.sleep(0.2)

    # ── UI refresh ────────────────────────────────────────────────────────────

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.clear()
        for role, pid in self._agents.items():
            table.add_row(role, str(pid), "● running", key=role)

    def _refresh_queue(self) -> None:
        lv = self.query_one("#queue", ListView)
        lv.clear()
        for task in self.queue.list_all():
            status = task["status"]
            role = task["role"]
            skill = task.get("skill") or "–"
            lv.append(ListItem(Label(f"[{status}] {role} / {skill}")))

    def _selected_role(self) -> str:
        table = self.query_one("#agents", DataTable)
        if table.cursor_row is not None and table.row_count > 0:
            return str(table.get_cell_at((table.cursor_row, 0)))
        return "agent"

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
        self.queue.enqueue(
            role=self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
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
