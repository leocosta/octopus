# Destructive-Action Guard

A PreToolUse hook that blocks dangerous Bash commands before
the agent runs them — `rm -rf`, `git push --force`, `git reset
--hard`, `DROP TABLE`, `DELETE FROM ... ;` (without `WHERE`),
`chmod -R 777`, `find ... -delete`, `curl | bash`, and similar.

The hook activates automatically in every Octopus-managed repo
where `hooks: true` is set (the default for the `quality-gates`
bundle, and common in `starter`). No skill bundle membership
needed — hooks attach via `hooks: true`.

## Why

Claude Code's system prompt warns about destructive actions,
but other agents (Copilot, Codex, Gemini, OpenCode) don't have
that protection. Claude Code itself in `bypassPermissions`
mode also relaxes the safety nets. This hook is a uniform
layer below whatever permission mode is in play.

## How to bypass

When a destructive command is genuinely intended, add a
`# destructive-guard-ok: <reason>` marker to the command text:

```bash
rm -rf node_modules  # destructive-guard-ok: regenerated from package.json
```

The reason must be non-empty. The marker surfaces in command
history and code review, so the bypass is visible — unlike a
silent override.

## How to disable

For repos with stronger out-of-band protections, opt out via
`.octopus.yml`:

```yaml
hooks: true
destructiveGuard: false
```

When disabled the rest of the hooks layer is unaffected.

## Patterns blocked in v1

| Pattern | Why |
|---|---|
| `rm -rf` | Recursive force delete |
| `git push --force` / `-f` | Rewrites remote history |
| `git reset --hard` | Discards local changes |
| `git checkout --` | Discards uncommitted edits |
| `git clean -f` | Irreversibly removes untracked files |
| `DROP TABLE` | Destroys database table |
| `DROP DATABASE` | Destroys entire database |
| `TRUNCATE` | Empties database table |
| `DELETE FROM ... ;` (no `WHERE`) | Deletes every row |
| `chmod -R 777` | World-writable recursion |
| `find ... -delete` | Bulk deletion from find results |
| `npm uninstall -g` | Removes globally installed package |
| `curl ... \| bash` | Executes remote script unverified |

A legitimate `DELETE FROM sessions WHERE expired_at < now();`
is not blocked — the guard only trips when no `WHERE` clause is
present.

## Extending

Each pattern is a regex in
`hooks/pre-tool-use/destructive-guard.sh`. Adding a new pattern
is a one-line change to the `patterns=(…)` array with a new
test case in `tests/test_destructive_guard.sh`.

## Review before merging

The guard is a speed bump on accidental destruction, not a
sandbox. Creative agents can obfuscate commands (base64, piping
through `eval`, constructing via variables) and the guard will
not catch those. That's a known limitation; the value is
stopping the common careless case.
