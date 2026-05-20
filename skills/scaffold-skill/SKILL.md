---
name: scaffold-skill
description: >
  Create new Octopus skills with the correct structure — frontmatter
  with name + description, SKILL.md ≤ 250 lines, optional
  REFERENCE.md / EXAMPLES.md / scripts/ at one level of depth — and
  register the skill into a target bundle so no skill ships loose.
  Complements compress-skill (which modifies existing skills). Family
  *-skill.
triggers:
  keywords: ["new skill", "create skill", "scaffold skill", "author skill", "scaffold-skill"]
---

# Skill Authoring Protocol

## Overview

`scaffold-skill` is the meta-skill that produces new skills. It
enforces the format (frontmatter + body), the length budget (SKILL.md
under 100 lines), and the **Octopus-specific rule that no skill ships
loose** — every new skill is registered into an existing bundle or
proposes a new bundle in the same flow.

Description-writing rules, the review checklist, and worked examples
live in [REFERENCE.md](./REFERENCE.md).

## When to Engage

Engage when the user wants to:

- Create a new skill
- Port a workflow from another ecosystem into Octopus
- Extract repeated chat instructions into a durable skill

Do **not** engage when:

- The skill already exists — use `compress-skill` to refine it
- The desired behaviour is a one-shot — write a command in
  `commands/` instead
- The desired behaviour is a hook — write a hook, not a skill

## Protocol

### Step 1 — Gather requirements

Ask the user:

- What problem does the skill solve?
- What is the **one** triggering condition? (Multiple triggers usually
  means two skills)
- Are there deterministic operations? (Those become scripts)
- What reference material is needed? (Becomes `REFERENCE.md` if more
  than ~50 lines of standalone content)

### Step 2 — Draft the structure

Default layout:

```
skills/<name>/
  SKILL.md           # ≤ 100 lines, frontmatter + protocol
  REFERENCE.md       # optional — long lookup material
  EXAMPLES.md        # optional — worked examples
  scripts/           # optional — deterministic operations
```

**References stay one level deep.** SKILL.md may link to REFERENCE.md
and EXAMPLES.md; those files do **not** link further outward.

### Step 3 — Write SKILL.md

Sections, in order: frontmatter (`name`, `description`), `# Title`,
`## Overview` (one paragraph), `## When to Engage` (triggers and
non-triggers), `## Protocol` (numbered steps), `## Anti-Patterns`
(by name), `## Integration with Other Skills`.

Length budget: target ≤ 150 lines, hard cap 250. Over budget?
Split into REFERENCE.md (see the splitting rule in
[REFERENCE.md](./REFERENCE.md#when-to-split-into-referencemd)).

Description shape (the most important part of the skill): capability
first, then integration cues — pairs with X / active by default on Y
/ family of Z / triggers on path or keyword. Some skills also expose
a structured `triggers:` frontmatter field for automatic engagement.
The full rules and examples drawn from existing Octopus skills live
in [REFERENCE.md](./REFERENCE.md#the-description-field).

### Step 4 — Scripts beat generated code

If the skill describes a deterministic operation (parse JSON, hash a
file, format a date, run a query against a known endpoint), write a
script in `scripts/` and reference it from SKILL.md. Scripts save
tokens and improve reliability — generated code on every run is
wasteful and inconsistent.

### Step 5 — Register into a bundle

**Octopus-specific extension.** Every new skill ends with bundle
registration:

1. Decide which existing bundle owns this capability
   (`starter` / `quality` / `docs` / `growth` / `backend` / etc)
2. Add the skill name to `bundles/<bundle>.yml` under `skills:`
3. No existing bundle fits → propose a new one (rare) — output the
   YAML stub for review

A skill not in a bundle is not discoverable by the setup flow. The
flow ends with the bundle edit, not with the SKILL.md write.

### Step 6 — Review checklist

Run the [final checklist](./REFERENCE.md#review-checklist) before
closing the session.

## Anti-Patterns

- Shipping a skill not registered in any bundle
- Description that lists capability without triggers, or vice versa
- SKILL.md over 250 lines without a split into REFERENCE.md
- Reference chains (SKILL.md → REFERENCE.md → DEEP.md)
- Generated code on every run for operations a script can do once
- Skills with multiple triggers — split into two skills

## Integration with Other Skills

- **`compress-skill`** — sibling in the `*-skill` family. Use when
  the skill already exists and needs to shrink
- **`continuous-learning`** — when a recurring pattern shows up in
  `knowledge/`, `scaffold-skill` is how it graduates to a skill
- **`doc-lifecycle`** — when the skill encodes a hard-to-reverse
  architectural choice, an ADR accompanies it
- **`superpowers:writing-skills`** — when the superpowers plugin is
  installed, that skill's mechanics still apply; `scaffold-skill`
  adds the Octopus-specific bundle-registration step on top
