#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CANONICAL="$SCRIPT_DIR/skills/_shared/task-routing.md"

echo "Test 1: canonical fragment exists"
[[ -f "$CANONICAL" ]] || { echo "FAIL: $CANONICAL not found"; exit 1; }
echo "PASS: canonical present"

echo "Test 2: canonical contains the four matrix headings"
for heading in \
  "Stack / language signals" \
  "Domain-audit signals" \
  "Cross-workflow signals" \
  "Risk-profile signals"
do
  grep -qF "$heading" "$CANONICAL" \
    || { echo "FAIL: canonical missing '$heading'"; exit 1; }
done
echo "PASS: canonical structure valid"

extract_block() {
  awk '/<!-- BEGIN task-routing -->/{flag=1; next} /<!-- END task-routing -->/{flag=0} flag' "$1"
}

echo "Test 3: each starter workflow skill embeds the canonical block"
canonical_body="$(extract_block "$CANONICAL")"
[[ -n "$canonical_body" ]] || { echo "FAIL: canonical body is empty"; exit 1; }
for f in \
  "$SCRIPT_DIR/skills/implement/SKILL.md" \
  "$SCRIPT_DIR/skills/debugging/SKILL.md" \
  "$SCRIPT_DIR/skills/receiving-code-review/SKILL.md"
do
  skill_body="$(extract_block "$f")"
  if [[ "$skill_body" != "$canonical_body" ]]; then
    echo "FAIL: $f task-routing body drifted from canonical"
    diff <(printf '%s\n' "$canonical_body") <(printf '%s\n' "$skill_body") | head -20
    exit 1
  fi
done
echo "PASS: three skills synced with canonical"

echo "Test 4: the RM-034 placeholder string is gone from all three skills"
for f in \
  "$SCRIPT_DIR/skills/implement/SKILL.md" \
  "$SCRIPT_DIR/skills/debugging/SKILL.md" \
  "$SCRIPT_DIR/skills/receiving-code-review/SKILL.md"
do
  if grep -q "RM-034 will replace this paragraph" "$f"; then
    echo "FAIL: $f still contains the v1 RM-034 stub"
    exit 1
  fi
done
echo "PASS: stub replaced in all three skills"

echo ""
echo "All task-routing sync tests passed."
