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

expected_skills=(adr feature-lifecycle context-budget audit-all security-scan money-review tenant-scope-audit cross-stack-contract)
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
[[ ${#OCTOPUS_SKILLS[@]} -eq 8 ]] \
  || { echo "FAIL: expected 8 skills after bundle expansion, got ${#OCTOPUS_SKILLS[@]}"; exit 1; }

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^backend-specialist$" \
  || { echo "FAIL: backend-specialist role missing after expansion"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: bundles-only manifest expands to full component lists"

echo "Test 10: depends_on — happy path resolves dependency chain"

OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=()

FAKE=$(mktemp -d)
mkdir -p "$FAKE/skills/parent-skill" "$FAKE/skills/child-skill"
cat > "$FAKE/skills/parent-skill/SKILL.md" <<'EOF'
---
name: parent-skill
description: parent
---
# parent
EOF
cat > "$FAKE/skills/child-skill/SKILL.md" <<'EOF'
---
name: child-skill
description: child
depends_on:
  - parent-skill
---
# child
EOF

OCTOPUS_DIR_SAVED="$OCTOPUS_DIR"
OCTOPUS_DIR="$FAKE"
OCTOPUS_SKILLS=(child-skill)

_resolve_skill_dependencies

OCTOPUS_DIR="$OCTOPUS_DIR_SAVED"

printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -q "^parent-skill$" \
  || { echo "FAIL: parent-skill not pulled in via depends_on"; exit 1; }
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -q "^child-skill$" \
  || { echo "FAIL: child-skill dropped"; exit 1; }

rm -rf "$FAKE"
echo "PASS: depends_on resolves child → parent"

echo "Test 11: depends_on — missing dep warns and continues"

FAKE=$(mktemp -d)
mkdir -p "$FAKE/skills/orphan-skill"
cat > "$FAKE/skills/orphan-skill/SKILL.md" <<'EOF'
---
name: orphan-skill
description: orphan
depends_on:
  - does-not-exist
---
# orphan
EOF

OCTOPUS_DIR_SAVED="$OCTOPUS_DIR"
OCTOPUS_DIR="$FAKE"
OCTOPUS_SKILLS=(orphan-skill)

_resolve_skill_dependencies 2>/tmp/ra_warn.$$ || true

OCTOPUS_DIR="$OCTOPUS_DIR_SAVED"

grep -q "does-not-exist" /tmp/ra_warn.$$ \
  || { echo "FAIL: missing dep warning did not mention 'does-not-exist'"; rm -f /tmp/ra_warn.$$; rm -rf "$FAKE"; exit 1; }
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -q "^orphan-skill$" \
  || { echo "FAIL: orphan-skill was dropped when dep is missing"; exit 1; }

rm -f /tmp/ra_warn.$$
rm -rf "$FAKE"
echo "PASS: missing dep warns but keeps the parent"

echo "Test 12: depends_on — cycle is detected and aborts"

FAKE=$(mktemp -d)
mkdir -p "$FAKE/skills/a-skill" "$FAKE/skills/b-skill"
cat > "$FAKE/skills/a-skill/SKILL.md" <<'EOF'
---
name: a-skill
description: a
depends_on:
  - b-skill
---
EOF
cat > "$FAKE/skills/b-skill/SKILL.md" <<'EOF'
---
name: b-skill
description: b
depends_on:
  - a-skill
---
EOF

OCTOPUS_DIR_SAVED="$OCTOPUS_DIR"
OCTOPUS_DIR="$FAKE"
OCTOPUS_SKILLS=(a-skill)

if ( _resolve_skill_dependencies ) 2>/tmp/ra_cycle.$$ ; then
  echo "FAIL: cycle was not detected"
  rm -f /tmp/ra_cycle.$$; rm -rf "$FAKE"; exit 1
fi

OCTOPUS_DIR="$OCTOPUS_DIR_SAVED"

grep -q "cycle" /tmp/ra_cycle.$$ \
  || { echo "FAIL: cycle error message missing"; cat /tmp/ra_cycle.$$; rm -f /tmp/ra_cycle.$$; rm -rf "$FAKE"; exit 1; }

rm -f /tmp/ra_cycle.$$
rm -rf "$FAKE"
echo "PASS: cycle detected and aborts"

echo "Test 13: depends_on — skills without the field are untouched"

FAKE=$(mktemp -d)
mkdir -p "$FAKE/skills/plain-skill"
cat > "$FAKE/skills/plain-skill/SKILL.md" <<'EOF'
---
name: plain-skill
description: plain, no deps
---
# plain
EOF

OCTOPUS_DIR_SAVED="$OCTOPUS_DIR"
OCTOPUS_DIR="$FAKE"
OCTOPUS_SKILLS=(plain-skill)

_resolve_skill_dependencies

OCTOPUS_DIR="$OCTOPUS_DIR_SAVED"

[[ "${#OCTOPUS_SKILLS[@]}" -eq 1 ]] \
  || { echo "FAIL: skills count changed unexpectedly"; exit 1; }
[[ "${OCTOPUS_SKILLS[0]}" == "plain-skill" ]] \
  || { echo "FAIL: plain-skill replaced"; exit 1; }

rm -rf "$FAKE"
echo "PASS: skills without depends_on are untouched"
