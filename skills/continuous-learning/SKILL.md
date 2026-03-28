---
name: continuous-learning
description: >
  Continuous learning system that captures insights, tests hypotheses, and
  promotes confirmed patterns to rules. Inspired by the Claude.md learning
  protocol — adapted for multi-agent environments (Kilo Code, Codex, Copilot, etc.)
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

## Integration with Octopus Agents

### Kilo Code
Instructions are inlined in `.kilocode/rules.md` via concatenate mode.
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
