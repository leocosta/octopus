#!/usr/bin/env bash
# tests/test_command_delegation.sh
# RM-129 — skill<->command consolidation guard.
#
# A command with a namesake skill must DELEGATE to it, not duplicate its
# procedure: the command is the slash entrypoint, the skill holds the logic.
# Most already do; this locks the pattern so a future edit can't reintroduce a
# fat, drifting command that duplicates its skill. Scoped to the families where
# the 1:1 delegation contract is clearest (audit-*, knowledge-*). Grep/exit-code
# assertions, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$SCRIPT_DIR"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@" &>/dev/null; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

for cmd in commands/audit-*.md commands/knowledge-*.md; do
  base="$(basename "$cmd" .md)"
  [[ -d "skills/$base" ]] || continue            # only families with a namesake skill
  # delegates: mentions the skill, and stays thin (no duplicated procedure body)
  check "$base command references its skill" grep -qiE 'skill|skills/' "$cmd"
  lines=$(wc -l < "$cmd")
  check "$base command stays a thin delegator (<=60 lines, got $lines)" test "$lines" -le 60
done

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
