from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, Vertical
from textual.widgets import DataTable, Footer, Header, Input, Label, ListItem, ListView

from .process_manager import ProcessManager
from .queue import TaskQueue
from .skill_matcher import SkillMatcher


class OctopusControl(App):
    TITLE = "Octopus Control"
    CSS_PATH = Path(__file__).parent / "app.tcss"
    BINDINGS = [
        Binding("a", "add_task", "Add task"),
        Binding("p", "pause", "Pause"),
        Binding("k", "kill_agent", "Kill"),
        Binding("tab", "focus_next", "Focus", show=False),
        Binding("q", "request_quit", "Quit"),
    ]

    def __init__(self, octopus_dir: Path):
        super().__init__()
        self.octopus_dir = octopus_dir
        self.pm = ProcessManager(octopus_dir)
        self.queue = TaskQueue(octopus_dir / "queue")
        self._matcher = SkillMatcher(skills_dir=octopus_dir / "skills")
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
        yield Input(placeholder="[a] add task…", id="cmd", classes="hidden")
        yield Footer()

    def on_mount(self) -> None:
        agents_table = self.query_one("#agents", DataTable)
        agents_table.add_columns("Role", "Status", "Task")
        schedule_table = self.query_one("#schedule", DataTable)
        schedule_table.add_columns("ID", "When", "Role", "Skill")
        self._agents = self.pm.adopt_orphans()
        self._refresh_roster()
        self.set_interval(1, self._refresh_roster)

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.clear()
        for role, _pid in self._agents.items():
            table.add_row(role, "● running", "–", key=role)

    def _refresh_queue(self) -> None:
        lv = self.query_one("#queue", ListView)
        lv.clear()
        for task in self.queue.list_all():
            lv.append(ListItem(Label(f"{task['role']} — {task['status']}")))

    def _selected_role(self) -> str:
        table = self.query_one("#agents", DataTable)
        if table.cursor_row is not None and table.row_count > 0:
            return str(table.get_cell_at((table.cursor_row, 0)))
        return "default"

    def action_add_task(self) -> None:
        cmd = self.query_one("#cmd", Input)
        cmd.remove_class("hidden")
        cmd.focus()

    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        self.query_one("#cmd", Input).add_class("hidden")
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

    def watch_agent_output(self, role: str) -> None:
        async def _tail():
            async for line in self.pm.tail_log(role):
                self.query_one("#output", Label).update(line)
        self.run_worker(_tail())


def main() -> None:
    octopus_dir = Path(".octopus")
    octopus_dir.mkdir(exist_ok=True)
    OctopusControl(octopus_dir).run()


if __name__ == "__main__":
    main()
