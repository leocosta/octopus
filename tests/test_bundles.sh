#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES_DIR="$SCRIPT_DIR/bundles"

echo "Test 1: all expected bundle files exist"
for name in starter quality-gates growth docs-discipline cross-stack dotnet-api node-api; do
  [[ -f "$BUNDLES_DIR/$name.yml" ]] \
    || { echo "FAIL: bundle $name.yml missing"; exit 1; }
done
echo "PASS: all seven bundles present"

echo "Test 2: every bundle has name/description/category"
for f in "$BUNDLES_DIR"/*.yml; do
  grep -q "^name: " "$f" || { echo "FAIL: $f missing 'name:'"; exit 1; }
  grep -q "^description: " "$f" || { echo "FAIL: $f missing 'description:'"; exit 1; }
  grep -qE "^category: (foundation|intent|stack)$" "$f" \
    || { echo "FAIL: $f missing valid 'category:'"; exit 1; }
done
echo "PASS: every bundle has required metadata"

echo "Test 3: intent and stack bundles all have persona_question"
for f in "$BUNDLES_DIR"/*.yml; do
  cat=$(awk '/^category: /{print $2; exit}' "$f")
  if [[ "$cat" == "intent" || "$cat" == "stack" ]]; then
    grep -q "^persona_question: " "$f" \
      || { echo "FAIL: $f ($cat) missing persona_question"; exit 1; }
  fi
done
echo "PASS: intent/stack bundles expose a persona question"

echo "All bundle structural tests passed!"

echo "Test 4: parse_octopus_yml accepts a bundles: list"

source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
cat > "$TMPDIR/test.yml" <<'EOF'
bundles:
  - starter
  - quality-gates
EOF

parse_octopus_yml "$TMPDIR/test.yml"

[[ ${#OCTOPUS_BUNDLES[@]} -eq 2 ]] \
  || { echo "FAIL: expected 2 bundles, got ${#OCTOPUS_BUNDLES[@]}"; exit 1; }
[[ "${OCTOPUS_BUNDLES[0]}" == "starter" ]] \
  || { echo "FAIL: first bundle wrong"; exit 1; }
[[ "${OCTOPUS_BUNDLES[1]}" == "quality-gates" ]] \
  || { echo "FAIL: second bundle wrong"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: parser reads bundles: list"

echo "Test 5: _load_bundle parses a single bundle YAML"

# Reset arrays to isolate this test
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()

_load_bundle "starter"

# starter contributes adr, feature-lifecycle, context-budget
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort > /tmp/got_skills.$$
printf '%s\n' adr feature-lifecycle context-budget | sort > /tmp/exp_skills.$$
diff -q /tmp/got_skills.$$ /tmp/exp_skills.$$ >/dev/null \
  || { echo "FAIL: starter did not populate skills correctly"; exit 1; }
rm -f /tmp/got_skills.$$ /tmp/exp_skills.$$

echo "PASS: _load_bundle populates OCTOPUS_SKILLS for starter"

echo "Test 6: _load_bundle on an unknown name aborts with message"

if ( _load_bundle "does-not-exist" ) 2>/tmp/err.$$ ; then
  echo "FAIL: _load_bundle should have errored on missing bundle"
  exit 1
fi
grep -q "unknown bundle" /tmp/err.$$ \
  || { echo "FAIL: error message should mention 'unknown bundle'"; rm -f /tmp/err.$$; exit 1; }
rm -f /tmp/err.$$
echo "PASS: _load_bundle fails loudly on missing bundle"

echo "Test 7: expand_bundles unions multiple bundles and de-duplicates"

OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=("starter" "quality-gates")

expand_bundles

expected_skills=(adr feature-lifecycle context-budget security-scan money-review tenant-scope-audit)
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort -u > /tmp/got.$$
printf '%s\n' "${expected_skills[@]}" | sort -u > /tmp/exp.$$
diff -q /tmp/got.$$ /tmp/exp.$$ >/dev/null \
  || { echo "FAIL: expand_bundles produced wrong skills"; cat /tmp/got.$$; rm -f /tmp/got.$$ /tmp/exp.$$; exit 1; }
rm -f /tmp/got.$$ /tmp/exp.$$

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^backend-specialist$" \
  || { echo "FAIL: backend-specialist role missing"; exit 1; }

echo "PASS: expand_bundles unions starter + quality-gates"

echo "Test 8: expand_bundles de-duplicates across bundles"

OCTOPUS_SKILLS=(existing-skill)
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=("quality-gates" "cross-stack")

expand_bundles

count=$(printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -c "^backend-specialist$" || true)
[[ "$count" -eq 1 ]] \
  || { echo "FAIL: backend-specialist duplicated ($count occurrences)"; exit 1; }

printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -q "^existing-skill$" \
  || { echo "FAIL: explicit skill was dropped by expand_bundles"; exit 1; }

echo "PASS: expand_bundles de-duplicates and preserves explicit entries"

echo "Test 9: bundles-only manifest expands to full component lists"

TMPDIR=$(mktemp -d)
cat > "$TMPDIR/.octopus.yml" <<'EOF'
agents:
  - claude

bundles:
  - starter
  - quality-gates

hooks: true
EOF

OCTOPUS_BUNDLES=()
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
OCTOPUS_RULES=()

parse_octopus_yml "$TMPDIR/.octopus.yml"
expand_bundles

# 3 (starter) + 3 (quality-gates) = 6 distinct skills
[[ ${#OCTOPUS_SKILLS[@]} -eq 6 ]] \
  || { echo "FAIL: expected 6 skills after bundle expansion, got ${#OCTOPUS_SKILLS[@]}"; exit 1; }

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^backend-specialist$" \
  || { echo "FAIL: backend-specialist role missing after expansion"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: bundles-only manifest expands to full component lists"
