#!/usr/bin/env bash
# Regression guard for #245: the Bash guard hooks must read the command from
# where Claude Code actually sends it — tool_input.command in the PreToolUse
# payload — not a top-level `command` field. Reading the wrong field made
# block-no-verify, detect-secrets and git-push-reminder see an empty command
# and exit 0 on every platform, so they never fired.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOKS="$DIR/hooks/pre-tool-use"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

# A real Claude Code PreToolUse payload for the Bash tool.
payload() {
  printf '%s' "$1" | python3 -c 'import json, sys; print(json.dumps({
    "session_id": "s", "hook_event_name": "PreToolUse", "tool_name": "Bash",
    "tool_input": {"command": sys.stdin.read(), "description": "d"}}))'
}

# run_hook <hook> <command> — prints "rc=<n>" and the hook's stderr.
run_hook() {
  local out rc
  out="$(payload "$2" | bash "$HOOKS/$1.sh" 2>&1)"; rc=$?
  printf 'rc=%s\n%s\n' "$rc" "$out"
}

# ── block-no-verify ──────────────────────────────────────────────────────────
t_no_verify_blocks() { run_hook block-no-verify 'git commit --no-verify -m x' | grep -qx 'rc=2'; }
check "block-no-verify blocks 'git commit --no-verify'" t_no_verify_blocks

t_no_verify_allows() { run_hook block-no-verify 'git commit -m x' | grep -qx 'rc=0'; }
check "block-no-verify allows a plain commit" t_no_verify_allows

# ── git-push-reminder ────────────────────────────────────────────────────────
t_push_reminds() { local o; o="$(run_hook git-push-reminder 'git push origin main')"; grep -qx 'rc=0' <<<"$o" && grep -q 'REMINDER' <<<"$o"; }
check "git-push-reminder reminds on 'git push' (without blocking)" t_push_reminds

t_push_silent() { ! run_hook git-push-reminder 'git status' | grep -q 'REMINDER'; }
check "git-push-reminder stays silent on other commands" t_push_silent

# ── detect-secrets (scans the STAGED files of the current repo) ──────────────
REPO="$(mktemp -d)"; trap 'rm -rf "$REPO"' EXIT
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name t
printf 'const key = "AKIA%s";\n' ABCDEFGHIJKLMNOP > "$REPO/config.js"
git -C "$REPO" add config.js

t_secrets_blocks() { local o; o="$(cd "$REPO" && run_hook detect-secrets 'git commit -m add')"; grep -qx 'rc=2' <<<"$o" && grep -q 'config.js' <<<"$o"; }
check "detect-secrets blocks a commit with a staged AWS key" t_secrets_blocks

t_secrets_ignores_other() { (cd "$REPO" && run_hook detect-secrets 'git status') | grep -qx 'rc=0'; }
check "detect-secrets ignores non-commit commands" t_secrets_ignores_other

# ── non-Bash tools carry no tool_input.command: every hook lets them through ──
t_non_bash() {
  local h
  for h in block-no-verify detect-secrets git-push-reminder; do
    printf '{"hook_event_name":"PreToolUse","tool_name":"Read","tool_input":{"file_path":"/x"}}' \
      | bash "$HOOKS/$h.sh" >/dev/null 2>&1 || { echo "  $h did not exit 0 for a Read payload"; return 1; }
  done
}
check "non-Bash payloads pass through every guard" t_non_bash

echo ""
echo "guard hooks payload: $PASS passed, $FAIL failed."
[[ "$FAIL" -eq 0 ]]
