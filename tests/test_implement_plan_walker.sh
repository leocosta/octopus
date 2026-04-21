#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_FILE="$SCRIPT_DIR/commands/implement.md"
ADR_DIR="$SCRIPT_DIR/docs/adr"

echo "Test 1: commands/implement.md documents --plan flag"
grep -q -- "--plan" "$CMD_FILE" \
  || { echo "FAIL: --plan flag missing from commands/implement.md"; exit 1; }
echo "PASS: --plan flag documented"

echo "Test 2: commands/implement.md documents --resume-from flag"
grep -q -- "--resume-from" "$CMD_FILE" \
  || { echo "FAIL: --resume-from flag missing"; exit 1; }
echo "PASS: --resume-from flag documented"

echo "Test 3: walker 4-step flow present"
for step in "Step 1 — Load plan" "Step 2 — Find starting task" "Step 3 — Main loop" "Step 4 — Completion"; do
  grep -q "$step" "$CMD_FILE" \
    || { echo "FAIL: walker step header '$step' missing"; exit 1; }
done
echo "PASS: walker 4-step flow documented"

echo "Test 4: review pause banner + prompt present"
grep -q "Task N complete" "$CMD_FILE" \
  || { echo "FAIL: 'Task N complete' banner anchor missing"; exit 1; }
grep -q "Continue / stop / redo-current" "$CMD_FILE" \
  || { echo "FAIL: 'Continue / stop / redo-current' prompt missing"; exit 1; }
echo "PASS: review pause documented"

echo "Test 5: HARD-GATE against push / PR / branch creation"
grep -q "HARD-GATE" "$CMD_FILE" \
  || { echo "FAIL: 'HARD-GATE' anchor missing"; exit 1; }
grep -qE "never pushes|never opens PRs|never creates branches" "$CMD_FILE" \
  || { echo "FAIL: walker HARD-GATE wording missing"; exit 1; }
echo "PASS: HARD-GATE documented"

echo "Test 6: ADR referenced from the command"
adr_path=$(ls "$ADR_DIR"/*-plan-walker-checkbox-commit.md 2>/dev/null | head -1 || true)
[[ -n "$adr_path" ]] || { echo "FAIL: plan-walker checkbox-commit ADR missing"; exit 1; }
adr_basename=$(basename "$adr_path")
grep -q "$adr_basename" "$CMD_FILE" \
  || { echo "FAIL: commands/implement.md does not link the ADR ($adr_basename)"; exit 1; }
echo "PASS: ADR linked"
