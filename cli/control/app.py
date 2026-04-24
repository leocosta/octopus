import asyncio
import os
import re as _re
import signal
import time
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

# Skills and agents live in .claude/ relative to the project root
_SKILLS_DIR = Path(".claude") / "skills"
_AGENTS_DIR = Path(".claude") / "agents"
# Agents excluded from the roster (internal/automation agents)
_EXCLUDED_AGENTS = {"dream"}

_SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
_STATUS_LABEL = {"queued": "○", "running": "●", "done": "✓", "failed": "✗"}


class OctopusControl(App):
    TITLE = "🐙 Octopus Control"
    CSS_PATH = Path(__file__).parent / "app.tcss"
    BINDINGS = [
        Binding("a", "add_task", "Add task"),
        Binding("k", "kill_agent", "Kill"),
        Binding("r", "reply_agent", "Reply"),
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
        self._agent_started: dict[str, float] = {}
        self._known_roles: list[str] = self._load_known_roles()
        self._awaiting_exit: bool = False
        self._scheduler: Scheduler | None = None
        self._cleanup_tick: int = 0
        self._spin_tick: int = 0

    @staticmethod
    def _load_known_roles() -> list[str]:
        """Return sorted list of agent role names from .claude/agents/, excluding internal agents."""
        if not _AGENTS_DIR.exists():
            return []
        return sorted(
            f.stem for f in _AGENTS_DIR.glob("*.md")
            if f.stem not in _EXCLUDED_AGENTS
        )

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="main"):
            with Vertical(id="left"):
                yield DataTable(id="agents")
            with Vertical(id="right"):
                yield ListView(id="queue")
                yield DataTable(id="schedule")
        yield RichLog(id="output", markup=True, highlight=False, wrap=True)
        yield Input(placeholder="  /skill [args]  ·  natural language  ·  Tab to complete", id="cmd", classes="hidden")
        yield Footer()

    def on_mount(self) -> None:
        agents_table = self.query_one("#agents", DataTable)
        agents_table.add_columns("Role", "Status")
        schedule_table = self.query_one("#schedule", DataTable)
        schedule_table.add_columns("When", "Role", "Skill")

        # Panel titles
        self.query_one("#agents", DataTable).border_title = "Agents"
        self.query_one("#queue", ListView).border_title = "Queue"
        self.query_one("#schedule", DataTable).border_title = "Schedule"
        self.query_one("#output", RichLog).border_title = "Output"
        self.query_one("#cmd", Input).border_title = "Command"

        self._agents = self.pm.adopt_orphans()
        # Reconcile: mark tasks stuck in "running" as "failed" if their process is gone
        for task in self.queue.list_all():
            if task["status"] == "running" and task["role"] not in self._agents:
                self.queue.update_status(task["id"], "failed")
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
        self.set_interval(0.3, self._spin_poll)

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

    def _spin_poll(self) -> None:
        """Fast timer (0.3s) — advances spinner and redraws queue + roster if agents are active."""
        if not self._agents and not any(
            t["status"] == "running" for t in self.queue.list_all()
        ):
            return
        self._spin_tick += 1
        self._refresh_queue()
        self._refresh_roster()

    def _reap_dead_agents(self) -> None:
        dead = []
        for role, pid in list(self._agents.items()):
            # poll() reaps zombies; fall back to kill(0) for adopted orphans
            code = self.pm.exit_code(role)
            if code is not None:
                dead.append(role)
                continue
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
            self._agent_started[role] = time.time()
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
        log_widget.border_title = f"Output · {role} · live"
        with open(log_path) as f:
            while True:
                line = f.readline()
                if line:
                    log_widget.write(line.rstrip())
                else:
                    if role not in self._agents:
                        log_widget.border_title = f"Output · {role} · done"
                        break
                    await asyncio.sleep(0.2)

    # ── UI refresh ────────────────────────────────────────────────────────────

    def _last_log_line(self, role: str) -> str:
        log_path = self.pm.logs_dir / f"{role}.log"
        if not log_path.exists():
            return ""
        try:
            stat = log_path.stat()
            if stat.st_size == 0:
                return ""
            with open(log_path, "rb") as f:
                f.seek(max(0, stat.st_size - 300))
                tail = f.read().decode("utf-8", errors="replace")
            lines = [ln.strip() for ln in tail.splitlines() if ln.strip()]
            return lines[-1] if lines else ""
        except OSError:
            return ""

    def _refresh_roster(self) -> None:
        table = self.query_one("#agents", DataTable)
        saved_row = table.cursor_row
        table.clear()
        frame = _SPINNER[self._spin_tick % len(_SPINNER)]
        tasks = self.queue.list_all()
        all_roles = list(dict.fromkeys(list(self._known_roles) + list(self._agents)))
        for role in all_roles:
            pending = sum(1 for t in tasks if t["role"] == role and t["status"] == "queued")
            badge = f"  [dim]+{pending} queued[/dim]" if pending else ""
            if role in self._agents:
                elapsed = int(time.time() - self._agent_started.get(role, time.time()))
                mins, secs = divmod(elapsed, 60)
                elapsed_str = f"{mins}m{secs:02d}s" if mins else f"{secs}s"
                last_line = self._last_log_line(role)
                if last_line:
                    truncated = last_line[:36] + "…" if len(last_line) > 36 else last_line
                    status = f"{frame} {elapsed_str}  [dim]{truncated}[/dim]{badge}"
                else:
                    status = f"{frame} {elapsed_str}{badge}"
            elif self.pm.has_session(role):
                status = f"[#ffd166]↩ awaiting reply[/#ffd166]{badge}"
            else:
                status = f"[dim]○ idle{badge}[/dim]"
            table.add_row(role, status, key=role)
        if saved_row is not None and saved_row < table.row_count:
            table.move_cursor(row=saved_row)

    def _refresh_queue(self) -> None:
        lv = self.query_one("#queue", ListView)
        lv.clear()
        tasks = self.queue.list_all()
        running = sum(1 for t in tasks if t["status"] == "running")
        queued = sum(1 for t in tasks if t["status"] == "queued")
        title = "Queue"
        if running or queued:
            title = f"Queue  {running} running · {queued} waiting"
        lv.border_title = title
        frame = _SPINNER[self._spin_tick % len(_SPINNER)]
        for task in tasks:
            status = task["status"]
            role = task["role"]
            skill = task.get("skill") or "–"
            if status == "running":
                icon = frame
            else:
                icon = _STATUS_LABEL.get(status, "?")
            skill_short = skill[:22] + "…" if len(skill) > 22 else skill
            lv.append(ListItem(Label(f"{icon} {role}  [dim]{skill_short}[/dim]")))

    def _selected_role(self) -> str:
        table = self.query_one("#agents", DataTable)
        if table.cursor_row is not None and table.row_count > 0:
            return str(table.get_cell_at((table.cursor_row, 0)))
        return "agent"

    def on_data_table_row_highlighted(self, event: DataTable.RowHighlighted) -> None:
        if event.data_table.id != "agents":
            return
        if event.row_key is None:
            return
        role = str(event.row_key.value)
        log_widget = self.query_one("#output", RichLog)
        log_path = self.pm.logs_dir / f"{role}.log"
        log_widget.clear()
        if role in self._agents:
            log_widget.border_title = f"Output · {role} · live"
        else:
            log_widget.border_title = f"Output · {role}"
        if log_path.exists():
            lines = log_path.read_text().splitlines()
            for line in lines[-50:]:
                log_widget.write(line)

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
        status_icon = "✓" if task["status"] == "done" else "✗"
        log_widget.border_title = f"Output · {role} · {status_icon} {task['status']}"
        if log_path.exists():
            for line in log_path.read_text().splitlines():
                log_widget.write(line)
        else:
            log_widget.write("[dim]No log file found[/dim]")

    # ── Command bar ───────────────────────────────────────────────────────────

    def action_add_task(self) -> None:
        cmd = self.query_one("#cmd", Input)
        selected_role = self._selected_role()
        cmd.remove_class("hidden")
        cmd.focus()
        if selected_role != "agent":
            prefill = f"@{selected_role}: "
            self.call_after_refresh(setattr, cmd, "value", prefill)
            self.call_after_refresh(setattr, cmd, "cursor_position", len(prefill))

    def action_reply_agent(self) -> None:
        role = self._selected_role()
        if role == "agent" or not self.pm.has_session(role):
            self.notify(f"No resumable session for {role}", severity="warning", timeout=3)
            return
        cmd = self.query_one("#cmd", Input)
        cmd.remove_class("hidden")
        cmd.focus()
        prefill = f"↩ {role}: "
        self.call_after_refresh(setattr, cmd, "value", prefill)
        self.call_after_refresh(setattr, cmd, "cursor_position", len(prefill))

    def on_input_submitted(self, event: Input.Submitted) -> None:
        text = event.value.strip()
        cmd_widget = self.query_one("#cmd", Input)
        cmd_widget.value = ""
        cmd_widget.add_class("hidden")
        if not text:
            return

        # Pre-parse ↩ role: prefix (resume/reply flow)
        reply_match = _re.match(r'^↩\s*([\w-]+):\s*(.*)', text, _re.DOTALL)
        if reply_match:
            role = reply_match.group(1)
            reply_text = reply_match.group(2).strip()
            session_id = self.pm.session_id(role)
            if not session_id:
                self.notify(f"No session found for {role}", severity="warning", timeout=3)
                return
            if not reply_text:
                self.notify("Reply text cannot be empty", severity="warning", timeout=3)
                return
            pid = self.pm.launch_resume(
                role=role,
                session_id=session_id,
                reply=reply_text,
                model="claude-sonnet-4-6",
            )
            self._agents[role] = pid
            self._agent_started[role] = time.time()
            self.run_worker(self._stream_log(role))
            self._refresh_roster()
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
            role=result.role_override or self._selected_role(),
            skill=result.skill,
            model=result.model,
            prompt=result.raw_prompt,
        )
        self._refresh_queue()

    def action_cleanup_queue(self) -> None:
        # Also clean "running" tasks whose process is no longer active
        for task in self.queue.list_all():
            if task["status"] == "running" and task["role"] not in self._agents:
                self.queue.update_status(task["id"], "failed")
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
