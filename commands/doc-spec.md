---
name: doc-spec
description: Create a new feature spec from template
---

---
description: Create a new feature specification from the Octopus template
agent: code
---

# /octopus:doc-spec

## Purpose

Bootstrap a new feature specification document from the Octopus template.
Use this for any non-trivial feature that needs a design before implementation.

## Usage

```
/octopus:doc-spec [slug]
```

If no slug is provided, ask the user for a short descriptive name (kebab-case).

## Instructions

1. Determine the slug:
   - If `$ARGUMENTS` contains a slug, use it (convert to kebab-case if needed)
   - Otherwise, ask the user: "What's a short name for this spec? (e.g. knowledge-modules)"

2. Set variables:
   - `SLUG`: the kebab-case slug
   - `TARGET`: `docs/specs/${SLUG}.md`

3. Create the directory if it doesn't exist:
   ```bash
   mkdir -p docs/specs
   ```

4. Check if an RFC exists for this feature:
   - Look for files matching `docs/rfcs/*-${SLUG}.md`
   - If found, note the RFC path to include in the spec's Metadata table

5. Read the template from `octopus/templates/spec.md`

6. Replace placeholders:
   - `{{SLUG}}` → actual slug (in Title Case for the heading)
   - If an RFC was found, fill in the RFC field in Metadata

7. Write the result to `$TARGET`

8. Report to the user:
   - File created at `$TARGET`
   - If an RFC was found: "Linked to RFC: docs/rfcs/..."
   - Remind them to fill in the design sections
   - Suggest: "The 'Context for Agents' section helps AI assistants understand what knowledge and skills are relevant for implementation"

9. Offer to continue into the design session:
   - Detect whether the current session is interactive. If
     stdin is not a TTY (e.g. the command was invoked by a
     script or another tool), skip this step silently.
   - Otherwise ask: `"Continue into the design session now? (y/N)"`.
   - On `y` (or `yes`), invoke `/octopus:doc-design ${SLUG}`.
   - On `N` or empty input, exit normally with the report from
     step 8.
