"""Natural language pipeline parser.

Converts free-form text with @mentions into a list of PipelineStep objects.
Used by the TUI pipeline builder to pre-fill steps from user input.
"""
from __future__ import annotations

import re
from dataclasses import dataclass, field

_WAIT_VERBS = re.compile(
    r"\b(revise|review|valide|validate|approve|aprove|aprova)\b",
    re.IGNORECASE,
)

_PARALLEL_CONNECTORS = re.compile(
    r"\b(e|and|em\s+paralelo|in\s+parallel|simultaneamente)\b",
    re.IGNORECASE,
)

_MENTION_RE = re.compile(r"@([\w-]+)")

_EXPLICIT_WAIT_RE = re.compile(r"\[wait\]\s*", re.IGNORECASE)


@dataclass
class PipelineStep:
    agent: str
    prompt: str
    tier: int = 1
    wait: bool = False
    ambiguous: bool = False


def parse_nl_pipeline(text: str) -> list[PipelineStep]:
    """Parse NL text with @mentions into pipeline steps.

    Rules:
    - Each @mention starts a new step; its prompt is the text until the next @mention.
    - `wait=True` is inferred when the prompt contains review verbs.
    - `[wait]` explicit modifier also sets `wait=True` and is removed from the prompt.
    - Two @mentions on the same "phrase" (no sentence break between them, separated
      only by a parallel connector or whitespace) share the same tier.
    - Steps without a clear tier assignment are marked ambiguous.
    """
    text = text.strip()
    if not text:
        return []

    mentions = list(_MENTION_RE.finditer(text))
    if not mentions:
        return []

    # Split text into raw segments: (agent, raw_segment_text)
    raw_segments: list[tuple[str, str]] = []
    for i, m in enumerate(mentions):
        start = m.end()
        end = mentions[i + 1].start() if i + 1 < len(mentions) else len(text)
        segment = text[start:end].strip().lstrip(",").strip()
        raw_segments.append((m.group(1), segment))

    steps = _assign_tiers(raw_segments, text, mentions)
    return steps


# ── Tier assignment ────────────────────────────────────────────────────────────

def _assign_tiers(
    raw_segments: list[tuple[str, str]],
    full_text: str,
    mentions: list[re.Match],
) -> list[PipelineStep]:
    """Assign tier numbers and build PipelineStep objects."""
    steps: list[PipelineStep] = []
    current_tier = 1

    for i, (agent, segment) in enumerate(raw_segments):
        # Detect explicit [wait] modifier
        explicit_wait = bool(_EXPLICIT_WAIT_RE.search(segment))
        clean_segment = _EXPLICIT_WAIT_RE.sub("", segment).strip()

        wait = explicit_wait or bool(_WAIT_VERBS.search(clean_segment))
        ambiguous = False

        # Determine tier relative to previous step
        if i == 0:
            tier = 1
        else:
            prev_mention_end = mentions[i - 1].end()
            between = full_text[prev_mention_end:mentions[i].start()]
            tier, ambiguous = _infer_tier(between, current_tier)

        current_tier = tier

        steps.append(PipelineStep(
            agent=agent,
            prompt=clean_segment,
            tier=tier,
            wait=wait,
            ambiguous=ambiguous,
        ))

    return steps


def _infer_tier(between_text: str, current_tier: int) -> tuple[int, bool]:
    """Return (tier, is_ambiguous) based on text between two @mentions.

    Parallel: same tier.
    Sequential (sentence break): next tier.
    Ambiguous: no clear separator → flag.
    """
    stripped = between_text.strip().lstrip(",").strip()

    # No text between mentions at all → ambiguous
    if not stripped:
        return current_tier, True

    # Parallel connector only (e.g. "and", "e", "em paralelo") → same tier
    connector_only = _PARALLEL_CONNECTORS.fullmatch(stripped)
    if connector_only:
        return current_tier, False

    # Sentence-ending punctuation before next mention → sequential
    if re.search(r"[.!?]\s*$", stripped):
        return current_tier + 1, False

    # Connector present anywhere in the between-text → parallel
    if _PARALLEL_CONNECTORS.search(stripped):
        return current_tier, False

    # Fallback: treat as sequential but not ambiguous (clear segment break)
    return current_tier + 1, False
