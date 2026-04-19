# Spec: `tools:` Field in Role Frontmatter

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-006 |
| **RFC** | N/A |

## Problem Statement

Role templates under `roles/` declare YAML frontmatter that is forwarded to each configured coding assistant. Claude Code supports a `tools:` frontmatter key that constrains the tool surface of a subagent (e.g., a social-media agent that only needs `Read`, `Write`, `WebSearch`, `WebFetch`). Without that key, a role inherits every tool available to the parent session, weakening isolation.

Other agents (OpenCode native delivery; Copilot/Codex/Antigravity inline delivery) do not understand `tools:` and break or surface it as user content when the key is forwarded verbatim. A single authoring surface must work across all supported agents: Claude keeps the field, every other target strips it.

## Goals

1. Allow role templates to declare `tools:` in their YAML frontmatter without breaking non-Claude agents.
2. Preserve `tools:` verbatim when delivering to Claude Code native agents.
3. Strip `tools:` for every non-Claude native delivery (OpenCode today, any future native target that does not support it).
4. Ensure inline-delivery agents (Copilot, Codex, Antigravity) never expose `tools:` — the whole frontmatter is already removed by `strip_frontmatter`.
5. Cover the behavior with automated tests so future frontmatter changes do not regress it.

## Non-Goals

- Do not validate the contents of the `tools:` list against Claude's canonical tool names (that is a Claude Code concern).
- Do not infer tool sets automatically from role descriptions.
- Do not introduce per-agent frontmatter overrides (one role template fits all agents).

## Design

### Authoring surface

Role templates opt into `tools:` by adding a list in their frontmatter:

```yaml
---
name: social-media
description: "..."
model: sonnet
color: "#C05621"
tools: [Read, Write, WebSearch, WebFetch]
---
```

The field is optional; roles that do not declare it continue to get the default Claude tool surface.

### Delivery paths

- **Claude (native, per-file):** `deliver_roles("claude")` pipes the template through `normalize_role_frontmatter_for_agent("claude")`, which short-circuits to `cat` and preserves the frontmatter exactly. The resulting file lands under `.claude/agents/<role>.md`.
- **OpenCode (native, per-file):** `normalize_role_frontmatter_for_agent("opencode")` walks the frontmatter line by line and drops any line matching `^tools:[[:space:]]`. `color:` normalization runs in the same pass.
- **Copilot / Codex / Antigravity (inline concatenation):** `deliver_roles` strips the frontmatter entirely via `strip_frontmatter` before concatenating into the agent's single instructions file, so `tools:` never appears.

### Reference implementation

- `setup.sh:1044` — `normalize_role_frontmatter_for_agent` contains the stripping logic (line 1070: `[[ "$line" =~ ^tools:[[:space:]] ]] && continue`).
- `setup.sh:997` — `strip_frontmatter` removes frontmatter entirely for inline delivery.
- `roles/social-media.md:6` — first role to use `tools:` in production.

## Backward Compatibility

- Roles without `tools:` continue to deliver unchanged across all agents.
- OpenCode/Claude outputs for existing roles (e.g., `product-manager`) are unaffected: the extra strip rule only matches lines prefixed with `tools:`.

## Context for Agents

**Knowledge modules**: N/A
**Implementing roles**: `social-media` (first consumer).
**Related ADRs**: N/A
**Skills needed**: N/A

## Testing Strategy

Covered by `tests/test_generate_roles.sh`:

- Test 4 — delivered Claude agent file for `social-media` contains `^tools:`.
- Test 5 — delivered OpenCode agent file for `social-media` does **not** contain `^tools:` and retains other frontmatter (`name:`).
- Test 6 — Copilot inline delivery (`.github/copilot-instructions.md`) does not contain `tools:` and still renders the role section header.

## Risks

- Future Claude-only frontmatter keys would need similar stripping rules; the current implementation adds them one-by-one inside `normalize_role_frontmatter_for_agent`. Mitigation: co-locate all Claude-specific stripping rules there so the pattern is discoverable.
- If a role template accidentally uses a nested/multiline `tools:` YAML structure, the regex-based strip only drops the first line. Mitigation: role templates document inline-list form (`tools: [Read, Write, ...]`); add a lint if this becomes a problem.

## Changelog

- **2026-04-18** — Initial spec capturing the already-implemented behavior (RM-006).
