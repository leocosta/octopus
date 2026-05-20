# scaffold-skill — Reference

## The Description Field

The `description:` in the frontmatter is **the only thing the agent
sees when deciding whether to invoke the skill**. Treat it as the
skill's marketing copy.

### Rules

- Max ~1024 chars
- Third person, indicative ("Synthesises X", not "I synthesise X")
- First sentence: the capability
- Second sentence: "Use when …" with concrete triggers

### Bad description

> "Helps with documents."

Why it fails: doesn't differentiate from any other doc-related skill;
no trigger; no capability boundary.

### Good description

> "Synthesise the current conversation context into a PRD and publish
> it to the issue tracker without re-interviewing the user. Use when
> a brainstorm or doc-align session just concluded and decisions are
> fresh in context."

Why it works: names the artifact (PRD), names the anti-behaviour (no
re-interview), names the trigger (post-brainstorm).

## Review Checklist

Before closing a `scaffold-skill` session, confirm:

- [ ] Frontmatter present with `name` and `description`
- [ ] Description has capability + "Use when" triggers
- [ ] SKILL.md target ≤ 150 lines, hard cap 250 (run `wc -l skills/<name>/SKILL.md`)
- [ ] No time-sensitive content ("as of Q3 2025" rots)
- [ ] Vocabulary consistent with `CONTEXT.md` and adjacent skills
- [ ] Anti-Patterns section present and concrete (forbidden behaviours
      named, not just "be careful")
- [ ] Integration with Other Skills section names siblings and
      composers, including external (`superpowers:*`) where relevant
- [ ] Registered in `bundles/<bundle>.yml` under `skills:`
- [ ] References one level deep — SKILL.md → REFERENCE.md only, no
      chains
- [ ] If the skill describes a deterministic operation, that operation
      is a script in `scripts/`, not prose

## When to Split into REFERENCE.md

Split when **any** of the following holds:

- SKILL.md would exceed ~250 lines
- The skill has a distinct lookup section (vocabulary table, signal
  catalog, worked examples) that the agent does not need to read
  every time
- A section has its own internal structure (subsections, multiple
  tables) — that section is a sub-domain and belongs in REFERENCE

Do **not** split when the content is core protocol — protocol stays
in SKILL.md even if it pushes the line count up. Splitting protocol
fragments the workflow.

## Worked Example — Naming a New Skill

Suppose the user wants a skill that detects PII leaks before commit.

### Octopus naming pattern

| Pattern | Example | Use when |
|---|---|---|
| `<family>-<verb>` | `doc-align`, `doc-prd` | Belongs to an existing family |
| `<verb>-<noun>` | `refactor-deepen`, `scaffold-skill` | New family or one-off |
| `<verb>` (single word) | `debug`, `implement`, `prototype` | Foundational action |

For PII-leak detection:

- Foundational? No — narrow scope. Rule out single-word.
- Existing family? `audit-*` exists (`audit-money`, `audit-tenant`,
  `audit-security`) — fits.
- **Name: `audit-pii`**

### Bundle

`audit-*` skills live in the `quality` bundle → register there.

### Description

> "Scan staged changes for PII leaks — emails, document numbers,
> phone numbers, names — using project-configured rules. Use when
> running pre-commit audits on a feature branch or when handling
> a customer-data migration."

Concrete capability, concrete triggers, references project config —
agent can decide invocation without reading the body.
