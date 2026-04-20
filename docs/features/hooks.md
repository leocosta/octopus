# Hooks

Lifecycle hooks that automate quality enforcement for Claude Code. Other agents receive equivalent quality rules inlined from `rules/common/quality.md`.

## Available hooks

| Hook | Phase | What it does |
|---|---|---|
| `block-no-verify` | PreToolUse | Blocks `--no-verify` in git commands |
| `detect-secrets` | PreToolUse | Warns about hardcoded secrets |
| `destructive-guard` | PreToolUse / Bash | Blocks `rm -rf`, `git push --force`, `DROP TABLE`, `DELETE FROM` without `WHERE`, etc. Bypass via `# destructive-guard-ok: <reason>` marker. Opt-out via `destructiveGuard: false`. See [destructive-action-guard.md](destructive-action-guard.md). |
| `git-push-reminder` | PreToolUse | Reminds to review before pushing |
| `format-check` | PreToolUse | Checks formatting on file writes |
| `auto-format` | PostToolUse | Auto-formats edited files |
| `typecheck` | PostToolUse | Runs type checking after edits |
| `console-log-warn` | PostToolUse | Warns about debug statements |
| `mcp-health` | PostToolUseFailure | Checks MCP server health on failure |
| `save-state` | PreCompact | Saves session state before compacting |
| `load-context` | SessionStart | Loads project context on session start |
| `console-log-check` | Stop | Final check for debug statements |
| `session-end` | Stop | Session cleanup |
| `lifecycle-marker` | SessionEnd | Marks session lifecycle events |

## How it works

1. Enable in `.octopus.yml`:
   ```yaml
   hooks: true
   ```
2. Run `octopus setup`
3. Hooks are injected into `.claude/settings.json`

## Disable specific hooks

```bash
OCTOPUS_DISABLED_HOOKS=auto-format,typecheck octopus setup
```
