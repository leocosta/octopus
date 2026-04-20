#!/usr/bin/env bash
set -euo pipefail

# Read the JSON payload Claude Code feeds to PreToolUse hooks.
payload="$(cat)"

# Extract the Bash command from tool_input.command. When the hook is
# invoked for a non-Bash tool the field is absent and we exit 0.
command="$(printf '%s' "$payload" \
  | python3 -c 'import json, sys; d=json.load(sys.stdin); print(d.get("tool_input", {}).get("command", ""))')"

[[ -z "$command" ]] && exit 0

# Bypass marker: any line containing
# `# destructive-guard-ok: <non-empty reason>` is accepted.
if printf '%s' "$command" | grep -qE '#[[:space:]]*destructive-guard-ok:[[:space:]]*[^[:space:]]+' ; then
  exit 0
fi

# Destructive pattern blocklist. Each entry is a description | regex
# pair; the description appears in the error message.
patterns=(
  'rm -rf (recursive force delete)|\brm[[:space:]]+(-[a-zA-Z]*r[a-zA-Z]*f|-[a-zA-Z]*f[a-zA-Z]*r)\b'
  'git push --force (rewrites remote history)|\bgit[[:space:]]+push[[:space:]]+(.*[[:space:]])?(--force|-f)\b'
  'git reset --hard (discards local changes)|\bgit[[:space:]]+reset[[:space:]]+(.*[[:space:]])?--hard\b'
  'git checkout -- (discards uncommitted edits)|\bgit[[:space:]]+checkout[[:space:]]+--([[:space:]]|$)'
  'git clean -f (irreversibly removes untracked files)|\bgit[[:space:]]+clean[[:space:]]+(-[a-zA-Z]*f[a-zA-Z]*|-[a-zA-Z]*f)\b'
  'DROP TABLE (destroys database table)|\bDROP[[:space:]]+TABLE\b'
  'DROP DATABASE (destroys entire database)|\bDROP[[:space:]]+DATABASE\b'
  'TRUNCATE (empties database table)|\bTRUNCATE\b'
  'DELETE FROM without WHERE (deletes every row)|\bDELETE[[:space:]]+FROM[[:space:]]+[A-Za-z0-9_."]+[[:space:]]*($|;|--)'
  'chmod -R 777 (world-writable recursion)|\bchmod[[:space:]]+(-[a-zA-Z]*R[a-zA-Z]*|-[a-zA-Z]*R)[[:space:]]+777\b'
  'find -delete (bulk deletion from find results)|\bfind[[:space:]]+.*[[:space:]]-delete\b'
  'npm uninstall -g (removes globally installed package)|\bnpm[[:space:]]+uninstall[[:space:]]+.*(-g|--global)\b'
  'curl | bash (executes remote script unverified)|\bcurl[[:space:]]+[^|]*\|[[:space:]]*(bash|sh|zsh)\b'
)

for entry in "${patterns[@]}"; do
  desc="${entry%%|*}"
  regex="${entry#*|}"
  if printf '%s' "$command" | grep -qE "$regex" ; then
    {
      printf 'octopus destructive-guard: blocked command\n'
      printf '  matched rule: %s\n' "$desc"
      printf '  bypass: add `# destructive-guard-ok: <reason>` to the command\n'
      printf '  e.g. `rm -rf node_modules  # destructive-guard-ok: regenerated from package.json`\n'
      printf '  off: set `destructiveGuard: false` in .octopus.yml\n'
    } >&2
    exit 2
  fi
done

exit 0
