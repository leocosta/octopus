# Spec: `/octopus:doc-design` — interactive design session

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-21 |
| **Author** | Leonardo Costa |
| **Status** | Implemented (2026-04-21) |
| **RFC** | N/A |
| **Roadmap** | RM-035 |

## Problem Statement

`/octopus:doc-spec <slug>` creates an empty spec stub from
`templates/spec.md`. The Design, Implementation Plan, Testing
Strategy, and Risks sections land as HTML-comment placeholders —
the author still has to sit down alone and brainstorm their way
through them.

External tooling fills this gap today: users invoke
`superpowers:brainstorming` (from the Claude Code Superpowers
plugin) to drive an interactive design session that produces the
same spec artefact with substance. That dependency blocks Octopus
from being self-sufficient: a repo that wants the full
"spec-design → plan → execute" loop has to install a second
ecosystem of skills.

RM-035 closes the first leg of that gap: bring the
design-brainstorming protocol inside Octopus as a native command,
producing specs in the same canonical path (`docs/specs/<slug>.md`)
and template the team already uses.

## Goals

- Ship `/octopus:doc-design <slug>` — an interactive command that
  fills a spec stub's Design, Implementation Plan, Testing, and
  (adaptively) Non-Goals / Risks / Migration sections through a
  one-question-at-a-time conversation.
- Reuse the existing `templates/spec.md` and `docs/specs/<slug>.md`
  path. No new template, no new directory.
- Offer the session as a natural chain from `/octopus:doc-spec`:
  after the stub is created, the command asks whether to continue
  into the design session now.
- Enforce a HARD-GATE: the command never writes production code,
  never creates branches, never dispatches implementation. Its
  terminal state is a committed spec.
- Ship the command in the `docs-discipline` bundle alongside the
  other `doc-*` commands and meta-tools.

## Non-Goals

- A separate SKILL.md. The protocol is on-demand, not always-on;
  a command keeps context-budget impact at zero.
- Generating the bite-sized TDD implementation plan. That is
  RM-036 (`/octopus:doc-plan`). `doc-design` stops at a
  higher-level Implementation Plan (3–7 ordered steps, files +
  dependencies).
- Measuring conversational quality in tests. The heuristics that
  drive section-by-section questions are LLM instructions, not
  code. Validation happens through dog-food.
- Replacing `/octopus:doc-research`. That command explores a
  topic to generate roadmap items; `doc-design` fills an existing
  spec. They sit at different stages of the workflow.

## Design

### Overview

`/octopus:doc-design` is a single markdown command under
`commands/doc-design.md`. It drives an eight-step conversational
protocol that consumes a spec stub (creating one first when
absent) and writes the Design / Implementation Plan / Testing /
adaptive sections in place, section by section, with user
approval after each write.

Responsibility split:

- **Command (`commands/doc-design.md`)** — owns the whole
  protocol: setup, context scan, section prompts, approval loop,
  commit, final handoff message.
- **Template (`templates/spec.md`)** — unchanged. Its existing
  HTML-comment placeholders mark the sections `doc-design`
  populates.
- **Chaining from `doc-spec`** — `commands/doc-spec.md` gets a
  final step: after writing the stub, ask "continue into the
  design session now? (y/N)". On `y`, the agent invokes
  `/octopus:doc-design <slug>`. On `N`, exits normally.
- **Bundle / wizard registration** — `doc-design` is listed in
  `bundles/docs-discipline.yml` and `cli/lib/setup-wizard.sh`.

### Detailed Design

#### Entry points

```
# Combined entry (via doc-spec)
/octopus:doc-spec <slug>
  → creates docs/specs/<slug>.md stub
  → prompts: "Continue into the design session now? (y/N)"
  → y: invokes /octopus:doc-design <slug>
  → N: exits normally

# Standalone entry
/octopus:doc-design <slug>
  → if docs/specs/<slug>.md missing: invokes doc-spec inline
  → proceeds into the 8-step protocol
```

#### Protocol steps

