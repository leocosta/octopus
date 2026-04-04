# Research: claude-agents-support

**Date:** 2026-04-04
**Trigger:** User noticed that Octopus workflow capabilities (dev-flow, pr-review, etc.) were
not appearing in Claude Code's `/agents` picker, and wanted them accessible there.

## Context

Claude Code's `/agents` dialog shows files placed in `.claude/agents/`. Octopus exposes
its workflow capabilities as **slash commands** (`.claude/commands/`) and its **roles**
(`.claude/agents/`). The user initially expected workflow commands to appear as agents;
after clarification, the goal became: ensure roles are first-class agents across all
supported Code Assistants.

**Current state of role delivery:**

| Platform | native_agents | Delivery | Target | Status |
|----------|--------------|----------|--------|--------|
| Claude   | true | file_per_role | `.claude/agents/` | ✅ works |
| OpenCode | true | file_per_role | `.opencode/agents/` | ✅ works |
| Copilot  | false | inline in main output | `.github/copilot-instructions.md` | ✅ works |
| Codex    | false | inline in main output | `AGENTS.md` | ✅ works |
| Antigravity | false | inline in main output | `ANTIGRAVITY.md` | ✅ works |

Both native and inline delivery paths exist in `setup.sh` (`deliver_roles()`) and are
covered by `tests/test_generate_roles.sh`.

**Identified gap:** Claude Code agent files support a `tools:` frontmatter field to
restrict which tools the agent can use. None of the existing Octopus roles declare it,
it is undocumented, and non-Claude platforms would receive it incorrectly if added
(OpenCode doesn't support it; inline delivery strips frontmatter already but the
normalization function doesn't handle it explicitly).

## Analysis

The `normalize_role_frontmatter_for_agent()` function in `setup.sh` currently:
- For Claude: passes everything through (`cat`) — `tools:` would be preserved ✅
- For OpenCode: normalizes `color:` to quoted lowercase — `tools:` would leak into the
  OpenCode agent file where it is unknown/ignored
- For non-native (inline): `strip_frontmatter` removes all frontmatter before appending —
  `tools:` never reaches the output ✅

The only gap is OpenCode: if a role declares `tools:`, it appears in
`.opencode/agents/<role>.md` as an unrecognized field. The fix is to strip `tools:`
inside the OpenCode normalization branch.

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-006 | Add `tools:` field to role frontmatter with normalization for non-Claude agents | 🟡 Medium | low |

## Discarded Items

| Title | Reason |
|-------|--------|
| Auto-discover all roles without .octopus.yml listing | User confirmed explicit listing is preferred |
| Commands as agents | User explicitly rejected; commands are slash-commands, roles are agents |
