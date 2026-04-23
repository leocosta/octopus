import sys
sys.path.insert(0, ".")
from cli.control.pipeline import parse_pipeline_frontmatter
from pathlib import Path
import textwrap


PLAN_WITH_PIPELINE = textwrap.dedent("""\
    ---
    slug: user-auth
    generated_by: octopus:doc-plan
    pipeline:
      review_skill: octopus:codereview
      pr_on_success: true
    tasks:
      - id: t1
        agent: backend-specialist
        depends_on: []
      - id: t2
        agent: frontend-specialist
        depends_on: [t1]
    ---

    # User Auth Implementation Plan

    - [ ] **t1** — Create users table
    - [ ] **t2** — Build login screen
""")


def test_parse_pipeline_frontmatter_returns_tasks(tmp_path):
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN_WITH_PIPELINE)
    meta, tasks = parse_pipeline_frontmatter(plan)
    assert meta["pipeline"]["pr_on_success"] is True
    assert len(tasks) == 2
    assert tasks[0].id == "t1"
    assert tasks[0].agent == "backend-specialist"
    assert tasks[0].depends_on == []
    assert tasks[1].depends_on == ["t1"]


def test_parse_plan_without_pipeline_raises(tmp_path):
    plan = tmp_path / "plan.md"
    plan.write_text("# Simple plan\n\n- [ ] do something\n")
    try:
        parse_pipeline_frontmatter(plan)
        assert False, "Expected ValueError"
    except ValueError as e:
        assert "pipeline" in str(e).lower()


def test_task_bodies_extracted_from_markdown(tmp_path):
    plan = tmp_path / "plan.md"
    plan.write_text(PLAN_WITH_PIPELINE)
    _, tasks = parse_pipeline_frontmatter(plan)
    assert tasks[0].body == "Create users table"
    assert tasks[1].body == "Build login screen"
