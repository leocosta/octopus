from pathlib import Path

from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.widgets import DataTable, Footer, Header

from .process_manager import ProcessManager
from .queue import TaskQueue


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
        self._agents: dict[str, int] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        yield DataTable(id="agents")
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.add_columns("Role", "Status", "Task")
        self._agents = self.pm.adopt_orphans()
        self._refresh_roster()
        self.set_interval(1, self._refresh_roster)

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        table.clear()
        for role, _pid in self._agents.items():
            table.add_row(role, "● running", "–", key=role)


def main() -> None:
    octopus_dir = Path(".octopus")
    octopus_dir.mkdir(exist_ok=True)
    OctopusControl(octopus_dir).run()


if __name__ == "__main__":
    main()
