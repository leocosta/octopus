# Roadmap

This file is the project backlog. Items are added via `/octopus:doc-research`
and graduate to a Spec or RFC when work begins.

When creating a Spec or RFC for an item, update its status to "in progress"
and add a link to the created document.

---

## Backlog

### RM-006 — Add `tools:` field to role frontmatter

- **Priority:** 🟡 Medium
- **Effort:** low (<1d)
- **Status:** proposed
- **Added:** 2026-04-04
- **Research:** [claude-agents-support](research/2026-04-04-claude-agents-support.md)

Role files should be able to declare `tools:` in their YAML frontmatter to restrict
which tools a Claude Code agent can use (e.g., a social-media agent doesn't need Bash
access). This field is Claude Code-specific and must be stripped for non-Claude agents:
`normalize_role_frontmatter_for_agent()` in `setup.sh` must remove `tools:` for OpenCode
(and any future native agent that doesn't support it). Inline delivery (Copilot, Codex,
Antigravity) already strips all frontmatter via `strip_frontmatter`, so no change needed
there.

**Rationale:** Improves agent isolation and security. Without `tools:` restriction, a
role like social-media has access to all tools (Bash, Write, etc.) even though it only
needs to read project files and draft content. Declaring `tools:` makes the agent's
capabilities explicit and auditable.

---

## In Progress

| ID | Title | Resolution | Date |
|----|-------|------------|------|
| RM-005 | Language rules — behavioral detection + per-project override | in progress → [Spec](specs/language-rules.md) | 2026-03-30 |

---

## Completed / Rejected

| ID | Title | Resolution | Date |
|----|-------|------------|------|
| RM-001 | Pre-approved permissions in the manifest | completed → [Spec](specs/permissions-manifest.md) | 2026-03-30 |
