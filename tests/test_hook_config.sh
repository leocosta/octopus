#!/usr/bin/env bash
# Turning individual agent hooks off must be possible, discoverable and
# durable. Before: setup asked one yes/no ("Hooks (destructive-guard,
# session-start)") that installed all 18; the only per-hook switch was the
# OCTOPUS_DISABLED_HOOKS env var, which lasted one setup run — `octopus update`
# re-ran setup without it and the hooks came back. And the guard messages told
# people to set that env var at runtime, where the hooks never read it.
#
# Now: `disabledHooks:` in .octopus.yml (inline or block list), written by the
# setup picker and by `octopus hooks disable|enable`, applied on every setup.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# delivered_ids <settings.json> — the hook ids setup wrote, one per line.
delivered_ids() {
  python3 - "$1" <<'PYEOF'
import json, os, sys
s = json.load(open(sys.argv[1]))
for entries in s.get("hooks", {}).values():
    for e in entries:
        for h in e.get("hooks", []):
            print(os.path.basename(h["command"].strip('"')).removesuffix(".sh"))
PYEOF
}

# deliver <yml-body> — parse that manifest and deliver the hooks, in a subshell
# (setup.sh --source-only defines globals); prints the settings.json path.
deliver() {
  local work; work="$(mktemp -d "$tmp/w.XXXX")"
  mkdir -p "$work/.claude"
  echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$work/.claude/settings.json"
  printf '%s\n' "$1" > "$work/.octopus.yml"
  (
    source "$DIR/setup.sh" --source-only
    unset OCTOPUS_DISABLED_HOOKS
    PROJECT_ROOT="$work"
    MANIFEST_CAP_HOOKS="true"
    MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
    MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
    parse_octopus_yml "$work/.octopus.yml"
    _merge_disabled_hooks_cfg
    deliver_hooks claude
  ) >"$work/out.log" 2>&1
  echo "$work"
}

# ── setup reads disabledHooks ───────────────────────────────────────────────
t_block_list() {
  local w; w="$(deliver $'hooks: true\ndisabledHooks:\n  - auto-format\n  - typecheck  # slow on this repo')"
  local ids; ids="$(delivered_ids "$w/.claude/settings.json")"
  ! grep -qx auto-format <<<"$ids" && ! grep -qx typecheck <<<"$ids" && grep -qx detect-secrets <<<"$ids"
}
check "disabledHooks block list keeps those hooks out of settings.json" t_block_list

t_inline_list() {
  local w; w="$(deliver $'hooks: true\ndisabledHooks: [detect-secrets, "git-push-reminder"]')"
  local ids; ids="$(delivered_ids "$w/.claude/settings.json")"
  ! grep -qx detect-secrets <<<"$ids" && ! grep -qx git-push-reminder <<<"$ids" && grep -qx auto-format <<<"$ids"
}
check "disabledHooks inline list works too" t_inline_list

t_unknown_warns() {
  local w; w="$(deliver $'hooks: true\ndisabledHooks: [no-such-hook]')"
  grep -q "unknown hook 'no-such-hook'" "$w/out.log"
}
check "an unknown id in disabledHooks is reported" t_unknown_warns

t_legacy_destructive_guard() {
  local w; w="$(deliver $'hooks: true\ndestructiveGuard: false')"
  (
    source "$DIR/setup.sh" --source-only
    unset OCTOPUS_DISABLED_HOOKS
    parse_octopus_yml "$w/.octopus.yml"; _merge_disabled_hooks_cfg
    [[ "$OCTOPUS_DESTRUCTIVE_GUARD" == "false" ]]
  )
}
check "destructiveGuard: false is still honoured" t_legacy_destructive_guard

# A manifest saved on Windows (Notepad, Python text mode) is CRLF. Reproduced on
# the Windows VM: `octopus hooks disable` wrote CRLF and setup then read
# "typecheck\r", warned "unknown hook" and left it on.
t_crlf_manifest() {
  local w; w="$(deliver $'hooks: true\r\ndisabledHooks:\r\n  - typecheck\r\n')"
  local ids; ids="$(delivered_ids "$w/.claude/settings.json")"
  ! grep -qx typecheck <<<"$ids" && ! grep -q 'unknown hook' "$w/out.log"
}
check "a CRLF .octopus.yml is read correctly" t_crlf_manifest

t_crlf_toggle_keeps_eol() {
  local p="$tmp/crlf"; mkdir -p "$p"; git -C "$p" init -q
  printf 'agents:\r\n  - claude\r\nhooks: true\r\n' > "$p/.octopus.yml"
  (cd "$p" && bash "$DIR/cli/octopus.sh" hooks disable typecheck --no-apply >/dev/null) || return 1
  local listed; listed="$(cd "$p" && bash "$DIR/cli/octopus.sh" hooks list)"
  grep -q $'^  - typecheck\r$' "$p/.octopus.yml" && ! grep -q $'[^\r]$' "$p/.octopus.yml" \
    && grep -qE '^ +off +typecheck' <<<"$listed"
}
check "hooks disable keeps a CRLF manifest CRLF, and list still reads it" t_crlf_toggle_keeps_eol

# ── the full setup, twice: the second run is what `octopus update` does ─────
t_survives_rerun() {
  local p="$tmp/full"; mkdir -p "$p"; git -C "$p" init -q
  printf 'agents:\n  - claude\nbundles:\n  - starter\nhooks: true\ndisabledHooks:\n  - auto-format\n' > "$p/.octopus.yml"
  local h="$tmp/home"; mkdir -p "$h"
  (cd "$p" && env -u OCTOPUS_DISABLED_HOOKS HOME="$h" bash "$DIR/cli/octopus.sh" setup >/dev/null 2>&1) || return 1
  (cd "$p" && env -u OCTOPUS_DISABLED_HOOKS HOME="$h" bash "$DIR/cli/octopus.sh" setup >/dev/null 2>&1) || return 1
  local ids; ids="$(delivered_ids "$p/.claude/settings.json")"
  ! grep -qx auto-format <<<"$ids" && grep -qx detect-secrets <<<"$ids"
}
check "a hook turned off in .octopus.yml stays off across setup re-runs" t_survives_rerun

