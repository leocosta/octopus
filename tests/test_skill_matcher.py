import sys
sys.path.insert(0, ".")
from cli.control.skill_matcher import SkillMatcher
from pathlib import Path

MOCK_SKILLS = {
    "audit-security": {"keywords": ["auth", "jwt", "secret"], "model": None},
    "audit-money":  {"keywords": ["payment", "stripe"],     "model": "claude-opus-4-7"},
}


def make_matcher(tmp_path):
    return SkillMatcher(skills_dir=tmp_path, _mock=MOCK_SKILLS)


def test_slash_command(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/audit-security src/auth/", role_model="claude-sonnet-4-6")
    assert r.skill == "audit-security"
    assert r.model == "claude-sonnet-4-6"


def test_slash_with_model_flag(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/audit-security --model opus", role_model="claude-sonnet-4-6")
    assert r.model == "claude-opus-4-7"


def test_nl_single_match(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("check jwt tokens", role_model="claude-sonnet-4-6")
    assert r.skill == "audit-security" and r.needs_confirm is True


def test_nl_no_match(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("refactor the database layer", role_model="claude-sonnet-4-6")
    assert r.skill is None and r.raw_prompt == "refactor the database layer"


def test_skill_model_wins_over_role(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/audit-money", role_model="claude-sonnet-4-6")
    assert r.model == "claude-opus-4-7"


def test_nl_ambiguous(tmp_path):
    mock = {
        "audit-security": {"keywords": ["auth", "payment"], "model": None},
        "audit-money":  {"keywords": ["payment", "stripe"], "model": None},
    }
    m = SkillMatcher(skills_dir=tmp_path, _mock=mock)
    r = m.resolve("process payment auth", role_model="claude-sonnet-4-6")
    assert r.skill is None and r.ambiguous is not None and len(r.ambiguous) >= 2


def test_slash_unknown_skill(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("/unknown-skill some args", role_model="claude-sonnet-4-6")
    assert r.skill == "unknown-skill"


def test_empty_input(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("", role_model="claude-sonnet-4-6")
    assert r.skill is None and r.raw_prompt == ""


def test_at_role_prefix_extracted(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@writer: write the ADR", role_model="claude-sonnet-4-6")
    assert r.role_override == "writer"
    assert r.raw_prompt == "write the ADR"


def test_at_role_prefix_with_slash_skill(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@backend-developer: /audit-security src/auth/", role_model="claude-sonnet-4-6")
    assert r.role_override == "backend-developer"
    assert r.skill == "audit-security"


def test_no_at_role_prefix_unchanged(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("write the ADR", role_model="claude-sonnet-4-6")
    assert r.role_override is None


def test_at_role_with_hyphen(tmp_path):
    m = make_matcher(tmp_path)
    r = m.resolve("@frontend-developer: build the login screen", role_model="claude-sonnet-4-6")
    assert r.role_override == "frontend-developer"
    assert r.raw_prompt == "build the login screen"
