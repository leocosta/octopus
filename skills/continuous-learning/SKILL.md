---
name: continuous-learning
model: sonnet
description: >
  Capture insights, test hypotheses, and promote confirmed patterns to rules
  (adapted for multi-agent environments). Default mode is single-
  developer/session capture to knowledge/. Team mode aggregates recurring
  review feedback across the fleet into rule-promotion candidates — fleet-wide
  patterns promote to shared workspace rules, single-repo patterns stay local.
triggers:
  paths: ["knowledge/**", "docs/learning/**", "docs/research/**"]
  keywords: ["hypothesis", "recurring feedback", "team pattern", "keeps coming up", "promote to rule"]
  tools: []
---

# Continuous Learning Protocol

## Overview

This protocol implements an iterative learning cycle for Code Assistants. The system
evolves by capturing domain knowledge, testing hypotheses, and promoting confirmed
patterns into default rules.

## Workflow

### Before starting a new task

1. **Review existing rules and hypotheses** for the relevant domain
2. **Apply confirmed rules by default** — they are checked first before any manual
   decision
3. **Check if any hypothesis can be tested** with today's work — flag them for
   validation during the task

### After completing each task

1. **Extract insights** from what you learned during the task:
   - Patterns that emerged repeatedly
   - Edge cases you encountered
   - Domain-specific constraints
   - Tool or framework quirks

2. **Store insights** in the appropriate domain folder:

```
/knowledge/<domain>/
  knowledge.md    → Confirmed facts, patterns, and anti-patterns
  hypotheses.md   → Observations that need more data to confirm
  rules.md        → Auto-applied rules (confirmed 5+ times)
```

3. **Maintain `/knowledge/INDEX.md`** as a routing table that maps domains to
   their folder paths

## Promotion Rules

| Transition | Condition | Action |
|---|---|---|
| Hypothesis → Rule | Confirmed 5+ times across tasks | Move to `rules.md` with confirmation count |
| Rule → Hypothesis | Contradicted by new data | Demote back to `hypotheses.md` with evidence |
| Hypothesis → Discarded | Failed 3+ times | Remove from `hypotheses.md` |

## Output Format

Each file uses this structure:

### knowledge.md (Facts and Patterns)
```markdown
# <Domain> Knowledge

## Confirmed Facts
- [FACT-001] Description of confirmed fact
  - Evidence: Task/PR where confirmed
  - Date: YYYY-MM-DD

## Anti-Patterns
- [ANTI-001] Description of anti-pattern to avoid
  - Example: snippet showing the wrong approach
  - Reason: why it fails
```

### hypotheses.md (Needs More Data)
```markdown
# <Domain> Hypotheses

## Under Investigation
- [HYP-001] Hypothesis description
  - Predicted outcome: what should happen if true
  - Confirmed count: X/5
  - Failed count: Y/3
  - Last tested: YYYY-MM-DD
  - Evidence:
    - Task 1: result
    - Task 2: result
```

### rules.md (Apply by Default)
```markdown
# <Domain> Rules

## Auto-Applied Rules
- [RULE-001] Rule description
  - Confirmed 5 times across: task-1, task-2, ...
  - Enforces: what behavior/pattern this enforces
  - Exception: when this rule does NOT apply
```

## Team mode — fleet-wide review learning

Everything above is the **default mode**: a single developer's session capture
to `knowledge/`. **Team mode** lifts the same capture→promote loop to the
*team/review* scope: it aggregates recurring **review feedback** across the
fleet and turns repeated patterns into rule-promotion candidates — so "the
whole team keeps making mistake X" becomes a rule instead of a re-typed PR
comment.

### Capture (continuous, automatic)

A Stop hook — `hooks/stop/review-log-capture.sh` — reads the session
transcript, detects review findings (the `BLOCKING:` / `ADVISORY:` /
`QUESTION:` tags `architect` / `security` / `mentor` emit, and `pr-review`
report blocks), and appends one structured entry per finding to
`.octopus/review-log/<date>.md` (gitignored). No edits to the review skills —
the capture is deterministic and out of band.

```
- 2026-05-30 | repo=billing-api | src=architect | sev=ADVISORY | topic="missing test for error path" | file=users/service.ts:42
```

### Aggregate + promote (operator-run)

Run team mode to mine the log across the fleet:

1. **Resolve the fleet** — reuse the `fleet.yml` `repos:` list (same as
   `audit-fleet` / `fleet-bootstrap`). Mine each repo's `.octopus/review-log/`,
   bootstrapping from existing artifacts where the log is thin (`pr-review` PR
   comments, `mentor` `docs/mentoring/`, the `.octopus/proposals/` queue).
2. **Normalize + group** findings by topic ("missing test for error path",
   "custom exception without catch site").
3. **Count occurrences and distinct-repo spread** per topic in the window.
4. **Apply thresholds** — configurable in `fleet.yml`, with defaults:
   ```yaml
   # fleet.yml
   learning:
     local: 5         # 5+ occurrences within a single repo → local candidate
     fleet_repos: 3   # appears in 3+ distinct repos → workspace candidate
   ```
   **Spread routes the destination:** a pattern across `≥ fleet_repos` distinct
   repos promotes to the **shared `workspace:` rules** (inherited fleet-wide); a
   single-repo pattern over `local` stays that repo's local rule.

### Candidate shape (`.octopus/proposals/<ts>-team-pattern.md`)

- **Pattern:** the recurring finding, normalized.
- **Frequency:** N occurrences across which PRs/repos (cited) + distinct-repo count.
- **Proposed rule:** a draft line for `rules/common/<topic>.local.md` (workspace
  or local) or a `knowledge/` entry.
- **Route:** `workspace` (≥ `fleet_repos`) or `local` (≥ `local`).

Promotion reuses **`/octopus:review-proposals`** — the manager
promotes/partials/archives. **Human-gated; team mode never auto-edits a rule.**
A workspace-routed candidate, when promoted, writes to the workspace repo's
shared `rules/common/*.local.md`, inherited by every repo.

### Cadence

Capture is continuous (the hook fires every session with review output);
aggregation is **operator-run** (the manager runs team mode, pairing with the
weekly `review-proposals` habit) — consistent with `audit-fleet` /
`fleet-bootstrap`.

### Anti-Patterns (team mode)

- **Auto-promoting** a candidate — always human-gated via `review-proposals`.
- **Editing the review skills to capture** — capture is the Stop hook's job.
- **Counting raw occurrences only** — repo spread is the team signal and routes
  local vs workspace.

## Integration with Octopus Agents

### Open Code
Instructions are inlined in `.opencode/rules.md` via concatenate mode.
Before each task, reference:
```
/knowledge/INDEX.md → route to relevant domain
/knowledge/<domain>/rules.md → apply default rules
/knowledge/<domain>/hypotheses.md → check testable hypotheses
```

### Codex / Copilot / Other Agents
Same protocol. Knowledge files are project-level (readable by all agents).
The INDEX.md serves as the routing table for all agents.

### Claude Code
Instructions are symlinked to `.claude/skills/continuous-learning/`.
Knowledge folder is at repo root level, readable directly.

## Example Domain Structure

```
/knowledge/
├── INDEX.md                  # Domain router
├── pricing/
│   ├── knowledge.md          # Facts about pricing logic
│   ├── hypotheses.md         # Unconfirmed observations
│   └── rules.md              # Auto-applied pricing rules
├── authentication/
│   ├── knowledge.md
│   ├── hypotheses.md
│   └── rules.md
└── data-access/
    ├── knowledge.md
    ├── hypotheses.md
    └── rules.md
```
