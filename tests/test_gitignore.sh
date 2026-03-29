#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"

OCTOPUS_AGENTS=(claude copilot codex)
declare -A OCTOPUS_AGENT_OUTPUT=()

update_gitignore

[[ -f "$TMPDIR/.gitignore" ]] || { echo "FAIL: .gitignore not created"; exit 1; }
grep -q ".claude/CLAUDE.md" "$TMPDIR/.gitignore" || { echo "FAIL: missing .claude/CLAUDE.md"; exit 1; }
grep -q ".claude/settings.json" "$TMPDIR/.gitignore" || { echo "FAIL: missing .claude/settings.json"; exit 1; }
grep -q ".github/copilot-instructions.md" "$TMPDIR/.gitignore" || { echo "FAIL: missing copilot"; exit 1; }
grep -q "AGENTS.md" "$TMPDIR/.gitignore" || { echo "FAIL: missing AGENTS.md"; exit 1; }
grep -q ".env.octopus" "$TMPDIR/.gitignore" || { echo "FAIL: missing .env.octopus"; exit 1; }

# Test idempotency — run again, should not duplicate entries
update_gitignore
count=$(grep -c ".claude/CLAUDE.md" "$TMPDIR/.gitignore")
[[ "$count" -eq 1 ]] || { echo "FAIL: duplicate entries in .gitignore (count=$count)"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: gitignore management tests passed"
