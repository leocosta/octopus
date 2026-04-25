"""Pipeline builder — data model and Textual widget.

PipelineBuilderModel: pure data layer (step list, mutations, YAML serialization).
PipelineBuilder: Textual widget wrapping the model with keyboard navigation.
"""
from __future__ import annotations

import hashlib
import io
from dataclasses import dataclass, field
from pathlib import Path
from typing import TYPE_CHECKING

import yaml

from .nl_parser import PipelineStep, parse_nl_pipeline

if TYPE_CHECKING:
    pass


# ── Data model ────────────────────────────────────────────────────────────────

@dataclass
class BuilderStep:
    agent: str
    prompt: str
    tier: int = 1
    wait: bool = False
    ambiguous: bool = False

    @classmethod
    def from_nl_step(cls, nl: PipelineStep) -> "BuilderStep":
        return cls(
            agent=nl.agent,
            prompt=nl.prompt,
            tier=nl.tier,
            wait=nl.wait,
            ambiguous=nl.ambiguous,
        )

    def _stable_id(self, position: int) -> str:
        key = f"{position}:{self.agent}:{self.prompt[:40]}"
        return "t" + hashlib.sha1(key.encode()).hexdigest()[:6]


class PipelineBuilderModel:
    def __init__(self) -> None:
        self.steps: list[BuilderStep] = []

    # ── Mutations ─────────────────────────────────────────────────────────

    def add_step(self, step: BuilderStep) -> None:
        self.steps.append(step)

    def remove_step(self, index: int) -> None:
        if 0 <= index < len(self.steps):
            self.steps.pop(index)

    def move_step(self, index: int, delta: int) -> None:
        new_index = index + delta
        if 0 <= new_index < len(self.steps):
            self.steps[index], self.steps[new_index] = (
                self.steps[new_index],
                self.steps[index],
            )

    def toggle_wait(self, index: int) -> None:
        if 0 <= index < len(self.steps):
            self.steps[index].wait = not self.steps[index].wait

    # ── Factory ───────────────────────────────────────────────────────────

    @classmethod
    def from_nl_pipeline(cls, text: str) -> "PipelineBuilderModel":
        m = cls()
        for nl_step in parse_nl_pipeline(text):
            m.add_step(BuilderStep.from_nl_step(nl_step))
        return m

    # ── Serialization ─────────────────────────────────────────────────────

    def to_yaml(self) -> str:
        """Serialize the builder steps to a YAML string for PipelineRunner."""
        ids = [s._stable_id(i) for i, s in enumerate(self.steps)]

        # Group steps by tier to compute depends_on
        tier_to_ids: dict[int, list[str]] = {}
        for step_id, step in zip(ids, self.steps):
            tier_to_ids.setdefault(step.tier, []).append(step_id)

        sorted_tiers = sorted(tier_to_ids)

        tasks = []
        for step_id, step in zip(ids, self.steps):
            tier_index = sorted_tiers.index(step.tier)
            if tier_index == 0:
                depends_on: list[str] = []
            else:
                prev_tier = sorted_tiers[tier_index - 1]
                depends_on = tier_to_ids[prev_tier]

            task: dict = {
                "id": step_id,
                "agent": step.agent,
                "prompt": step.prompt,
                "depends_on": depends_on,
                "wait": step.wait,
            }
            tasks.append(task)

        return yaml.dump({"tasks": tasks}, default_flow_style=False, sort_keys=False)

    def save(self, path: Path) -> None:
        path.write_text(self.to_yaml())


# ── Textual widget ────────────────────────────────────────────────────────────

try:
    from textual.app import ComposeResult
    from textual.binding import Binding
    from textual.message import Message
    from textual.widgets import DataTable, Input, Static
    from textual.widget import Widget
    from textual.reactive import reactive

    class PipelineBuilder(Widget):
        """Interactive pipeline builder widget for the TUI.

        Keys:
          j/k     move cursor
          a       add step below cursor
          d       delete step at cursor
          w       toggle wait on cursor step
          Enter   edit prompt of cursor step
          p       confirm and return YAML to caller
          Esc     cancel
        """

        BINDINGS = [
            Binding("j", "cursor_down", "Down", show=False),
            Binding("k", "cursor_up", "Up", show=False),
            Binding("a", "add_step", "Add"),
            Binding("d", "delete_step", "Delete"),
            Binding("w", "toggle_wait", "Wait"),
            Binding("p", "confirm", "Confirm"),
            Binding("escape", "cancel", "Cancel"),
        ]

        cursor: reactive[int] = reactive(0)

        def __init__(self, model: PipelineBuilderModel, **kwargs) -> None:
            super().__init__(**kwargs)
            self.model = model
            self._editing: bool = False

        def compose(self) -> ComposeResult:
            yield Static(id="builder-help", markup=True)
            yield DataTable(id="builder-table", cursor_type="row")

        def on_mount(self) -> None:
            table = self.query_one("#builder-table", DataTable)
            table.add_columns("#", "Agent", "Wait", "Prompt")
            self._refresh_table()
            self._update_help()

        def _refresh_table(self) -> None:
            table = self.query_one("#builder-table", DataTable)
            table.clear()
            for i, step in enumerate(self.model.steps):
                tier_str = str(step.tier)
                wait_str = "[x]" if step.wait else "[ ]"
                agent_str = f"[yellow]{step.agent}[/yellow]" if step.ambiguous else step.agent
                prompt_short = step.prompt[:48] + "…" if len(step.prompt) > 48 else step.prompt
                table.add_row(tier_str, agent_str, wait_str, prompt_short)
            if self.model.steps:
                row = min(self.cursor, len(self.model.steps) - 1)
                table.move_cursor(row=row)

        def _update_help(self) -> None:
            help_widget = self.query_one("#builder-help", Static)
            help_widget.update(
                "[dim]j/k[/dim] move  [dim]a[/dim] add  [dim]d[/dim] del  "
                "[dim]w[/dim] wait  [dim]p[/dim] confirm  [dim]Esc[/dim] cancel"
            )

        def action_cursor_down(self) -> None:
            if self.cursor < len(self.model.steps) - 1:
                self.cursor += 1
                self._refresh_table()

        def action_cursor_up(self) -> None:
            if self.cursor > 0:
                self.cursor -= 1
                self._refresh_table()

        def action_add_step(self) -> None:
            tier = self.model.steps[self.cursor].tier + 1 if self.model.steps else 1
            self.model.add_step(BuilderStep(agent="", prompt="", tier=tier))
            self.cursor = len(self.model.steps) - 1
            self._refresh_table()

        def action_delete_step(self) -> None:
            self.model.remove_step(self.cursor)
            self.cursor = max(0, self.cursor - 1)
            self._refresh_table()

        def action_toggle_wait(self) -> None:
            self.model.toggle_wait(self.cursor)
            self._refresh_table()

        def action_confirm(self) -> None:
            self.post_message(self.Confirmed(self.model))

        def action_cancel(self) -> None:
            self.post_message(self.Cancelled())

        class Confirmed(Message):
            def __init__(self, model: PipelineBuilderModel) -> None:
                super().__init__()
                self.model = model

        class Cancelled(Message):
            pass

except ImportError:
    # Textual not available — data model still works for tests
    pass
