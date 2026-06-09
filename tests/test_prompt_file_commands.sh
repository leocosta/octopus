#!/usr/bin/env bash
# tests/test_prompt_file_commands.sh — RM-156: workflow commands delivered to
# Copilot as IDE prompt files (.github/prompts/*.prompt.md).
#
# Capability-gated (ADR-011): an agent renders prompt files only when its manifest
# declares `native_prompt_files: true`. The single source stays commands/*.md.
#
# NOTE: no `set -u` — load_manifest (like the production setup.sh) relies on
# BASH_REMATCH being unset on a non-match, which `set -u` turns into a fatal error.
set -o pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only
# setup.sh enables `set -euo pipefail`; this test counts pass/fail instead of
# exiting on the first miss, so relax those inherited flags.
set +e +u

PASS=0; FAIL=0
ok()   { echo "PASS: $1"; PASS=$((PASS+1)); }
bad()  { echo "FAIL: $1"; FAIL=$((FAIL+1)); }

OCTOPUS_DIR="$SCRIPT_DIR"
OCTOPUS_WORKFLOW=true
declare -a OCTOPUS_CMD_NAMES=() OCTOPUS_CMD_DESCS=() OCTOPUS_CMD_RUNS=()
declare -A OCTOPUS_AGENT_OUTPUT=()

# --- Copilot: native_prompt_files true → prompt files generated ---------------
TMP_CP=$(mktemp -d); PROJECT_ROOT="$TMP_CP"
load_manifest "copilot"
deliver_commands "copilot"

PF="$TMP_CP/.github/prompts/octopus-pr-open.prompt.md"
if [[ -f "$PF" ]]; then ok "copilot: octopus-pr-open.prompt.md generated"
else bad "copilot: octopus-pr-open.prompt.md generated"; fi

if [[ -f "$PF" ]]; then
  grep -qE '^(name|cli):' "$PF" && bad "copilot: name:/cli: frontmatter stripped" \
                                || ok "copilot: name:/cli: frontmatter stripped"
  grep -qE '^mode:[[:space:]]*agent$' "$PF" && ok "copilot: mode: agent set" \
                                            || bad "copilot: mode: agent set"
  grep -qE '^description:' "$PF" && ok "copilot: description carried over" \
                                 || bad "copilot: description carried over"
  # a $ARGUMENTS-using command must have it translated, with none left behind
  DA="$TMP_CP/.github/prompts/octopus-doc-adr.prompt.md"
  if grep -qF '${input}' "$DA" && ! grep -qF '$ARGUMENTS' "$DA"; then
    ok 'copilot: $ARGUMENTS translated to ${input}'
  else
    bad 'copilot: $ARGUMENTS translated to ${input}'
  fi
fi

# --- Claude: native_commands true (no prompt files) --------------------------
TMP_CL=$(mktemp -d); PROJECT_ROOT="$TMP_CL"
load_manifest "claude"
deliver_commands "claude"
if [[ -d "$TMP_CL/.github/prompts" ]]; then
  bad "claude: no .github/prompts produced (native_commands path)"
else
  ok "claude: no .github/prompts produced (native_commands path)"
fi

rm -rf "$TMP_CP" "$TMP_CL"
echo "--------------------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ $FAIL -eq 0 ]]
