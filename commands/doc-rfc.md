---
name: doc-rfc
description: Create a new RFC from template with project context
---

---
description: Create a new RFC document from the Octopus template
agent: code
---

# /octopus:doc-rfc

## Purpose

Bootstrap a new RFC (Request for Comments) document from the Octopus template.
Use this when a feature requires consensus from multiple stakeholders before
detailed design work begins.

## Usage

```
/octopus:doc-rfc [slug]
```

If no slug is provided, ask the user for a short descriptive name (kebab-case).

## Instructions

1. Determine the slug:
   - If `$ARGUMENTS` contains a slug, use it (convert to kebab-case if needed)
   - Otherwise, ask the user: "What's a short name for this RFC? (e.g. knowledge-modules)"

2. Set variables:
   - `DATE`: today's date in YYYY-MM-DD format
   - `SLUG`: the kebab-case slug
   - `TARGET`: `docs/rfcs/${DATE}-${SLUG}.md`

3. Create the directory if it doesn't exist:
   ```bash
   mkdir -p docs/rfcs
   ```

4. Read the template from `octopus/templates/rfc.md`

5. Replace placeholders:
   - `{{DATE}}` → actual date
   - `{{SLUG}}` → actual slug (in Title Case for the heading)

6. Write the result to `$TARGET`

7. Report to the user:
   - File created at `$TARGET`
   - Remind them to fill in the sections and share with stakeholders
   - Suggest: "After the RFC is approved, create a spec with `/octopus:doc-spec`"
