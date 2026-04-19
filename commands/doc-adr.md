---
name: doc-adr
description: Create a new ADR with auto-incrementing number
---

---
description: Create a new Architecture Decision Record from the Octopus template
agent: code
---

# /octopus:doc-adr

## Purpose

Bootstrap a new Architecture Decision Record (ADR) from the Octopus template.
Use this whenever you make a non-trivial technical decision during any phase
of development.

## Usage

```
/octopus:doc-adr [slug]
```

If no slug is provided, ask the user to describe the decision in a few words.

## Instructions

1. Determine the slug:
   - If `$ARGUMENTS` contains a slug, use it (convert to kebab-case if needed)
   - Otherwise, ask the user: "What decision are you documenting? (e.g. use-postgresql, parser-strategy)"

2. Determine the next ADR number:
   ```bash
   mkdir -p docs/adrs
   ```
   - List existing ADR files: `ls docs/adrs/[0-9]*.md 2>/dev/null`
   - Find the highest number prefix
   - Increment by 1, zero-padded to 3 digits (001, 002, etc.)
   - If no ADRs exist yet, start at 001

3. Set variables:
   - `NUMBER`: the zero-padded number (e.g. "007")
   - `DATE`: today's date in YYYY-MM-DD format
   - `SLUG`: the kebab-case slug
   - `TARGET`: `docs/adrs/${NUMBER}-${SLUG}.md`

4. Read the template from `octopus/templates/adr.md`

5. Replace placeholders:
   - `{{NUMBER}}` → actual number
   - `{{DATE}}` → actual date
   - `{{SLUG}}` → actual slug (in Title Case for the heading)

6. Write the result to `$TARGET`

7. Report to the user:
   - File created at `$TARGET`
   - Show the ADR number: "ADR-${NUMBER}"
   - Remind them to fill in Context, Decision, and Consequences
   - If there's a spec in `docs/specs/`, suggest linking the ADR to the relevant spec section
