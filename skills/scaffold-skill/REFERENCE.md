# scaffold-skill — Reference

## The Description Field

The `description:` in the frontmatter is **the only thing the agent
sees when deciding whether to invoke the skill**. Treat it as the
skill's marketing copy.

### Rules

- Max ~1024 chars
- Third person, indicative ("Synthesises X", not "I synthesise X")
- First sentence: the **capability** — what the skill does, named
  artifacts where relevant
- Follow-up: **integration cues** that help the agent route — any of
  *pairs with X*, *active by default on Y*, *family of Z*, *triggers
  on @-mention / path / keyword*. Skip cues that do not apply.

The "capability + integration cues" shape matches what every existing
Octopus skill uses (see `debug`, `implement`, `audit-money`,
`compress-skill`, `plan-backlog`, `doc-lifecycle`). A "Use when …"
trigger sentence is fine but not required — pick the form that
expresses the routing signal best.

For skills that engage automatically on file paths or keywords, also
add a `triggers:` frontmatter field. Examples in the codebase:
`audit-money` (keywords), `compress-skill` (paths), `plan-backlog`
(paths). The `triggers:` field is the precise way to express
auto-engagement; description prose is the human-readable summary.

### Bad description

> "Helps with documents."

Why it fails: doesn't differentiate from any other doc-related skill;
no integration cue; no capability boundary.

### Good description

> "Pre-merge audit of money-touching code. Given a branch or PR,
> inspects numeric types, rounding, tests for non-round cents,
> env-var consistency, payment idempotency, webhook signature
> verification, and fee disclosure coupling. Produces a
> severity-tiered report (block / warn / info)."

Why it works: names the capability (pre-merge audit), the inputs
(branch or PR), the inspections (concrete list — the agent knows
what triggers this), and the output shape (severity-tiered report).
This is the actual `audit-money` description in the codebase.

## Review Checklist

Before closing a `scaffold-skill` session, confirm:

- [ ] Frontmatter present with `name` and `description`
- [ ] Description has capability + integration cues (pairs / active
      by default / family / triggers / "Use when") — at least one
      routing signal
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

> "Pre-commit audit of staged changes for PII leaks — emails,
> document numbers, phone numbers, names — using project-configured
> rules. Active by default on every pre-commit task; pairs with
> audit-security (broader secrets/auth audit) and composes with
> audit-all (pre-merge composer)."

Concrete capability, concrete integration cues, references project
config — agent can decide invocation without reading the body. The
shape mirrors `debug` and `audit-money` from the existing codebase.

For path/keyword-based engagement, add `triggers:` to the
frontmatter:

```yaml
triggers:
  paths: ["**/*.csv", "**/seed*.{ts,sql}"]
  keywords: ["email", "cpf", "ssn", "address"]
```
