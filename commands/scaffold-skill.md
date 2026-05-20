---
name: scaffold-skill
description: (Octopus) Create a new Octopus skill end-to-end — frontmatter, SKILL.md, optional REFERENCE.md, and bundle registration so no skill ships loose.
---

---
description: (Octopus) Create a new Octopus skill end-to-end — frontmatter, SKILL.md, optional REFERENCE.md, and bundle registration so no skill ships loose.
agent: code
---

# /octopus:scaffold-skill

## Purpose

The `scaffold-skill` skill defines the meta-discipline for authoring
new skills. This slash command drives it explicitly when the user
wants to create one now — useful as a canonical invocation point
alongside the other engineering-process commands.

## Usage

```
/octopus:scaffold-skill <short description of the new skill>
```

## Instructions

Invoke the `scaffold-skill` skill (`skills/scaffold-skill/SKILL.md`).
The skill owns the requirements gather, the layout (SKILL.md +
optional REFERENCE.md / EXAMPLES.md / scripts/ at one level), the
description shape rule, the length budget (target ≤ 150 lines, hard
cap 250), the scripts-over-generated-code rule, and the Octopus-
specific bundle registration step — do not reinterpret here.

The flow ends with the bundle edit, not with the SKILL.md write.
A skill not registered in any bundle is not discoverable by the
setup flow.
