"""Tests for the natural language pipeline parser."""
from __future__ import annotations

import pytest

from cli.control.nl_parser import PipelineStep, parse_nl_pipeline


# ── @mention detection ────────────────────────────────────────────────────────

def test_single_mention_produces_one_step():
    steps = parse_nl_pipeline("@tech-writer, create a spec for lesson plans")
    assert len(steps) == 1
    assert steps[0].agent == "tech-writer"


def test_multiple_mentions_produce_multiple_steps():
    steps = parse_nl_pipeline(
        "@tech-writer, create a spec. @product-manager, review it."
    )
    assert len(steps) == 2
    assert steps[0].agent == "tech-writer"
    assert steps[1].agent == "product-manager"


def test_empty_input_returns_empty():
    assert parse_nl_pipeline("") == []
    assert parse_nl_pipeline("   ") == []


def test_no_mentions_returns_empty():
    assert parse_nl_pipeline("just some free text with no mentions") == []


# ── Prompt extraction ─────────────────────────────────────────────────────────

def test_prompt_is_text_after_mention():
    steps = parse_nl_pipeline("@tech-writer create a spec for lesson plans")
    assert "create a spec for lesson plans" in steps[0].prompt


def test_prompt_strips_comma_after_mention():
    steps = parse_nl_pipeline("@tech-writer, create a spec")
    assert steps[0].prompt.startswith("create")


def test_each_step_prompt_excludes_next_mention():
    steps = parse_nl_pipeline("@tech-writer create spec. @product-manager review it.")
    assert "product-manager" not in steps[0].prompt
    assert "tech-writer" not in steps[1].prompt


# ── Step numbering (sequential by default) ───────────────────────────────────

def test_sequential_steps_get_increasing_tier():
    steps = parse_nl_pipeline("@tech-writer write. @product-manager review.")
    assert steps[0].tier == 1
    assert steps[1].tier == 2


# ── Wait inference ────────────────────────────────────────────────────────────

@pytest.mark.parametrize("verb", ["revise", "review", "valide", "validate", "approve", "aprove", "aprova"])
def test_wait_inferred_for_review_verbs(verb):
    steps = parse_nl_pipeline(f"@product-manager {verb} the spec")
    assert steps[0].wait is True


def test_wait_false_for_non_review_verbs():
    steps = parse_nl_pipeline("@tech-writer create a spec")
    assert steps[0].wait is False


def test_wait_false_for_execution_verb_implement():
    steps = parse_nl_pipeline("@backend-spec implement the API")
    assert steps[0].wait is False


# ── Parallelism inference ─────────────────────────────────────────────────────

@pytest.mark.parametrize("connector", ["e", "and", "em paralelo", "in parallel", "simultaneamente"])
def test_parallel_connector_assigns_same_tier(connector):
    steps = parse_nl_pipeline(
        f"@tech-writer write spec. @frontend-spec {connector} @backend-spec implement."
    )
    frontend = next(s for s in steps if s.agent == "frontend-spec")
    backend = next(s for s in steps if s.agent == "backend-spec")
    assert frontend.tier == backend.tier


def test_non_parallel_mentions_have_different_tiers():
    steps = parse_nl_pipeline("@tech-writer write. @product-manager review.")
    assert steps[0].tier != steps[1].tier


# ── Ambiguous steps ───────────────────────────────────────────────────────────

def test_ambiguous_steps_are_flagged():
    # When we can't infer parallelism clearly, step is marked ambiguous
    # Here: two mentions with no connector and no clear separator
    steps = parse_nl_pipeline("@frontend-spec @backend-spec implement")
    assert any(s.ambiguous for s in steps)


# ── Explicit [wait] modifier ──────────────────────────────────────────────────

def test_explicit_wait_modifier_sets_wait_true():
    steps = parse_nl_pipeline("@product-manager [wait] take a look at the code")
    assert steps[0].wait is True


def test_explicit_wait_modifier_removed_from_prompt():
    steps = parse_nl_pipeline("@product-manager [wait] take a look")
    assert "[wait]" not in steps[0].prompt


# ── Step dataclass ────────────────────────────────────────────────────────────

def test_step_has_expected_fields():
    steps = parse_nl_pipeline("@tech-writer create spec")
    s = steps[0]
    assert hasattr(s, "agent")
    assert hasattr(s, "prompt")
    assert hasattr(s, "tier")
    assert hasattr(s, "wait")
    assert hasattr(s, "ambiguous")
