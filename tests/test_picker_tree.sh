#!/usr/bin/env bash
# tests/test_picker_tree.sh
# Pre-expanded tree picker. The fzf front-end isn't unit-testable, but the row
# builder (_picker_tree_rows) and the keep→exclude diff (_picker_diff_union_kept)
# are pure. This drives them headlessly against the real bundles and asserts the
# tree shape, the pre-select defaults, and that an unchecked member becomes an
# exclude. Grep/exit-code, per project convention.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

export MANIFEST_PATH="/nonexistent" SETUP_PROFILES=""
source "$SCRIPT_DIR/cli/lib/setup-picker.sh"

# --- _picker_tree_rows: shape + defaults -----------------------------------
_CURRENT_BUNDLES=(starter); _CURRENT_EXCLUDES=()
rows="$(_picker_tree_rows)"
field() { cut -f"$1"; }   # tab field helper

# Pull a row's default (field 3) by its id (field 1). Real tabs throughout.
rowdef() { grep -F "$1"$'\t' <<<"$rows" | head -1 | cut -f3; }

check "rows have a Features header"      grep -q $'^h:Features\t' <<<"$rows"
check "rows have a Foundation header"    grep -q $'^h:Foundation\t' <<<"$rows"
check "rows have a Stack header"         grep -q $'^h:Stack\t' <<<"$rows"
check "hooks pre-selected (default 1)"   test "$(rowdef f:hooks)" = "1"
check "reviewers off by default (0)"     test "$(rowdef f:reviewers)" = "0"
check "starter bundle pre-selected"      test "$(rowdef b:starter)" = "1"
check "a non-current bundle is off"      test "$(rowdef b:quality-metrics)" = "0"
check "members are indented + kinded"    grep -q $'^m:implement\t      implement (skill)\t1\t' <<<"$rows"
check "a stack rule appears as a member" grep -q $'^m:typescript\t.*(rule)\t1\t' <<<"$rows"
check "member is kept (default 1)"       test "$(rowdef m:implement)" = "1"

# A member already in the manifest exclude: starts unchecked (default 0).
_CURRENT_BUNDLES=(starter); _CURRENT_EXCLUDES=(prototype)
rows="$(_picker_tree_rows)"
check "excluded member starts unchecked" test "$(rowdef m:prototype)" = "0"

# --- _picker_diff_union_kept: union minus kept = excludes ------------------
U="$(mktemp)"; K="$(mktemp)"
printf 'audit-all\naudit-contracts\narchitect\ntypescript\n' > "$U"
printf 'audit-all\naudit-contracts\narchitect\n' > "$K"   # typescript NOT kept
out="$(_picker_diff_union_kept "$U" "$K")"
check "diff yields the unkept member"   grep -qx "typescript" <<<"$out"
check "diff keeps the rest out"         test "$(grep -c . <<<"$out")" -eq 1
printf 'audit-all\naudit-contracts\narchitect\ntypescript\n' > "$K"   # all kept
check "nothing excluded when all kept"  test -z "$(_picker_diff_union_kept "$U" "$K")"
rm -f "$U" "$K"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
