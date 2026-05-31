#!/usr/bin/env bash
# tests/test_consigliere_role.sh
# Structural tests for the consigliere role (RM-101). Grep-based, per convention.
set -euo pipefail
OCTOPUS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
R="$OCTOPUS_DIR/roles/consigliere.md"
PASS=0; FAIL=0

check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then
    echo "PASS: $desc"; PASS=$((PASS + 1))
  else
    echo "FAIL: $desc"; FAIL=$((FAIL + 1))
  fi
}

# --- exists + frontmatter -----------------------------------------------
check "consigliere role file exists" test -f "$R"
check "frontmatter name is consigliere" grep -q "^name: consigliere$" "$R"
check "frontmatter has description" grep -q "^description:" "$R"
check "frontmatter has model" grep -q "^model:" "$R"
check "frontmatter has color" grep -q "^color:" "$R"
check "uses the PROJECT_CONTEXT placeholder" grep -q "{{PROJECT_CONTEXT}}" "$R"

# --- the persona's defining traits --------------------------------------
check "framed as a chief-of-staff / consigliere persona" \
  grep -qiE "chief.of.staff|consigliere" "$R"
check "strict grounding — never assert what is not in a source" \
  grep -qiE "never (assert|invent)|only what is (explicit|in)|not in (a |the )?(source|snapshot)" "$R"
check "reuses audit-grounding discipline" grep -qi "audit-grounding" "$R"
check "surfaces political risk" grep -qiE "political risk|risco político" "$R"
check "applies heuristics push and pull" grep -qiE "push.*pull|pull.*push|proactiv|when asked" "$R"
check "consults the playbook / people heuristics" grep -qiE "playbook|people/" "$R"
check "proposes capturing heuristics (feeds playbook-review)" grep -qiE "playbook-review|propose|capture" "$R"
check "advises, does not gate/execute (read-only by default)" \
  grep -qiE "read-only|advise|does not gate|no(t)? .*authority|never gates?" "$R"
check "honors the write-guard / private workspace" \
  grep -qiE "write-guard|consigliere.workspace|private" "$R"

# --- site docs: both locales --------------------------------------------
check "site doc (EN) exists" test -f "$OCTOPUS_DIR/docs/site/roles/consigliere.mdx"
check "site doc (pt-br) exists" test -f "$OCTOPUS_DIR/docs/site/pt-br/roles/consigliere.mdx"

# --- summary ------------------------------------------------------------
echo "-----------------------------------------"
echo "consigliere-role: $PASS passed, $FAIL failed"
[[ "$FAIL" -eq 0 ]]
