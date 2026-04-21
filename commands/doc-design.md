---
name: doc-design
description: Interactive design session that fills a spec stub's Design, Implementation Plan, Testing, and adaptive sections one question at a time
---

---
description: Interactive design session that fills a spec stub's Design, Implementation Plan, Testing, and adaptive sections one question at a time
agent: code
---

# /octopus:doc-design

## Purpose

Drive a conversational design session that turns a spec stub
(produced by `/octopus:doc-spec`) into a fully populated
specification. Fills `## Design`, `## Implementation Plan`,
`## Testing Strategy`, `## Context for Agents`, and — when signals
warrant — `## Non-Goals`, `## Risks`, and `## Migration /
Backward Compatibility`. The session ends with the spec
committed to git; no implementation code is written.

## Usage

```
/octopus:doc-design [slug]
```

- Chained from `/octopus:doc-spec` when the user answers `y` to
  "continue into the design session now?".
- Runs standalone when the user invokes it directly. Creates the
  stub via `/octopus:doc-spec` first if `docs/specs/<slug>.md`
  does not yet exist.

## HARD-GATE

**HARD-GATE:** this command does not write production code, does
not write tests, does not create implementation branches, and
does not dispatch any implementation skill. The terminal state
is a committed spec in `docs/specs/<slug>.md`. Any request during
the session that drifts into implementation (writing code,
writing tests, creating a feature branch to code on) must be
declined — redirect the user to `/octopus:doc-plan` (RM-036) or
`/octopus:implement` once the spec is merged.

**Docs-only branches are permitted** (and expected when the
current branch is `main` or `master`). Step 8 creates
`docs/<slug>-design` solely to carry the spec commit, so the
change still lands via PR rather than directly on `main`.

## Instructions

### Step 1 — Setup

1. Resolve `<slug>`:
   - If `$ARGUMENTS` contains a slug, use it (kebab-case).
   - Otherwise ask: "What slug should we design? (kebab-case)".
2. Resolve the spec path: `docs/specs/<slug>.md`.
3. If the spec does not exist, invoke `/octopus:doc-spec <slug>`
   inline to create the stub (same flow the user would run
   themselves), then continue.
4. Read the stub. Extract the following as read-only context; do
   not overwrite them later:
   - Metadata block (Date, Author, Status, RFC, Roadmap)
   - Problem Statement
   - Goals
   - Non-Goals (if already filled)

### Step 2 — Context scan

Silently read, without asking the user a question:

- `git log --oneline -20` — recent activity.
- `docs/roadmap.md` — locate any `RM-<N>` entry whose description
  matches the slug or the stub's metadata `Roadmap` field.
- `knowledge/INDEX.md` if present.
- Skills adjacent to the topic by simple keyword match (e.g. slug
  contains `audit` → check `skills/audit-all/`, `skills/money-review/`).

Report in a single line: `"Scanned N commits, roadmap, and
adjacent skills. Let's design."`

### Step 3 — Design → Overview

1. Ask one or two focused questions about the high-level
   approach. Prefer multiple-choice when possible, one question
   per message.
2. Draft the `### Overview` subsection under `## Design`.
3. Show the draft. Ask: `"Looks right? (y / revise / skip)"`.
4. On `y`: write the draft into the spec file, replacing the
   existing HTML-comment placeholder under `### Overview`.
5. On `revise`: ask a targeted clarifying question and redraft.
6. On `skip`: leave the placeholder untouched; move on.

### Step 4 — Design → Detailed Design

Same mini-cycle as Step 3, targeting the `### Detailed Design`
subsection. Focus questions on components, data flow, and
interactions.

### Step 5 — Adaptive sections

For each optional section below, decide whether to prompt the
user based on the signals gathered so far. **Never trigger more
than two adaptive sections in one session.** If three or more
apply, pick the two strongest signals and mention the rest in
the final message: `"I also spotted <X>; run
/octopus:doc-design <slug> again to cover it."`

