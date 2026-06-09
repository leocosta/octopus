#!/usr/bin/env bash
# tests/test_cli_agent_commands.sh — RM-159: selected workflow commands delivered
# to the GitHub Copilot CLI as custom agents (.github/agents/octopus-*.agent.md).
#
# The selection is a manifest-side allowlist (the copilot manifest), so the
# canonical command source is untouched and Claude delivery is unaffected. CLI
# agents are ADDITIVE to the IDE prompt-files — a selected command gets both.
#
# NOTE: no `set -u` — load_manifest (like production setup.sh) relies on
# BASH_REMATCH being unset on a non-match, which `set -u` turns into a fatal error.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only
# setup.sh enables `set -euo pipefail`; this test counts pass/fail instead of
# exiting on the first miss, so relax those inherited flags.
set +e +u

PASS=0; FAIL=0
ok()  { echo "PASS: $1"; PASS=$((PASS+1)); }
bad() { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

OCTOPUS_DIR="$SCRIPT_DIR"
OCTOPUS_WORKFLOW=true
declare -a OCTOPUS_CMD_NAMES=() OCTOPUS_CMD_DESCS=() OCTOPUS_CMD_RUNS=()
declare -A OCTOPUS_AGENT_OUTPUT=()

# --- Copilot: selected commands become CLI agents ----------------------------
TMP_CP=$(mktemp -d); PROJECT_ROOT="$TMP_CP"
load_manifest "copilot"
deliver_commands "copilot"

AG="$TMP_CP/.github/agents/octopus-pr-open.agent.md"
if [[ -f "$AG" ]]; then ok "copilot: selected command pr-open → agent file"
else bad "copilot: selected command pr-open → agent file"; fi

if [[ -f "$AG" ]]; then
  grep -qE '^name:[[:space:]]*octopus-pr-open$' "$AG" \
    && ok "copilot: agent name set" || bad "copilot: agent name set"
  grep -qE '^description:' "$AG" \
    && ok "copilot: description carried over" || bad "copilot: description carried over"
  # Neither the Octopus source frontmatter (cli:) nor the IDE prompt-file
  # frontmatter (mode:) should leak into the agent file.
  grep -qE '^(cli|mode):' "$AG" \
    && bad "copilot: source/IDE frontmatter stripped" \
    || ok "copilot: source/IDE frontmatter stripped"
  # pr-open uses $ARGUMENTS — it must be translated out (no raw token left).
  grep -qF '$ARGUMENTS' "$AG" \
    && bad 'copilot: $ARGUMENTS translated out' \
    || ok 'copilot: $ARGUMENTS translated out'
fi

# A non-selected command (doc-adr) must NOT get an agent file — selective (option B).
if [[ -f "$TMP_CP/.github/agents/octopus-doc-adr.agent.md" ]]; then
  bad "copilot: non-selected doc-adr excluded from CLI agents"
else
  ok "copilot: non-selected doc-adr excluded from CLI agents"
fi

# CLI agents are additive — the IDE prompt-file for the same command still exists.
if [[ -f "$TMP_CP/.github/prompts/octopus-pr-open.prompt.md" ]]; then
  ok "copilot: IDE prompt-file still generated (additive)"
else
  bad "copilot: IDE prompt-file still generated (additive)"
fi

# --- Claude: isolation guarantee — no .github/agents produced ----------------
TMP_CL=$(mktemp -d); PROJECT_ROOT="$TMP_CL"
load_manifest "claude"
deliver_commands "claude"
if [[ -d "$TMP_CL/.github/agents" ]]; then
  bad "claude: no .github/agents produced (Claude delivery unaffected)"
else
  ok "claude: no .github/agents produced (Claude delivery unaffected)"
fi

rm -rf "$TMP_CP" "$TMP_CL"
echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
