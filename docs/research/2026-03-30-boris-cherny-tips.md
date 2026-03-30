# Research: Boris Cherny Tips

**Date:** 2026-03-30
**Trigger:** Compare Boris Cherny's 57 tips (creator of Claude Code) against what Octopus already supports, to identify gaps and prioritize improvements in the framework.

## Context

Boris Cherny published 57 workflow tips across 8 threads (Jan–Mar 2026) at howborisusesclaudecode.com. Octopus already implements several of the recommended practices, but does not expose all of them as configuration options in the `.octopus.yml` manifest or in the CLAUDE.md template.

The analysis compares the current state of Octopus (v0.6.0) against the full list of tips (parts 1–8, up to 26/03/2026).

## Analysis

### What Octopus already covers

| Tip | Boris Section | How Octopus covers it |
|-----|---------------|-----------------------|
| 7 | Hooks | PostToolUse auto-format, typecheck, console-log-warn; PreCompact save-state; Stop hooks |
| 6 | Subagents | `agents:` in the manifest |
| 9 | MCP | `mcp:` in the manifest |
| 5 | Skills/Commands | `skills:` in the manifest |
| 4 | CLAUDE.md | Template with `{{RULES}}` and `{{SKILLS}}` |
| 15 | Learning/Knowledge | `knowledge:` in the manifest |
| 29 | /simplify | `simplify` skill exists |
| 31 | /loop | `loop` skill exists |
| 43 | /schedule | `schedule` skill exists |

### Identified gaps

`setup.sh` does not process any of the fields related to Boris's tips (permissions, effortLevel, sandbox, autoMode, outputStyle, memory). `hooks/hooks.json` has no PostCompact. The template `agents/claude/CLAUDE.md` has a `## Claude-Specific Behavior` section that is empty (only a TODO comment).

All 13 gaps from the previous analysis remain pending. Two new ones were added (auto mode, /batch) and one item was expanded (auto-memory → memory + dream).

### New gaps from Parts 5–8 (Feb–Mar 2026)

- **Tip 30 — /batch**: fan-out of agents with worktree isolation for parallel migrations
- **Tip 42 — Auto mode**: AI classifiers that auto-approve safe permissions (`permissionMode: auto`)
- **Tip 45 — Auto-dream**: subagent that consolidates and cleans up memory periodically (extension of auto-memory)

## Identified Items

| ID | Title | Priority | Effort |
|----|-------|----------|--------|
| RM-001 | Pre-approved permissions in the manifest | 🔴 High | low |
| RM-002 | PostCompact hook | 🔴 High | trivial |
| RM-003 | Claude-Specific Behavior in CLAUDE.md | 🔴 High | trivial |
| RM-004 | Effort Level in the manifest | 🟡 Medium | trivial |
| RM-005 | Worktree isolation in agents | 🟡 Medium | low |
| RM-006 | Auto mode in the manifest | 🟡 Medium | trivial |
| RM-007 | Auto-memory and auto-dream in the manifest | 🟡 Medium | low |
| RM-008 | Sandboxing in the manifest | 🟡 Medium | low |
| RM-009 | Output styles in the manifest | 🟢 Low | trivial |
| RM-010 | GitHub Action in the manifest | 🟢 Low | medium |
| RM-011 | /batch skill | 🟢 Low | high |

## Discarded Items

| Title | Reason |
|-------|--------|
| Plugins in the manifest | Depends on the evolution of CC's plugin system — premature |
| Default statusline | Too personal per developer, does not make sense to standardize in the manifest |
| Spinner verbs | Too cosmetic to be a roadmap item |
