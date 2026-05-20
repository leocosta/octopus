# Octopus docs site — style guide

Lock this style before authoring Phase 2+. All pages under
`docs/site/` follow these conventions.

## Voice and tone

- **Audience:** developers who already use an AI coding agent
  (Claude Code, Codex, Copilot, Gemini, OpenCode) and are
  evaluating whether to adopt Octopus.
- **Tone:** second person, present tense, plain English. No
  marketing fluff, no superlatives, no exclamation points.
- **Style:** technical, precise, opinionated when the project is
  opinionated. Name the trade-off when there is one.
- **Forbidden phrases:** "leverage", "unlock", "empower", "next
  generation", "robust", "best-in-class", "seamless".

## Page anatomy (rationale layer)

Every rationale page under `docs/site/{bundles,skills,commands,hooks,roles}/`
opens with:

1. **One-paragraph "Why this exists"** — names the failure mode
   prevented or the workflow enabled. Lead with the *problem*,
   not the *solution*.
2. **At-a-glance card** — frontmatter fields rendered as a small
   summary block (bundle membership, lifecycle stage for hooks,
   priority/effort for new items).
3. **Body** — the entity-type-specific sections (see plan).
4. **Embedded canonical** — verbatim include of the source
   `SKILL.md` / command body / hook script.
5. **Cross-references** — bundles, sibling skills, ADRs.

## Cross-references

- Always link by **name**, not by URL. The site's resolver knows
  where each entity lives.
- Use code spans for entity names: `` `audit-config` ``,
  `` `/octopus:doc-prd` ``, `` `hooks/stop/propose-knowledge-update.sh` ``.
- For ADRs, prefer descriptive linking: "the ADR on plan-walker
  checkpoint commits" rather than "ADR-001".

## Code blocks

- Use Starlight's `<Code>` component for install snippets and
  multi-line shell commands so they get the "copy" button.
- Inline code spans for path fragments, file names, frontmatter
  keys.
- Always show real commands, never `<placeholder>` pseudocode. If
  a real example needs a placeholder, name it `<your-project>`
  with the angle brackets visible.

## Diagrams

- Use Mermaid (built into Starlight) only when prose would take
  more than three paragraphs to convey the same shape.
- Diagrams must have a one-sentence caption above them.
- Never use diagrams as decoration.

## Frontmatter

Every rationale page sets at least:

```yaml
---
title: <Entity name>
description: <one sentence — shows in search results and OG cards>
---
```

For skills, commands, hooks, bundles, roles, also include:

```yaml
sidebar:
  order: <int>  # within its family, lower is earlier
```

## When a section doesn't apply

Skip it. Better to have a short page that answers the questions
that exist than a long page with empty sections. Never write
"N/A" or "TBD" — delete the section.
