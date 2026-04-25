"""Tests for pipeline builder step management and YAML serialization."""
from __future__ import annotations

import yaml
import pytest

from cli.control.pipeline_builder import BuilderStep, PipelineBuilderModel


# ── BuilderStep ───────────────────────────────────────────────────────────────

def test_builder_step_defaults():
    s = BuilderStep(agent="tech-writer", prompt="create spec")
    assert s.tier == 1
    assert s.wait is False
    assert s.ambiguous is False


def test_builder_step_from_nl_step():
    from cli.control.nl_parser import PipelineStep
    nl = PipelineStep(agent="product-manager", prompt="review spec", tier=2, wait=True)
    s = BuilderStep.from_nl_step(nl)
    assert s.agent == "product-manager"
    assert s.tier == 2
    assert s.wait is True


# ── PipelineBuilderModel ──────────────────────────────────────────────────────

def test_model_starts_empty():
    m = PipelineBuilderModel()
    assert m.steps == []


def test_add_step_appends():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="create spec"))
    assert len(m.steps) == 1


def test_remove_step_by_index():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="a"))
    m.add_step(BuilderStep(agent="product-manager", prompt="b"))
    m.remove_step(0)
    assert len(m.steps) == 1
    assert m.steps[0].agent == "product-manager"


def test_remove_step_out_of_bounds_is_noop():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="a"))
    m.remove_step(99)
    assert len(m.steps) == 1


def test_move_step_up():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="a", prompt="first"))
    m.add_step(BuilderStep(agent="b", prompt="second"))
    m.move_step(1, -1)
    assert m.steps[0].agent == "b"
    assert m.steps[1].agent == "a"


def test_move_step_down():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="a", prompt="first"))
    m.add_step(BuilderStep(agent="b", prompt="second"))
    m.move_step(0, 1)
    assert m.steps[0].agent == "b"


def test_move_step_out_of_bounds_is_noop():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="a", prompt="first"))
    m.move_step(0, -1)  # already at top
    assert m.steps[0].agent == "a"


def test_toggle_wait():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="pm", prompt="review"))
    m.toggle_wait(0)
    assert m.steps[0].wait is True
    m.toggle_wait(0)
    assert m.steps[0].wait is False


# ── YAML serialization ────────────────────────────────────────────────────────

def test_to_yaml_basic_structure():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="create spec", tier=1))
    m.add_step(BuilderStep(agent="product-manager", prompt="review spec", tier=2, wait=True))
    doc = yaml.safe_load(m.to_yaml())
    assert "tasks" in doc
    assert len(doc["tasks"]) == 2


def test_to_yaml_sequential_depends_on():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="write", tier=1))
    m.add_step(BuilderStep(agent="product-manager", prompt="review", tier=2))
    doc = yaml.safe_load(m.to_yaml())
    t1 = doc["tasks"][0]
    t2 = doc["tasks"][1]
    assert t2["depends_on"] == [t1["id"]]
    assert t1.get("depends_on", []) == []


def test_to_yaml_parallel_steps_same_depends_on():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="tech-writer", prompt="write", tier=1))
    m.add_step(BuilderStep(agent="frontend-spec", prompt="fe", tier=2))
    m.add_step(BuilderStep(agent="backend-spec", prompt="be", tier=2))
    doc = yaml.safe_load(m.to_yaml())
    t1_id = doc["tasks"][0]["id"]
    assert doc["tasks"][1]["depends_on"] == [t1_id]
    assert doc["tasks"][2]["depends_on"] == [t1_id]


def test_to_yaml_wait_field_present():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="pm", prompt="review", wait=True))
    doc = yaml.safe_load(m.to_yaml())
    assert doc["tasks"][0]["wait"] is True


def test_to_yaml_system_agent():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="system", prompt="merge to develop"))
    doc = yaml.safe_load(m.to_yaml())
    assert doc["tasks"][0]["agent"] == "system"


def test_from_nl_pipeline_populates_steps():
    from cli.control.nl_parser import parse_nl_pipeline
    m = PipelineBuilderModel.from_nl_pipeline(
        "@tech-writer create spec. @product-manager review it."
    )
    assert len(m.steps) == 2
    assert m.steps[0].agent == "tech-writer"
    assert m.steps[1].agent == "product-manager"


def test_to_yaml_round_trip_ids_are_stable():
    m = PipelineBuilderModel()
    m.add_step(BuilderStep(agent="a", prompt="task"))
    yaml1 = m.to_yaml()
    yaml2 = m.to_yaml()
    assert yaml.safe_load(yaml1)["tasks"][0]["id"] == yaml.safe_load(yaml2)["tasks"][0]["id"]
