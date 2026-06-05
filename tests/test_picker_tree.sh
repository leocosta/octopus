#!/usr/bin/env bash
# tests/test_picker_tree.sh
# Collapsible tree picker — the interactive fzf front-end isn't unit-testable,
# but the state engine (setup-picker-op.sh) and the catalog builder are pure
# file ops. This drives them headlessly: build the catalog from the real
# bundles, render/expand/toggle, and assert the resulting sel/excl state.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS+1)); else echo "FAIL: $d"; FAIL=$((FAIL+1)); fi; }

# --- engine in isolation, synthetic catalog --------------------------------
source "$SCRIPT_DIR/cli/lib/setup-picker-op.sh"
SD="$(mktemp -d)"
printf '%s\n' \
"head	h:Intent	Intent	" \
"bundle	b:quality-metrics	quality-metrics	Measurement axis" \
"member	m:quality-metrics	quality-metrics	quality-metrics|skill" \
"head	h:Stack	Stack	" \
"bundle	b:stack-typescript	stack-typescript	TS profile" \
"member	m:typescript	typescript	stack-typescript|rule" > "$SD/catalog"
: > "$SD/sel"; : > "$SD/feat"; : > "$SD/excl"; : > "$SD/exp"

# collapsed: members hidden
out="$(op_main "$SD" render)"
check "collapsed hides members"        bash -c '! grep -q "m:typescript" <<<"$1"' _ "$out"
check "collapsed shows the bundle"     grep -q "b:stack-typescript" <<<"$out"
check "collapsed bundle uses ▸"        grep -q "▸ stack-typescript" <<<"$out"

# expand reveals members, with kind shown
op_main "$SD" expand b:stack-typescript
out="$(op_main "$SD" render)"
check "expanded reveals the rule member"   grep -q "m:typescript" <<<"$out"
check "member shows its kind (rule)"        grep -q "typescript (rule)" <<<"$out"
check "expanded bundle uses ▾"              grep -q "▾ stack-typescript" <<<"$out"

# toggling a bundle writes sel; toggling a member writes excl (uncheck)
op_main "$SD" toggle b:stack-typescript
check "toggle bundle → sel"            grep -qx "stack-typescript" "$SD/sel"
op_main "$SD" toggle m:typescript
check "uncheck member → excl"          grep -qx "typescript" "$SD/excl"
out="$(op_main "$SD" render)"
check "unchecked member renders [ ]"   grep -q '\[ \] typescript (rule)' <<<"$out"
# re-check clears the exclude
op_main "$SD" toggle m:typescript
check "re-check member clears excl"     bash -c '! grep -qx typescript "$1/excl"' _ "$SD"

# describe feeds the preview pane
desc_out="$(op_main "$SD" describe b:quality-metrics)"
check "describe returns bundle desc"   grep -q "Measurement axis" <<<"$desc_out"
rm -rf "$SD"

# --- catalog builder against the real bundles ------------------------------
export MANIFEST_PATH="/nonexistent"; export SETUP_PROFILES=""
source "$SCRIPT_DIR/cli/lib/setup-picker.sh"
ST="$(mktemp -d)"; _CURRENT_BUNDLES=(); _picker_write_catalog "$ST"
cat="$(cat "$ST/catalog")"
check "catalog has a Foundation header"   grep -q $'^head\th:Foundation' <<<"$cat"
check "catalog has a Stack header"        grep -q $'^head\th:Stack' <<<"$cat"
check "catalog lists quality-metrics"     grep -q $'^bundle\tb:quality-metrics' <<<"$cat"
check "catalog carries a rule member"     grep -q $'^member\tm:typescript\ttypescript\tstack-typescript|rule' <<<"$cat"
check "fresh repo defaults sel=starter"   grep -qx "starter" "$ST/sel"
check "hooks on by default"               grep -qx "hooks" "$ST/feat"
rm -rf "$ST"

echo "-----------------------------------------"
echo "PASS=$PASS FAIL=$FAIL"
[[ "$FAIL" -eq 0 ]]
