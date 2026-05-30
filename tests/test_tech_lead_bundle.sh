#!/usr/bin/env bash
# tests/test_tech_lead_bundle.sh
# Structural tests for the tech-lead bundle (RM-096) — the manager kit.
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="$OCTOPUS_DIR/bundles/tech-lead.yml"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- the bundle file ----------------------------------------------------
check "tech-lead.yml exists" test -f "$B"
check "name is tech-lead" grep -q "name: tech-lead" "$B"
check "category intent" grep -q "category: intent" "$B"
check "has a persona_question" grep -q "persona_question:" "$B"
check "persona_default false (opt-in)" grep -q "persona_default: false" "$B"

# --- members: skills ----------------------------------------------------
for s in standards onboarding definition-of-done continuous-learning audit-fleet fleet-bootstrap; do
  check "lists skill $s" grep -qE "^[[:space:]]*-[[:space:]]*$s([[:space:]]|$|#)" "$B"
done

# --- members: roles -----------------------------------------------------
for r in mentor architect security; do
  check "lists role $r" grep -qE "^[[:space:]]*-[[:space:]]*$r([[:space:]]|$|#)" "$B"
done

# --- no-loose convention: every listed member exists --------------------
for s in standards onboarding definition-of-done continuous-learning audit-fleet fleet-bootstrap; do
  check "member skill $s exists" test -f "$OCTOPUS_DIR/skills/$s/SKILL.md"
done
for r in mentor architect security; do
  check "member role $r exists" test -f "$OCTOPUS_DIR/roles/$r.md"
done

# --- baseline-smell fix: tech-lead is NOT in the fleet baseline ----------
check "fleet-bootstrap baseline bundles do not list tech-lead" \
  bash -c '! grep -qE "bundles:.*tech-lead" "'"$OCTOPUS_DIR"'/skills/fleet-bootstrap/SKILL.md"'

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