| # | Step | User interaction |
|---|---|---|
| 1 | Setup — resolve slug, ensure stub, load prefilled metadata/goals as read-only context | Asks for slug only if missing |
| 2 | Context scan — `git log --oneline -20`, `docs/roadmap.md` for matching RM-NNN, `knowledge/INDEX.md` if present, adjacent skills by keyword | Silent; reports `"scanned X; let's design"` in one line |
| 3 | Design → Overview | Question(s) → write → approve → save |
| 4 | Design → Detailed Design | Same mini-cycle |
| 5 | Adaptive sections (see triggers below) | Up to 2 extra sections; each follows the same mini-cycle |
| 6 | Implementation Plan (3–7 ordered steps; not TDD bite-sized — that's `doc-plan`'s job) | Question → write → approve → save |
| 7 | Context for Agents — knowledge / roles / ADRs / skills / bundle filled from conversation signals | Show → approve → save |
| 8 | Self-review + close — fix placeholders inline, append Changelog entry, `git add` + `git commit`, print path, STOP. HARD-GATE prohibits writing code | Just confirms commit message |

#### Adaptive-section triggers (Step 5)

Agent decides whether to prompt each optional section based on
signals gathered in Steps 2–4:

| Section | Triggers |
|---|---|
| **Non-Goals** | Stub already lists ≥ 3 Goals, OR the Overview discussion mentioned "not scoping X" / "later" / "separate spec" |
| **Risks** | Detailed Design involved a material trade-off; keywords in discussion: `breaking`, `performance`, `security`, `deadlock`, `race`, `migration`, `incompatible`; spec touches security- or money-sensitive code |
| **Migration / Backward Compatibility** | Slug or Problem Statement mentions the CLI (`octopus *`), manifest (`.octopus.yml`), template, hook, or public protocol; discussion mentioned "existing users / repos", "rename", "remove", "deprecated" |
| **Testing Strategy** | Always prompted (not optional); `"N/A — docs only, no code"` is an accepted answer |

**Anti-overload rule:** `doc-design` never triggers more than two
adaptive sections in one session. If three or more apply, the
agent picks the two strongest signals and mentions the rest:
> "I also spotted <X>; run `/octopus:doc-design <slug>` again to
> cover it."

Unfilled sections keep the template's HTML-comment placeholders.
The author can fill them manually or re-run `doc-design` later.

#### Approval loop (applies to Steps 3, 4, 5, 6, 7)

```
1. Ask the question(s) for the section (one question per message).
2. Draft the section text from the answers.
3. Show the draft to the user.
4. Ask: "Looks right? (y/revise/skip)"
   - y       → write the section into docs/specs/<slug>.md
   - revise  → re-ask targeted clarification, redraft
   - skip    → leave the section with its HTML placeholder
5. Move to next section.
```

#### Final handoff message (Step 8)

```
Spec ready at docs/specs/<slug>.md.

To generate the implementation plan, run:
  /octopus:doc-plan <slug>         (available once RM-036 ships)

Or create docs/plans/<slug>.md manually following the pattern in
docs/superpowers/plans/.
```

### Migration / Backward Compatibility

- `commands/doc-spec.md` gains a final prompt; existing users who
  script `/octopus:doc-spec` non-interactively need a way to
  skip it. Two options, evaluated during implementation:
  1. Non-interactive detection (no TTY → skip prompt, behave as
     today). Preferred.
  2. Explicit flag `--no-design` on `doc-spec`. Fallback if (1)
     is brittle.
- No change to `templates/spec.md`. Existing specs written by the
  old flow remain valid; `doc-design` can be run against them to
  fill any still-empty sections without reformatting.
- `docs-discipline` bundle adds one command — backwards
  compatible for repos that already opted into the bundle.

## Implementation Plan

1. **Create `commands/doc-design.md`.** Full protocol: entry
   resolution, 8 steps, adaptive triggers table, approval loop
   text, HARD-GATE banner, handoff message.
2. **Modify `commands/doc-spec.md`.** Append final prompt
   chaining into `/octopus:doc-design`; detect non-interactive
   runs and skip it.
3. **Register `doc-design`** in `bundles/docs-discipline.yml`
   (skills list) and `cli/lib/setup-wizard.sh` (items array +
   hints + display list).
