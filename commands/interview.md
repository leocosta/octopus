---
name: interview
description: (Octopus) Run the requirements interview to scope one feature or problem — one question at a time until intent is concrete enough to feed doc-align, doc-prd, or implement. For area-level exploration that generates multiple backlog items, use /octopus:doc-research.
---

# /octopus:interview

## Purpose

The `interview` skill is the **greenfield** grilling skill — it runs
when the user has an idea but no plan yet, with no dependency on
`CONTEXT.md` or `docs/adr/`. This slash command drives it explicitly
when the user wants to shape requirements before any design or code
starts.

## Usage

```
/octopus:interview <one-sentence statement of the problem or goal>
```

## Instructions

Invoke the `interview` skill (`skills/interview/SKILL.md`). The skill
owns the one-question-per-turn discipline, the decision-tree tracking,
the "Established so far / Still unresolved" recap format, and the
hand-off rule (interview → doc-align / doc-prd / implement) — do not
reinterpret here.

If the user did not supply a one-sentence root statement, the first
turn of the interview is dedicated to producing one. Do not start
branching the tree until the root is confirmed.
