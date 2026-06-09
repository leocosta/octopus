#!/usr/bin/env bash
# tests/test_setup_agents.sh — RM-157: agent selection in `octopus setup`.
# Covers the non-interactive `--agents` flag (writes the chosen agents into
# .octopus.yml) and the picker's pure agent-row builder.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

# --- A: --agents writes the chosen set -------------------------------------
WORKDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$WORKDIR" OCTOPUS_SCOPE="repo" OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle starter --agents claude,copilot --dry-run 2>/dev/null || true
)
yml="$WORKDIR/.octopus.yml"
if grep -qE '^[[:space:]]+-[[:space:]]*claude$' "$yml" 2>/dev/null \
   && grep -qE '^[[:space:]]+-[[:space:]]*copilot$' "$yml" 2>/dev/null; then
  ok "--agents claude,copilot writes both agents"
else
  bad "--agents claude,copilot writes both agents"
fi
rm -rf "$WORKDIR"

# --- B: default (no --agents) stays claude-only ----------------------------
WORKDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$WORKDIR" OCTOPUS_SCOPE="repo" OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle starter --dry-run 2>/dev/null || true
)
yml="$WORKDIR/.octopus.yml"
if grep -qE '^[[:space:]]+-[[:space:]]*claude$' "$yml" 2>/dev/null \
   && ! grep -qE '^[[:space:]]+-[[:space:]]*copilot$' "$yml" 2>/dev/null; then
  ok "default agents = claude only"
else
  bad "default agents = claude only"
fi
rm -rf "$WORKDIR"

# --- C: picker agent rows (pure) -------------------------------------------
# _picker_agent_rows emits `a:<id><TAB>label<TAB>def<TAB>desc` (def 1=on, 0=off),
# matching the bundle/feature row contract. An agent in the current manifest
# defaults on; others off.
(
  export MANIFEST_PATH=/nonexistent OCTOPUS_DIR="$SCRIPT_DIR"
  source "$SCRIPT_DIR/cli/lib/setup-picker.sh" 2>/dev/null
  _CURRENT_AGENTS=(claude copilot)
  rows="$(_picker_agent_rows)"
  echo "$rows" | grep -qE '^a:copilot	' || exit 11
  echo "$rows" | grep -qE '^a:gemini	'  || exit 12
  echo "$rows" | awk -F'\t' '$1=="a:copilot" && $3=="1" {f=1} END{exit !f}' || exit 13
  echo "$rows" | awk -F'\t' '$1=="a:gemini"  && $3=="0" {f=1} END{exit !f}' || exit 14
) && ok "picker: _picker_agent_rows reflects current-state defaults" \
  || bad "picker: _picker_agent_rows reflects current-state defaults"

echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
