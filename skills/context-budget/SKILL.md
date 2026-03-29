---
name: context-budget
description: Audit and optimize AI agent context window usage to reduce token overhead and improve response quality
---

# Context Budget Optimization

## When to Use

- Agent responses are degrading in quality (sign of context window pressure)
- Adding new rules, skills, or agent instructions
- Periodic maintenance of AI agent configurations
- CLAUDE.md or agent files have grown beyond 300 lines combined

## Audit Framework

### 1. Inventory All Context Sources

Categorize everything that loads into the agent's context:

| Category | Source | Always Loaded? |
|----------|--------|----------------|
| Instructions | CLAUDE.md, AGENTS.md | Yes |
| Rules | .claude/rules/**/*.md | Yes (per-session) |
| Skills | .claude/skills/**/SKILL.md | On activation |
| Agents/Roles | .claude/agents/*.md | On invocation |
| Commands | .claude/commands/*.md | On invocation |
| MCP configs | settings.json mcpServers | Yes |
| Project context | knowledge/ modules | Via roles |

### 2. Measure Each Component

Estimate token count (rough: 1 token ~ 4 characters):

- Count lines and characters for each file
- Flag files exceeding thresholds:
  - Rules: > 100 lines per file
  - Skills: > 400 lines per SKILL.md
  - Agent descriptions: > 200 lines
  - CLAUDE.md: > 300 lines
  - Project context: > 500 lines

### 3. Identify Optimization Targets

Look for:

- **Redundancy** — same guidance repeated across rules files
- **Over-specification** — rules that state obvious language conventions
- **Stale content** — rules for patterns no longer used in the codebase
- **Verbose examples** — code examples that could be shorter without losing clarity
- **TODO placeholders** — skeleton content adding zero value

### 4. Optimization Strategies

**Reduce always-loaded content:**
- Move rarely-needed guidance from rules to skills (loaded on demand)
- Trim code examples to minimum viable illustration
- Remove TODO stubs and placeholder sections

**Consolidate:**
- Merge overlapping rules across files
- Deduplicate content between common/ and language-specific rules

**Restructure:**
- Split large files into focused smaller files (rules system supports this)
- Move project-specific context to knowledge/ modules (only loaded via roles)

## Output Format

After auditing, produce a summary:

```
Context Budget Report
=====================
Total estimated tokens: X,XXX
  - Rules (always loaded): X,XXX
  - Skills (on demand): X,XXX
  - Instructions (CLAUDE.md): X,XXX
  - Other: X,XXX

Issues found: N
  [HIGH] rules/common/patterns.md: 156 lines (threshold: 100)
  [MED]  Redundant security guidance in common/ and csharp/
  [LOW]  TODO placeholder in rules/python/architecture.md

Recommendations:
  1. ...
  2. ...
```