4. **Create `tests/test_doc_design.sh`** covering structural
   checks (frontmatter, section names, trigger-table presence,
   HARD-GATE wording, bundle + wizard registration) and one
   test asserting `doc-spec` prompts for the chain (grep for
   the prompt string).
5. **Update roadmap** — move RM-035 from Backlog to Completed
   table on merge.
6. **Dog-food:** run `/octopus:doc-design bundle-diff-preview`
   and `/octopus:doc-design post-merge-audit-hook` in a
   follow-up session to validate the protocol on two
   dissimilar topics (wizard UX vs git hook).

## Context for Agents

**Knowledge modules**: N/A (no domain knowledge required;
workflow skill).
**Implementing roles**: tech-writer, backend-specialist (bash).
**Related ADRs**: none yet; a new ADR documenting the
"spec-design → plan → execute" loop may follow once RM-036 and
RM-037 ship.
**Skills needed**: `adr`, `feature-lifecycle`,
`plan-backlog-hygiene`.
**Bundle**: `docs-discipline (existing)` — no new bundle
proposed.

**Constraints**:
- Pure markdown command (no SKILL.md, no shell code of its own).
- Must reuse `templates/spec.md` unchanged.
- HARD-GATE: the command never writes production code, branches,
  or dispatches implementation.
- Never triggers more than two adaptive sections per session.
- Idempotent: re-running on a partially filled spec fills only
  still-empty sections; never overwrites user-authored prose.

## Testing Strategy

`tests/test_doc_design.sh` covers:

1. `commands/doc-design.md` exists with valid frontmatter.
2. Command references `templates/spec.md` and
   `/octopus:doc-spec` (fallback when stub missing).
3. Command documents the HARD-GATE. The literal string
   `HARD-GATE:` must appear in the command body (greppable
   anchor); the surrounding paragraph must also contain the
   words `do not write code` or an equivalent explicit
   prohibition.
4. Command documents all eight steps (`Step 1` … `Step 8`).
5. Command documents the adaptive-section names (Non-Goals,
   Risks, Migration).
6. `bundles/docs-discipline.yml` lists `doc-design`.
7. `cli/lib/setup-wizard.sh` items array + hints include
   `doc-design`.
8. `commands/doc-spec.md` contains the chaining prompt string.

**Not tested (and why):**
- Conversational quality — model-dependent; validated through
  dog-food.
- Adaptive trigger accuracy — instructions are LLM prompts, not
  deterministic code.
- Section-placement correctness — would require chat fixtures
  and parsed output; brittle and low-ROI. Left to human review
  in each real session.

**Dog-food validation:**
Once the command lands, run it against the two stubs created
earlier this session
(`docs/specs/bundle-diff-preview.md`,
`docs/specs/post-merge-audit-hook.md`). Two dissimilar
topics — a wizard UX enhancement and a git hook — stress the
protocol's generality.

## Risks

- **Overload of adaptive triggers.** Even with the two-section
  cap, a verbose author may surface five trigger-worthy signals
  across the conversation. Agent picks the strongest; the
  "mention the rest" line keeps them visible so nothing is
  silently dropped. Mitigation is social, not enforced.
- **Non-interactive `doc-spec` regression.** If the TTY-detection
  falls back wrong, scripted callers of `/octopus:doc-spec` may
  hang on the new prompt. Mitigation: add a test that runs the
  command non-interactively and asserts it exits without
  hanging; include the `--no-design` escape hatch if needed.
- **Spec drift from template.** `templates/spec.md` evolves
  over time; `doc-design` hard-codes assumptions about which
  sections it fills. Mitigation: the command reads the template
  at runtime and targets section headings by name, not by
  offset. A template change that renames a section would surface
  as an integration test failure before shipping.
- **Feature creep from `doc-research`.** Both commands ask
  questions; users might blur them. Mitigation: `doc-design`'s
  first step explicitly refuses to run without an existing RM
  context or explicit `<slug>`, while `doc-research` owns RM
  generation. The handoff boundary is the spec stub.

## Changelog

- **2026-04-21** — Initial draft (design session with
  Leonardo Costa).
