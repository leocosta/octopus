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

# Temp-dir carve-out for `rm -rf`.
#
# A clean `rm -rf` whose every target RESOLVES strictly under /tmp or
# /var/tmp is allowed without a marker — this is throwaway scratch (mockups,
# snapshots) the agent generates constantly. The carve-out is deliberately
# strict; its invariant is: never exempt a command that could delete anything
# outside the temp root. Static string-matching cannot guarantee this (`.`,
# globs, and symlinks all resolve on the live filesystem), so the decision is
# made by a helper that (1) rejects all shell composition / expansion / glob
# metacharacters and path traversal, (2) parses the single `rm` invocation
# with shlex, and (3) resolves every target with realpath and confirms it
# lands strictly under a temp root and is not a reserved Octopus artifact
# (e.g. the context-handoff document at /tmp/octopus-handoff-*).
if printf '%s' "$command" | python3 -c '
import os, shlex, sys

cmd = sys.stdin.read()

# Reject shell composition, expansion, globbing, comments, traversal — none of
# which are statically confinable to /tmp.
if any(c in cmd for c in ";&|`$<>(){}*?[]#") or "\n" in cmd or ".." in cmd:
    sys.exit(1)

try:
    toks = shlex.split(cmd)
except ValueError:
    sys.exit(1)
if not toks or toks[0] != "rm":
    sys.exit(1)

targets, after_ddash = [], False
for t in toks[1:]:
    if not after_ddash and t == "--":
        after_ddash = True
    elif not after_ddash and t.startswith("-"):
        continue
    else:
        targets.append(t)
if not targets:
    sys.exit(1)

ROOTS = ("/tmp", "/var/tmp")
for t in targets:
    if not (t.startswith("/tmp/") or t.startswith("/var/tmp/")):
        sys.exit(1)
    rp = os.path.realpath(t)                 # resolves symlinks, "." and "/"
    if not any(rp == r or rp.startswith(r + "/") for r in ROOTS):
        sys.exit(1)
    if rp in ROOTS:                          # resolved to the bare temp root
        sys.exit(1)
    if os.path.basename(rp).startswith("octopus-"):
        sys.exit(1)                          # reserved Octopus artifact
sys.exit(0)
'; then
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
