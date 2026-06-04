---
name: standards
description: >
  Self-serve lookup answering 'what's our standard for X, and why?' from the
  team's own sources — docs/adr/ (decisions), rules/ (incl. *.local.md
  overrides), CONTEXT.md (vocabulary), knowledge/ (facts) — in that
  precedence, with the source cited. Never invents: routes to doc-adr or a
  rules override when nothing covers it. Read-only. Docs bundle.
triggers:
  keywords: ["what's our standard", "what is our standard", "our convention for", "is there a rule for", "why do we", "how do we do", "team standard"]
---

# Standards Lookup

## Overview

An engineer who asks *"what's our standard for X, and why?"* should not
have to ask a person — the answer already lives in version control. This
skill retrieves it: given a topic, it resolves the team's documented
standard, cites the source, and gives the rationale. It is the
**answering** counterpart to `audit-grounding`, which uses the same
sources to *flag* drift in a diff.

The skill is **read-only** and **never gates** anything. It answers a
question; it does not block a commit or approve a change.

## When to Engage

Engage when someone asks how the team does something, what the rule for
X is, or why a convention exists — in code or in conversation. Typical
cues: "what's our standard for error handling", "do we have a rule for
naming", "why do we use the Result pattern here".

Do **not** engage to:
- Gate or review a diff — that's `architect` / `audit-*`.
- Author a new standard — that's `doc-adr` or editing `rules/`. This
  skill *routes to* authoring when the standard is missing.

## The Sources (precedence order)

Resolve the topic against four sources, highest authority first:

1. **`docs/adr/*`** — decisions of record. A matching ADR is the
   strongest answer: "we decided X because Y (ADR-NNN)".
2. **`rules/`** — `rules/common/*.md` and per-language
   `rules/<lang>/*.md`, including `*.local.md` overrides. A `*.local.md`
   takes precedence over its base file, mirroring the rules-layer
   precedence used at setup.
3. **`CONTEXT.md`** — the domain glossary; the reference for
   vocabulary/naming questions (what the team *calls* things).
4. **`knowledge/<domain>/{rules,knowledge}.md`** — accumulated
   confirmed facts.

When two sources speak to the topic, prefer the higher one and mention
the others as supporting context.

## Protocol

1. **Take the topic** from the user (or infer it from the surrounding
   question). Normalize it (e.g. "exceptions", "API pagination").
2. **Search the four sources** in precedence order.
3. **Answer**, in this shape:
   - **Standard:** the rule/decision, in one or two sentences.
   - **Source:** the file path (clickable) — e.g.
     `docs/adr/004-result-pattern.md`, `exceptions.md`.
   - **Why:** the rationale, quoted or summarized from the source.
   - **Confidence:** `documented` (found) or `not-found`.
4. **The not-found path:** when no source covers the topic, say so
   plainly — "no documented standard for X" — and **never invent** one.
   Route the user to author it:
   - a decision → `/octopus:doc-adr`
   - a coding rule → a `rules/common/<topic>.local.md` override
   This makes the gap visible (and is itself a signal worth capturing).

## Anti-Patterns

- **Inventing an answer** the sources don't support — `not-found` over
  invention, always.
- **Gating or reviewing** — this skill answers; it never blocks.
- **Answering from generic best-practice** when the team has its own
  documented standard — cite the team's source first.
- **Editing** any source — it is strictly read-only.

## Integration with Other Skills

- **`audit-grounding`** — same four sources, opposite direction: it
  *flags* invented conventions / unsupported facts in a diff; this
  *answers* a question from them.
- **`doc-adr`** — the not-found route for decisions; authors the
  missing standard this skill couldn't find.
- **`continuous-learning`** — repeated `not-found` on the same topic is
  a signal that a standard should be authored and promoted.
- **`onboarding`** — composes this skill so a new engineer can self-
  serve standards questions during ramp-up.
