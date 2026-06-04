#!/usr/bin/env bash
# tests/test_member_deselect.sh
# RM-146 — picker member-deselect (skills + roles + rules; fzf and bash paths).
# The interactive phase-2 itself is not unit-testable, so this covers the pure
# pieces: the member union the picker offers (incl. stack/db rules), the bash
# fallback's index→member mapping, that the manifest writer emits `exclude:`,
# and that excluded members — skills, roles, AND rules — are dropped end-to-end
# via _apply_excludes. Grep/exit-code.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }
has() { grep -qx "$2" <<<"$1"; }

# --- member union the picker would offer for the chosen bundles -------------
_PICKER_RELEASE_ROOT="$SCRIPT_DIR"
eval "$(sed -n '/^_picker_member_union()/,/^}/p' "$SCRIPT_DIR/cli/lib/setup-picker.sh")"
union="$(_picker_member_union quality-audits backend)"
check "union includes a bundle skill (audit-all)"      has "$union" "audit-all"
check "union includes a bundle role (dba)"             has "$union" "dba"
check "union includes backend-patterns"                has "$union" "backend-patterns"
check "union does not duplicate"                        test "$(grep -c . <<<"$union")" -eq "$(sort -u <<<"$union" | grep -c .)"

# union now also offers a stack/db profile RULE, so it is deselectable too.
union_ts="$(_picker_member_union starter stack-typescript)"
check "union includes a stack rule (typescript)"       has "$union_ts" "typescript"
check "union still includes a skill (implement)"       has "$union_ts" "implement"

# --- bash fallback: index → member mapping (pure, testable) -----------------
eval "$(sed -n '/^_picker_indices_to_members()/,/^}/p' "$SCRIPT_DIR/cli/lib/setup-picker.sh")"
picks="$(_picker_indices_to_members "1, 3" a b c d)"
check "indices map 1,3 → a,c"          test "$picks" = $'a\nc'
check "indices ignore out-of-range"    test -z "$(_picker_indices_to_members "9 0 x" a b c)"
check "indices handle tab/space mix"   test "$(_picker_indices_to_members $'2\t2' a b c)" = $'b\nb'

# --- manifest writer emits exclude: ----------------------------------------
MANIFEST_PATH="$(mktemp -d)/.octopus.yml"; export MANIFEST_PATH
eval "$(sed -n '/^_setup_generate_manifest()/,/^}/p' "$SCRIPT_DIR/cli/lib/setup.sh")"
_setup_generate_manifest "starter backend" "true" "true" "" "" "audit-style dba-mongodb"
check "manifest has an exclude: block"   grep -q '^exclude:' "$MANIFEST_PATH"
check "exclude lists audit-style"        grep -qE '^[[:space:]]+- audit-style$' "$MANIFEST_PATH"
_setup_generate_manifest "starter" "true" "true" "" "" ""   # no excludes
check "no exclude: written when empty"   bash -c '! grep -q "^exclude:" "$1"' _ "$MANIFEST_PATH"

# --- end-to-end: parse + expand + apply drops the deselected member ---------
cat > "$MANIFEST_PATH" <<'EOF'
bundles:
  - backend
  - db-mssql
  - db-postgres
exclude:
  - dba-postgres
EOF
source "$SCRIPT_DIR/setup.sh" --source-only
OCTOPUS_BUNDLES=(); OCTOPUS_SKILLS=(); OCTOPUS_ROLES=(); OCTOPUS_RULES=(); OCTOPUS_MCP=(); OCTOPUS_EXCLUDE=()
parse_octopus_yml "$MANIFEST_PATH"; expand_bundles; _apply_excludes
_present() { printf '%s\n' "${OCTOPUS_SKILLS[@]}" | grep -qx "$1"; }
_absent()  { ! _present "$1"; }
check "deselected dba-postgres dropped"   _absent dba-postgres
check "kept dba-mssql remains"            _present dba-mssql

# --- end-to-end: a deselected RULE is dropped too ---------------------------
cat > "$MANIFEST_PATH" <<'EOF'
bundles:
  - starter
  - stack-typescript
exclude:
  - typescript
EOF
OCTOPUS_BUNDLES=(); OCTOPUS_SKILLS=(); OCTOPUS_ROLES=(); OCTOPUS_RULES=(); OCTOPUS_MCP=(); OCTOPUS_EXCLUDE=()
parse_octopus_yml "$MANIFEST_PATH"; expand_bundles; _apply_excludes
_rule_absent() { ! printf '%s\n' "${OCTOPUS_RULES[@]:-}" | grep -qx "$1"; }
check "deselected rule typescript dropped" _rule_absent typescript
rm -rf "$(dirname "$MANIFEST_PATH")"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
