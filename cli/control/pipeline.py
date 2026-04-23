from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class PipelineTask:
    id: str
    agent: str
    depends_on: list[str]
    skill: str | None
    body: str
    status: str = "waiting"


def parse_pipeline_frontmatter(plan_path: Path) -> tuple[dict, list[PipelineTask]]:
    raise NotImplementedError("parse_pipeline_frontmatter not yet implemented")