| Section | Trigger signals |
|---|---|
| **Non-Goals** | Stub already lists ≥ 3 Goals, OR the Overview discussion mentioned "not scoping X" / "later" / "separate spec" |
| **Risks** | Detailed Design involved a material trade-off; discussion keywords: `breaking`, `performance`, `security`, `deadlock`, `race`, `migration`, `incompatible`; spec touches security- or money-sensitive code |
| **Migration / Backward Compatibility** | Slug or Problem Statement mentions the CLI (`octopus *`), manifest (`.octopus.yml`), template, hook, or public protocol; discussion mentioned "existing users / repos", "rename", "remove", "deprecated" |

Each triggered section follows the same mini-cycle: ask → draft
→ show → approve → write.

### Step 6 — Implementation Plan (high level)

Ask: `"Walk me through the ordered steps — 3 to 7 items,
each with target files and dependencies."`

This is **not** the bite-sized TDD plan (that is RM-036's
`/octopus:doc-plan`). Stay at the "what file / what change"
level.

Draft the `## Implementation Plan` section as a numbered list.
Show → approve → write.

### Step 7 — Testing Strategy and Context for Agents

1. Ask: `"How do we validate this? Tests, manual review,
   dog-food? (A terse answer is fine; 'N/A — docs only, no
   code' is accepted.)"`.
2. Draft `## Testing Strategy`. Show → approve → write.
3. Draft `## Context for Agents` by inferring from the
   conversation:
   - **Knowledge modules** — any `knowledge/<module>` mentioned
     explicitly.
   - **Implementing roles** — inferred from the files being
     touched (backend, frontend, tech-writer, ...).
   - **Related ADRs** — any `docs/adr/*` cited or discovered in
     Step 2.
   - **Skills needed** — any skill mentioned by name during the
     session.
   - **Bundle** — required if the spec introduces a new skill.
     State `N/A — <reason>` otherwise.
4. Show the inferred block. Ask: `"Looks right? (y / revise)"`.
5. Write it into the spec.

### Step 8 — Self-review + close

1. Re-read the written spec. Scan for:
   - Remaining `<!-- ... -->` placeholders in sections you were
     responsible for (skipped ones are fine; sections you wrote
     should not have them).
   - Contradictions between sections.
   - Vague wording ("handle edge cases", "add validation
     appropriately", "TBD"). Rewrite inline.
2. Consolidate Metadata placeholders:
   - If the `Author` field still contains `<!-- Your name -->`,
     replace it with the output of `git config user.name`
     (fall back to "Unknown" if unset).
   - Leave other Metadata fields alone — they were set by
     `doc-spec` or by the user.
3. Append to the `## Changelog`:
   - `- **YYYY-MM-DD** — Design session completed`
     (replace `YYYY-MM-DD` with today's date).
4. Ensure a docs-only branch exists before committing:
   ```bash
   current_branch=$(git rev-parse --abbrev-ref HEAD)
   if [[ "$current_branch" == "main" || "$current_branch" == "master" ]]; then
     git checkout -b "docs/<slug>-design"
   fi
   ```
   Never commit the spec directly onto `main` or `master`.
5. Commit the spec:
   ```bash
   git add docs/specs/<slug>.md
   git commit -m "docs(specs): <slug> — design session

   Filled via /octopus:doc-design. Sections written: Overview,
   Detailed Design, <...list actually-written sections>,
   Implementation Plan, Testing Strategy, Context for Agents.

   Co-authored-by: claude <claude@anthropic.com>"
   ```
6. Print the final message:
   ```
   Spec ready at docs/specs/<slug>.md (branch: docs/<slug>-design).

   Open a PR for review, then — once merged — generate the
   implementation plan with:
     /octopus:doc-plan <slug>

   Or create docs/plans/<slug>.md manually following the
   pattern in docs/superpowers/plans/.
   ```
7. **STOP.** Do not implement, do not dispatch another skill,
   do not open the PR automatically. See the HARD-GATE section
   above.

## Idempotency

Re-running `/octopus:doc-design <slug>` on a partially filled
spec fills only still-empty sections. Never overwrite
user-authored prose. Detect "empty" by the presence of the
template's HTML-comment placeholder (`<!-- ... -->`) as the sole
content of a section.

## Template

All section names and their placeholder shapes come from
`templates/spec.md`. Read that file at the start of the session
if you need to resolve a section boundary or anchor.
