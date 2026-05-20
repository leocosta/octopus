---
name: doc-prd
description: (Octopus) Synthesise the current conversation into a PRD and publish it to the issue tracker, labelled ready-for-agent.
---

---
description: (Octopus) Synthesise the current conversation into a PRD and publish it to the issue tracker, labelled ready-for-agent.
agent: code
---

# /octopus:doc-prd

## Purpose

The `doc-prd` skill engages automatically when the user asks to turn
a finished discussion into a tracker-ready PRD; this slash command
drives it explicitly for a single PRD the user wants to produce now.

## Usage

```
/octopus:doc-prd [optional title hint]
```

## Instructions

Invoke the `doc-prd` skill (`skills/doc-prd/SKILL.md`). The skill
owns the full protocol — do not reinterpret it here.

Refuse if the conversation does not already contain pinned decisions.
Hand back to `doc-align` or `superpowers:brainstorming` instead.
