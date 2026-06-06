#!/usr/bin/env bash
# tests/test_picker_tree.sh
# Two-screen native-multiselect picker. The fzf front-end isn't unit-testable,
# but the two row builders (_picker_bundle_rows = screen 1, _picker_member_rows
# = screen 2) and the keep→exclude diff (_picker_diff_union_kept) are pure. Drive
# them headless against the real bundles. Grep/exit-code, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

export MANIFEST_PATH="/nonexistent" SETUP_PROFILES=""
source "$SCRIPT_DIR/cli/lib/setup-picker.sh"

# --- Screen 1: bundles + features, NO members ------------------------------
_CURRENT_BUNDLES=(starter); _CURRENT_EXCLUDES=()
rows="$(_picker_bundle_rows)"
rowdef() { grep -F "$1"$'\t' <<<"$rows" | head -1 | cut -f3; }

check "screen 1 has a Features header"   grep -q $'^h:Features\t' <<<"$rows"
check "screen 1 has a Foundation header" grep -q $'^h:Foundation\t' <<<"$rows"
check "screen 1 has a Stack header"      grep -q $'^h:Stack\t' <<<"$rows"
check "screen 1 has NO member rows"      test "$(grep -c $'^m:' <<<"$rows")" -eq 0
check "hooks pre-selected (default 1)"   test "$(rowdef f:hooks)" = "1"
check "reviewers off by default (0)"     test "$(rowdef f:reviewers)" = "0"
check "current bundle pre-selected"      test "$(rowdef b:starter)" = "1"
check "non-current bundle off"           test "$(rowdef b:knowledge)" = "0"
# Stack/DB are atomic profiles: shown under their category with a BARE label
# (no db-/stack- prefix), since they aren't multi-item bundles.
check "stack profile labeled bare"       grep -q $'^b:stack-csharp\t csharp\t' <<<"$rows"
check "db profile labeled bare"          grep -q $'^b:db-mssql\t mssql\t' <<<"$rows"

# --- Screen 2: members of the chosen INTENT bundles; stack/db are skipped ---
_CURRENT_BUNDLES=(starter); _CURRENT_EXCLUDES=()
m="$(_picker_member_rows starter stack-typescript db-mssql)"
check "screen 2 groups intent bundle by header" grep -q $'^h:starter\t' <<<"$m"
check "screen 2 lists a skill member"      grep -q $'^m:implement\t      implement (skill)\t1\t' <<<"$m"
check "member kept by default (1)"         test "$(grep -F 'm:implement'$'\t' <<<"$m" | head -1 | cut -f3)" = "1"
# atomic profiles never get a screen-2 group (no redundant 1-member fine-tune)
check "screen 2 skips stack profile"       bash -c '! grep -q "stack-typescript\|m:typescript" <<<"$1"' _ "$m"
check "screen 2 skips db profile"          bash -c '! grep -q "db-mssql\|dba-mssql" <<<"$1"' _ "$m"
check "only stack/db chosen → screen 2 empty" test -z "$(_picker_member_rows stack-csharp db-mssql)"
check "member of an unchosen bundle absent" bash -c '! grep -q "audit-all" <<<"$1"' _ "$m"
check "no members → empty output"          test -z "$(_picker_member_rows __nonexistent__)"

# Excluded member starts unchecked (default 0).
_CURRENT_BUNDLES=(starter); _CURRENT_EXCLUDES=(prototype)
m2="$(_picker_member_rows starter)"
check "excluded member starts unchecked"   test "$(grep -F 'm:prototype'$'\t' <<<"$m2" | cut -f3)" = "0"

# --- keep → exclude diff ---------------------------------------------------
U="$(mktemp)"; K="$(mktemp)"
printf 'audit-all\naudit-contracts\ntypescript\n' > "$U"
printf 'audit-all\naudit-contracts\n' > "$K"   # typescript NOT kept
check "diff yields the unkept member"   grep -qx "typescript" <<<"$(_picker_diff_union_kept "$U" "$K")"
printf 'audit-all\naudit-contracts\ntypescript\n' > "$K"
check "nothing excluded when all kept"  test -z "$(_picker_diff_union_kept "$U" "$K")"
rm -f "$U" "$K"

# --- regression guard: rc capture must be set -e-safe -----------------------
# cli/octopus.sh runs `set -euo pipefail`; capturing a non-zero exit with a bare
# `cmd; rc=$?` aborts the whole setup before the back/cancel branch runs (that
# was the "ESC abandons setup" bug). Both screens must use the if-form.
PICKER="$SCRIPT_DIR/cli/lib/setup-picker.sh"
check "no set -e-unsafe '; rc=\$?' capture" bash -c '! grep -q "; rc=\$?" "$1"' _ "$PICKER"
check "fzf-screen run uses if-form rc capture" \
  grep -q 'if out=.*fzf_bin.*then rc=0; else rc=$?; fi' "$PICKER"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
