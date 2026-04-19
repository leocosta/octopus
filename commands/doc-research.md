---
name: doc-research
description: Conduct an interactive brainstorming session and capture results as a research document + roadmap items
---

---
description: Conduct an interactive brainstorming session and capture results as a research document and roadmap items
agent: code
---

# /octopus:doc-research

## Purpose

Conduct a structured, agent-led brainstorming session on a topic and produce:
1. A research document (`docs/research/YYYY-MM-DD-<slug>.md`) capturing the full analysis
2. New items added to the project backlog (`docs/roadmap.md`)

Use this when you want to explore gaps, improvement opportunities, technical debt,
strategic options, or any topic that may generate future work items.

## Usage

```
/octopus:doc-research [slug]
```

If no slug is provided, ask the user for a short descriptive name (kebab-case).

## Instructions

### Step 1: Setup

1. Determine the slug:
   - If `$ARGUMENTS` contains a slug, use it (convert to kebab-case if needed)
   - Otherwise, ask: "What topic should we explore? (e.g. auth-improvements, api-performance)"

2. Set variables:
   - `DATE`: today's date in YYYY-MM-DD format
   - `SLUG`: the kebab-case slug
   - `RESEARCH_FILE`: `docs/research/${DATE}-${SLUG}.md`
   - `ROADMAP_FILE`: `docs/roadmap.md`

3. Create the directory:
   ```bash
   mkdir -p docs/research
   ```

### Step 2: Context Scan

Read the following before asking any questions:
- `docs/roadmap.md` — existing backlog items (to avoid duplicates)
- Recent commits: `git log --oneline -20`
- `knowledge/` — any relevant knowledge domains (check `knowledge/INDEX.md` if present)

If GitHub MCP is available, check open issues for related context.

Report briefly what you found: "I've scanned the existing roadmap (N open items), recent
commits, and knowledge base. Now let's explore [topic]."

### Step 3: Exploration

Ask directed questions **one at a time** to understand the topic.

Start with the trigger:
> "What prompted this research session?"
> (e.g. gap analysis, retrospective, pain point, external reference, team discussion)

Then explore based on the answers. Examples:
- "What's working well in this area that we should preserve?"
- "What's the biggest friction point right now?"
- "Are there external references (tools, patterns, industry practices) that inspired this?"
- "Who is affected most by the current situation?"

You may read project files as needed to ground your questions in the actual codebase.

Continue until you have enough context to propose concrete, actionable improvement items.

### Step 4: Item Generation

Propose candidate roadmap items. For each item:

- **Title**: Action-oriented, specific (e.g. "Add permissions pre-approval to manifest")
- **Priority**:
  - 🔴 High — high impact, blocks key workflows, or significant productivity gain
  - 🟡 Medium — clear value, not immediately urgent
  - 🟢 Low — nice to have, low friction to live without
- **Effort**: trivial (<1h) / low (<1d) / medium (<1w) / high (>1w)
- **Rationale**: 2-4 sentences explaining the value and why it matters

Present all candidates together and ask the user to:
- Confirm items to include
- Adjust priorities or effort estimates
- Add any missing items
- Mark items to reject (and capture the reason)

### Step 5: Assign IDs

1. Read `docs/roadmap.md` to find the last used ID (e.g. `RM-007`)
2. Assign sequential IDs to the approved new items (`RM-008`, `RM-009`, ...)
3. If no roadmap exists yet, start from `RM-001`

### Step 6: Write Outputs

**a) Create the research document** at `docs/research/${DATE}-${SLUG}.md`:

Use the template at `octopus/templates/research.md` if it exists. Fill in the
analysis, validated items table, and any discarded items with their reasons.

**b) Update the roadmap** at `docs/roadmap.md`:

If the file doesn't exist, initialize it from `octopus/templates/roadmap.md`.

Add new items to the **Backlog** section. Do NOT modify or remove existing items.
Each new item block:

```markdown
### RM-NNN — Title

- **Priority:** 🔴/🟡/🟢 Priority
- **Effort:** effort
- **Status:** proposed
- **Added:** DATE
- **Research:** [SLUG](research/DATE-SLUG.md)

Description of the item.

**Rationale:** Why this matters and the context that led to this idea.

---
```

### Step 7: Report

Tell the user:
- Research document created at `docs/research/${DATE}-${SLUG}.md`
- N items added to `docs/roadmap.md` (list them with IDs and priorities)
- Suggest next step: "When you're ready to work on an item, use `/octopus:doc-spec`
  or `/octopus:doc-rfc` and reference the item ID (e.g. RM-001)"
