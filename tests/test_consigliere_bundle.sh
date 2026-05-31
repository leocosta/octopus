#!/usr/bin/env bash
# tests/test_consigliere_bundle.sh
# Structural tests for the consigliere bundle (RM-099, ADR-008).
# Grep-based, per project convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
B="$OCTOPUS_DIR/bundles/consigliere.yml"
TL="$OCTOPUS_DIR/bundles/tech-lead.yml"
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
check "consigliere.yml exists" test -f "$B"
check "name is consigliere" grep -q "name: consigliere" "$B"
check "category intent" grep -q "category: intent" "$B"
check "has a persona_question" grep -q "persona_question:" "$B"
check "persona_default false (opt-in)" grep -q "persona_default: false" "$B"

# --- members: skills ----------------------------------------------------
check "lists skill consigliere-bootstrap" \
  grep -qE "^[[:space:]]*-[[:space:]]*consigliere-bootstrap([[:space:]]|$|#)" "$B"

# --- members: digest-source (RM-100) ------------------------------------
check "lists skill digest-source" \
  grep -qE "^[[:space:]]*-[[:space:]]*digest-source([[:space:]]|$|#)" "$B"

# --- members: context-status (RM-102) -----------------------------------
check "lists skill context-status" \
  grep -qE "^[[:space:]]*-[[:space:]]*context-status([[:space:]]|$|#)" "$B"

# --- members: playbook-review (RM-103) ----------------------------------
check "lists skill playbook-review" \
  grep -qE "^[[:space:]]*-[[:space:]]*playbook-review([[:space:]]|$|#)" "$B"

# --- members: roles (RM-101) --------------------------------------------
check "lists role consigliere" \
  grep -qE "^[[:space:]]*-[[:space:]]*consigliere([[:space:]]|$|#)" "$B"

# --- no-loose convention: every listed member exists --------------------
check "member skill consigliere-bootstrap exists" \
  test -f "$OCTOPUS_DIR/skills/consigliere-bootstrap/SKILL.md"
check "member skill digest-source exists" \
  test -f "$OCTOPUS_DIR/skills/digest-source/SKILL.md"
check "member skill context-status exists" \
  test -f "$OCTOPUS_DIR/skills/context-status/SKILL.md"
check "member skill playbook-review exists" \
  test -f "$OCTOPUS_DIR/skills/playbook-review/SKILL.md"
check "member role consigliere exists" \
  test -f "$OCTOPUS_DIR/roles/consigliere.md"

# --- ADR-008: separate from tech-lead -----------------------------------
check "tech-lead.yml does NOT list consigliere-bootstrap" \
  bash -c "! grep -qE '^[[:space:]]*-[[:space:]]*consigliere-bootstrap' '$TL'"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "consigliere-bundle: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
