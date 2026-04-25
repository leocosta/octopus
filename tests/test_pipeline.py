import sys
import textwrap
sys.path.insert(0, ".")
import pytest
from pathlib import Path
from cli.control.pipeline import PipelineRunner, PipelineTask


PLAN = textwrap.dedent("""\
    ---
    slug: auth
    pipeline:
      review_skill: octopus:codereview
      pr_on_success: false
    tasks:
      - id: t1
        agent: backend-developer
        depends_on: []
      - id: t2
        agent: frontend-developer
        depends_on: [t1]
      - id: t3
        agent: writer
        depends_on: [t1]
    ---

    - [ ] **t1** — Create users table
    - [ ] **t2** — Build login screen
    - [ ] **t3** — Write API docs
""")


def make_runner(tmp_path, plan_text=PLAN):
    plan = tmp_path / "plan.md"
    plan.write_text(plan_text)
    runner = PipelineRunner(plan, octopus_dir=tmp_path / ".octopus")
    return runner, plan


def test_ready_tasks_starts_with_no_deps(tmp_path):
    runner, _ = make_runner(tmp_path)
    ready = runner._ready_tasks()
    assert len(ready) == 1
    assert ready[0].id == "t1"


def test_ready_tasks_unblocks_after_dependency_done(tmp_path):
    runner, _ = make_runner(tmp_path)
    runner._tasks[0].status = "done"  # t1 done
    ready = runner._ready_tasks()
    ids = {t.id for t in ready}
    assert ids == {"t2", "t3"}


def test_ready_tasks_skips_already_running(tmp_path):
    runner, _ = make_runner(tmp_path)
    runner._tasks[0].status = "done"
    runner._tasks[1].status = "running"
    ready = runner._ready_tasks()
    assert len(ready) == 1
    assert ready[0].id == "t3"


def test_update_checkbox_marks_done(tmp_path):
    runner, plan = make_runner(tmp_path)
    runner._update_checkbox("t1")
    content = plan.read_text()
    assert "- [x] **t1**" in content
    assert "- [ ] **t2**" in content


def test_build_prompt_with_skill(tmp_path):
    runner, _ = make_runner(tmp_path)
    task = PipelineTask(id="tx", agent="reviewer", depends_on=[],
                        skill="octopus:codereview", body="scan auth/")
    assert runner._build_prompt(task) == "/octopus:codereview scan auth/"


def test_build_prompt_without_skill(tmp_path):
    runner, _ = make_runner(tmp_path)
    task = PipelineTask(id="tx", agent="backend-developer", depends_on=[],
                        skill=None, body="Implement login endpoint")
    assert runner._build_prompt(task) == "Implement login endpoint"


def test_build_prompt_bare_skill_gets_namespace(tmp_path):
    runner, _ = make_runner(tmp_path)
    task = PipelineTask(id="tx", agent="reviewer", depends_on=[],
                        skill="codereview", body="")
    assert runner._build_prompt(task).startswith("/octopus:codereview")


def test_all_tasks_succeed_returns_true(tmp_path, monkeypatch):
    runner, _ = make_runner(tmp_path)
    launched = []
    codes = {"backend-developer": 0, "frontend-developer": 0, "writer": 0, "reviewer": 0}
    monkeypatch.setattr(runner.pm, "launch",
                        lambda role, prompt, model, isolate=False: launched.append(role) or 1)
    monkeypatch.setattr(runner.pm, "exit_code", lambda role: codes.get(role))
    result = runner.run()
    assert result is True
    assert {"backend-developer", "frontend-developer", "writer"}.issubset(set(launched))


def test_failed_task_returns_false(tmp_path, monkeypatch):
    runner, _ = make_runner(tmp_path)
    monkeypatch.setattr(runner.pm, "launch",
                        lambda role, prompt, model, isolate=False: 1)
    monkeypatch.setattr(runner.pm, "exit_code",
                        lambda role: 1 if role == "backend-developer" else None)
    result = runner.run()
    assert result is False


def test_parse_plan_without_pipeline_raises(tmp_path):
    plan = tmp_path / "bad.md"
    plan.write_text("# No frontmatter\n\n- [ ] do something\n")
    with pytest.raises(ValueError):
        PipelineRunner(plan, octopus_dir=tmp_path / ".octopus")


def test_review_gate_dispatches_reviewer(tmp_path, monkeypatch):
    runner, _ = make_runner(tmp_path)
    launched = []
    monkeypatch.setattr(runner.pm, "launch",
                        lambda role, prompt, model, isolate=False: launched.append((role, prompt)) or 1)
    monkeypatch.setattr(runner.pm, "exit_code", lambda role: 0)
    runner.run_review_gate()
    assert any(role == "reviewer" for role, _ in launched)
    assert any("codereview" in prompt for _, prompt in launched)


def test_review_gate_skipped_when_no_review_skill(tmp_path, monkeypatch):
    plan = tmp_path / "plan.md"
    plan.write_text(textwrap.dedent("""\
        ---
        slug: simple
        pipeline:
          pr_on_success: false
        tasks:
          - id: t1
            agent: backend-developer
            depends_on: []
        ---

        - [ ] **t1** — do thing
    """))
    runner = PipelineRunner(plan, octopus_dir=tmp_path / ".octopus")
    launched = []
    monkeypatch.setattr(runner.pm, "launch",
                        lambda role, prompt, model, isolate=False: launched.append(role) or 1)
    runner.run_review_gate()
    assert not launched


def test_review_gate_returns_true_on_zero_exit(tmp_path, monkeypatch):
    runner, _ = make_runner(tmp_path)
    monkeypatch.setattr(runner.pm, "launch", lambda role, prompt, model, cwd=None, isolate=False: 1)
    monkeypatch.setattr(runner.pm, "exit_code", lambda role: 0)
    assert runner.run_review_gate() is True


def test_review_gate_returns_false_on_nonzero_exit(tmp_path, monkeypatch):
    runner, _ = make_runner(tmp_path)
    monkeypatch.setattr(runner.pm, "launch", lambda role, prompt, model, cwd=None, isolate=False: 1)
    monkeypatch.setattr(runner.pm, "exit_code", lambda role: 1)
    assert runner.run_review_gate() is False
