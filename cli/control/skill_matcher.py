import re
from dataclasses import dataclass, field
from pathlib import Path

MODEL_ALIASES = {
    "opus": "claude-opus-4-7",
    "sonnet": "claude-sonnet-4-6",
    "haiku": "claude-haiku-4-5-20251001",
}


@dataclass
class MatchResult:
    skill: str | None
    model: str
    raw_prompt: str
    needs_confirm: bool = False
    ambiguous: list[str] | None = None
    role_override: str | None = None


class SkillMatcher:
    def __init__(self, skills_dir: Path, _mock: dict | None = None):
        self._catalog = _mock if _mock is not None else self._load(skills_dir)

    def _load(self, skills_dir: Path) -> dict:
        catalog = {}
        for skill_md in skills_dir.glob("*/SKILL.md"):
            skill = skill_md.parent.name
            text = skill_md.read_text()
            kw = re.findall(r"keywords:\s*\[([^\]]+)\]", text)
            keywords = [w.strip().strip('"') for w in kw[0].split(",")] if kw else []
            model_m = re.search(r"^model:\s*(\S+)", text, re.MULTILINE)
            catalog[skill] = {
                "keywords": keywords,
                "model": model_m.group(1) if model_m else None,
            }
        return catalog

    def _resolve_model(self, flag: str | None, skill: str | None, role_model: str) -> str:
        if flag:
            return MODEL_ALIASES.get(flag, flag)
        if skill and self._catalog.get(skill, {}).get("model"):
            m = self._catalog[skill]["model"]
            return MODEL_ALIASES.get(m, m)
        return MODEL_ALIASES.get(role_model, role_model)

    def resolve(self, text: str, role_model: str) -> MatchResult:
        text = text.strip()

        # Pre-parse @role: prefix
        role_override = None
        at_match = re.match(r'^@([\w-]+):\s*', text)
        if at_match:
            role_override = at_match.group(1)
            text = text[at_match.end():]

        if text.startswith("/"):
            parts = text[1:].split()
            skill = parts[0] if parts else None
            model_flag = None
            if "--model" in parts:
                idx = parts.index("--model")
                model_flag = parts[idx + 1] if idx + 1 < len(parts) else None
                parts = [p for i, p in enumerate(parts) if i not in (idx, idx + 1)]
            raw = " ".join(parts[1:]) if len(parts) > 1 else ""
            return MatchResult(
                skill=skill,
                raw_prompt=raw,
                model=self._resolve_model(model_flag, skill, role_model),
                role_override=role_override,
            )
        matched = [
            s for s, meta in self._catalog.items()
            if any(kw in text.lower() for kw in meta["keywords"])
        ]
        if len(matched) == 1:
            skill = matched[0]
            return MatchResult(
                skill=skill,
                raw_prompt=text,
                needs_confirm=True,
                model=self._resolve_model(None, skill, role_model),
                role_override=role_override,
            )
        if len(matched) > 1:
            return MatchResult(
                skill=None,
                raw_prompt=text,
                ambiguous=matched,
                model=self._resolve_model(None, None, role_model),
                role_override=role_override,
            )
        return MatchResult(
            skill=None,
            raw_prompt=text,
            model=self._resolve_model(None, None, role_model),
            role_override=role_override,
        )