# ── the manifest the setup picker writes ────────────────────────────────────
t_generate_manifest() {
  local p="$tmp/gen"; mkdir -p "$p"
  (
    MANIFEST_PATH="$p/.octopus.yml"
    eval "$(sed -n '/^_setup_generate_manifest() {/,/^}/p' "$DIR/cli/lib/setup.sh")"
    _setup_generate_manifest "starter" "true" "true" "" "" "" "claude" "auto-format typecheck auto-format"
  )
  grep -qx 'disabledHooks:' "$p/.octopus.yml" \
    && [[ "$(grep -c '^  - auto-format$' "$p/.octopus.yml")" == 1 ]] \
    && grep -qx '  - typecheck' "$p/.octopus.yml"
}
check "setup writes the picker's unchecked hooks to disabledHooks (de-duplicated)" t_generate_manifest

# ── octopus hooks list / disable / enable ───────────────────────────────────
CLI="$DIR/cli/octopus.sh"
proj="$tmp/cli"; mkdir -p "$proj"; git -C "$proj" init -q
printf 'agents:\n  - claude\nbundles:\n  - starter\nhooks: true\ndestructiveGuard: false\nworkflow: true\n' > "$proj/.octopus.yml"

t_list() {
  local o; o="$(cd "$proj" && bash "$CLI" hooks list)"
  grep -qE '^ +off +destructive-guard' <<<"$o" && grep -qE '^ +on +detect-secrets' <<<"$o" \
    && grep -q 'Guards' <<<"$o" && ! grep -q 'mark-stale-translation' <<<"$o"
}
check "hooks list shows each hook on/off, grouped, without the internal one" t_list

t_disable() {
  (cd "$proj" && bash "$CLI" hooks disable auto-format typecheck --no-apply >/dev/null) || return 1
  local off; off="$(sed -n '/^disabledHooks:/,/^[^ ]/p' "$proj/.octopus.yml")"
  grep -q 'auto-format' <<<"$off" && grep -q 'typecheck' <<<"$off" && grep -q 'destructive-guard' <<<"$off" \
    && ! grep -q 'destructiveGuard' "$proj/.octopus.yml" && grep -qx 'workflow: true' "$proj/.octopus.yml"
}
check "hooks disable persists to disabledHooks and folds destructiveGuard in" t_disable

t_enable() {
  (cd "$proj" && bash "$CLI" hooks enable auto-format typecheck destructive-guard --no-apply >/dev/null) || return 1
  ! grep -q 'disabledHooks' "$proj/.octopus.yml" && grep -qx 'hooks: true' "$proj/.octopus.yml"
}
check "hooks enable removes them, and the key when the list empties" t_enable

t_unknown_id() { (cd "$proj" && bash "$CLI" hooks disable no-such-hook >/dev/null 2>&1); [[ $? -eq 2 ]]; }
check "hooks disable rejects an unknown id" t_unknown_id

t_apply() {
  local h="$tmp/home2"; mkdir -p "$h"
  (cd "$proj" && env -u OCTOPUS_DISABLED_HOOKS HOME="$h" bash "$CLI" hooks disable typecheck >/dev/null 2>&1) || return 1
  local ids; ids="$(delivered_ids "$proj/.claude/settings.json")"
  ! grep -qx typecheck <<<"$ids" && grep -qx auto-format <<<"$ids"
}
check "hooks disable (without --no-apply) re-runs setup and takes effect" t_apply

# ── the setup picker ─────────────────────────────────────────────────────────
t_picker_rows() {
  (
    source "$DIR/cli/lib/setup-picker.sh"
    _CURRENT_DISABLED_HOOKS=(typecheck)
    rows="$(_picker_hook_rows)"
    grep -q $'^h:hooks-guards\t' <<<"$rows" \
      && grep -q $'^k:detect-secrets\t[^\t]*\t1\t' <<<"$rows" \
      && grep -q $'^k:typecheck\t[^\t]*\t0\t' <<<"$rows" \
      && ! grep -q 'mark-stale-translation' <<<"$rows"
  )
}
check "picker offers every hook, checked unless already off" t_picker_rows

t_picker_diff() {
  (
    source "$DIR/cli/lib/setup-picker.sh"
    _CURRENT_DISABLED_HOOKS=(mark-stale-translation)
    hook_catalog_visible_ids | grep -vx -e auto-format -e detect-secrets > "$tmp/kept"
    off="$(_picker_disabled_from_kept "$tmp/kept")"
    [[ "$(sort <<<"$off" | tr '\n' ' ')" == "auto-format detect-secrets mark-stale-translation " ]]
  )
}
check "unchecked hooks become disabledHooks; a hidden one already off stays off" t_picker_diff

# ── the guards say how to turn them off, in a way that works ────────────────
t_messages() {
  local f bad=0
  for f in detect-secrets block-no-verify destructive-guard; do
    grep -q "octopus hooks disable $f" "$DIR/hooks/pre-tool-use/$f.sh" || { echo "  $f: no disable hint"; bad=1; }
  done
  ! grep -rq 'use OCTOPUS_DISABLED_HOOKS=' "$DIR/hooks/" || { echo "  a hook still suggests the runtime env var"; bad=1; }
  return $bad
}
check "blocking hooks point at 'octopus hooks disable <id>'" t_messages

echo ""
echo "hook config: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
