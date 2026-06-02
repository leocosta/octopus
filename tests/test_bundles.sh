#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUNDLES_DIR="$SCRIPT_DIR/bundles"

echo "Test 1: all expected bundle files exist"
for name in starter docs quality growth backend frontend fullstack; do
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

WORKDIR=$(mktemp -d)
cat > "$WORKDIR/test.yml" <<'EOF'
bundles:
  - starter
  - quality
EOF

parse_octopus_yml "$WORKDIR/test.yml"

[[ ${#OCTOPUS_BUNDLES[@]} -eq 2 ]] \
  || { echo "FAIL: expected 2 bundles, got ${#OCTOPUS_BUNDLES[@]}"; exit 1; }
[[ "${OCTOPUS_BUNDLES[0]}" == "starter" ]] \
  || { echo "FAIL: first bundle wrong"; exit 1; }
[[ "${OCTOPUS_BUNDLES[1]}" == "quality" ]] \
  || { echo "FAIL: second bundle wrong"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: parser reads bundles: list"

echo "Test 4b: parse_octopus_yml strips inline comments from list items"

# A hand-written .octopus.yml may annotate list members with inline comments;
# the manifest parser must store the bare name, never the comment text.
WORKDIR=$(mktemp -d)
cat > "$WORKDIR/.octopus.yml" <<'EOF'
bundles:
  - starter        # foundation
skills:
  - audit-money    # RM-001 — money
roles:
  - architect      # gates
EOF

OCTOPUS_BUNDLES=()
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
parse_octopus_yml "$WORKDIR/.octopus.yml"

[[ "${OCTOPUS_BUNDLES[0]}" == "starter" ]] \
  || { echo "FAIL: bundle parsed as '${OCTOPUS_BUNDLES[0]}'"; exit 1; }
[[ "${OCTOPUS_SKILLS[0]}" == "audit-money" ]] \
  || { echo "FAIL: skill parsed as '${OCTOPUS_SKILLS[0]}'"; exit 1; }
[[ "${OCTOPUS_ROLES[0]}" == "architect" ]] \
  || { echo "FAIL: role parsed as '${OCTOPUS_ROLES[0]}'"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: parse_octopus_yml strips inline comments from list items"

echo "Test 5: _load_bundle parses a single bundle YAML"

# Reset arrays to isolate this test
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()

_load_bundle "starter"

# starter contributes doc-adr, doc-lifecycle, context-budget, implement, debug, respond-to-review, delegate,
# test-tdd, map-system, prototype, context-handoff (Cluster 14 — RM-076, RM-078, RM-081, RM-082)
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort > /tmp/got_skills.$$
printf '%s\n' doc-adr doc-lifecycle context-budget implement debug respond-to-review delegate test-tdd map-system prototype context-handoff | sort > /tmp/exp_skills.$$
diff -q /tmp/got_skills.$$ /tmp/exp_skills.$$ >/dev/null \
  || { echo "FAIL: starter did not populate skills correctly"; exit 1; }
rm -f /tmp/got_skills.$$ /tmp/exp_skills.$$

echo "PASS: _load_bundle populates OCTOPUS_SKILLS for starter"

echo "Test 5b: _load_bundle strips inline YAML comments from list items"

# Bundles may annotate members with inline '# RM-NNN ...' comments (valid YAML).
# The parser must yield the bare skill/role name, never the comment text — a
# glued comment makes setup look for a directory named "skill   # RM-099 ...".
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()

_load_bundle "consigliere"  # every member of this bundle carries an inline '# RM-NNN' comment

[[ ${#OCTOPUS_SKILLS[@]} -gt 0 ]] \
  || { echo "FAIL: consigliere bundle parsed no skills"; exit 1; }

for name in "${OCTOPUS_SKILLS[@]}" "${OCTOPUS_ROLES[@]}"; do
  case "$name" in
    *"#"* | *" "*)
      echo "FAIL: parsed member '$name' carries an inline comment or whitespace"
      exit 1 ;;
  esac
done

echo "PASS: _load_bundle strips inline comments from list items"

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
OCTOPUS_BUNDLES=("starter" "quality")

expand_bundles

expected_skills=(doc-adr doc-lifecycle context-budget implement debug respond-to-review delegate test-tdd map-system prototype context-handoff audit-all audit-security audit-money audit-tenant audit-contracts refactor-deepen audit-config audit-grounding audit-verification audit-style audit-fleet fleet-bootstrap knowledge-hygiene knowledge-synthesize knowledge-briefing)
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort -u > /tmp/got.$$
printf '%s\n' "${expected_skills[@]}" | sort -u > /tmp/exp.$$
diff -q /tmp/got.$$ /tmp/exp.$$ >/dev/null \
  || { echo "FAIL: expand_bundles produced wrong skills"; cat /tmp/got.$$; rm -f /tmp/got.$$ /tmp/exp.$$; exit 1; }
rm -f /tmp/got.$$ /tmp/exp.$$

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^architect$" \
  || { echo "FAIL: architect role missing"; exit 1; }

echo "PASS: expand_bundles unions starter + quality"

echo "Test 8: expand_bundles de-duplicates across bundles"

OCTOPUS_SKILLS=(existing-skill)
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=("backend" "quality")

expand_bundles

count=$(printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -c "^backend-developer$" || true)
[[ "$count" -eq 1 ]] \
  || { echo "FAIL: backend-developer duplicated ($count occurrences)"; exit 1; }

printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -q "^existing-skill$" \
  || { echo "FAIL: explicit skill was dropped by expand_bundles"; exit 1; }

echo "PASS: expand_bundles de-duplicates and preserves explicit entries"

echo "Test 9: bundles-only manifest expands to full component lists"

WORKDIR=$(mktemp -d)
cat > "$WORKDIR/.octopus.yml" <<'EOF'
agents:
  - claude

bundles:
  - starter
  - quality

hooks: true
EOF

OCTOPUS_BUNDLES=()
OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_AGENTS=()
OCTOPUS_MCP=()
OCTOPUS_RULES=()

parse_octopus_yml "$WORKDIR/.octopus.yml"
expand_bundles

# starter (11 skills) + quality (15 unique skills: audit-all + its 3 deps, audit-contracts,
# refactor-deepen, audit-config, audit-grounding, audit-verification, audit-style, audit-fleet,
# fleet-bootstrap, knowledge-hygiene, knowledge-synthesize, knowledge-briefing) = 26 distinct skills
[[ ${#OCTOPUS_SKILLS[@]} -eq 26 ]] \
  || { echo "FAIL: expected 26 skills after bundle expansion, got ${#OCTOPUS_SKILLS[@]}"; exit 1; }

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^architect$" \
  || { echo "FAIL: architect role missing after expansion"; exit 1; }

rm -rf "$WORKDIR"
echo "PASS: bundles-only manifest expands to full component lists"

echo "Test 9b: frontend bundle expands to its skills + role"

OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=("frontend")

expand_bundles

printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort > /tmp/got_fe.$$
printf '%s\n' frontend-patterns test-component test-e2e | sort > /tmp/exp_fe.$$
diff -q /tmp/got_fe.$$ /tmp/exp_fe.$$ >/dev/null \
  || { echo "FAIL: frontend bundle skills wrong"; cat /tmp/got_fe.$$; rm -f /tmp/got_fe.$$ /tmp/exp_fe.$$; exit 1; }
rm -f /tmp/got_fe.$$ /tmp/exp_fe.$$

printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^frontend-developer$" \
  || { echo "FAIL: frontend-developer role missing"; exit 1; }

echo "PASS: frontend bundle expands correctly"

echo "Test 9c: fullstack bundle unions backend + frontend + audit-contracts, dedups test-e2e"

OCTOPUS_SKILLS=()
OCTOPUS_ROLES=()
OCTOPUS_RULES=()
OCTOPUS_MCP=()
OCTOPUS_BUNDLES=("fullstack")

expand_bundles

expected_fs=(backend-patterns test-e2e dba-mssql dba-postgres dba-mongodb dba-redis frontend-patterns test-component audit-contracts)
printf '%s\n' "${OCTOPUS_SKILLS[@]}" | sort -u > /tmp/got_fs.$$
printf '%s\n' "${expected_fs[@]}" | sort -u > /tmp/exp_fs.$$
diff -q /tmp/got_fs.$$ /tmp/exp_fs.$$ >/dev/null \
  || { echo "FAIL: fullstack bundle skills wrong"; cat /tmp/got_fs.$$; rm -f /tmp/got_fs.$$ /tmp/exp_fs.$$; exit 1; }
rm -f /tmp/got_fs.$$ /tmp/exp_fs.$$

te_count=$(printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -c "^test-e2e$" || true)
[[ "$te_count" -eq 1 ]] \
  || { echo "FAIL: test-e2e not de-duplicated in fullstack ($te_count occurrences)"; exit 1; }

for role in backend-developer dba frontend-developer; do
  printf '%s\n' "${OCTOPUS_ROLES[@]}" | grep -q "^${role}$" \
    || { echo "FAIL: fullstack missing role $role"; exit 1; }
done

echo "PASS: fullstack bundle expands and de-duplicates correctly"

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

echo "Test: renamed skill dirs exist"
for skill in doc-adr doc-lifecycle audit-money audit-security audit-tenant respond-to-review audit-contracts launch-feature launch-release debug plan-backlog test-e2e frontend-patterns test-component; do
  [[ -d "skills/${skill}" ]] \
    || { echo "FAIL: skills/${skill}/ not found"; exit 1; }
done
echo "PASS"
