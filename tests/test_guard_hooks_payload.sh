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

# #249: every spelling git accepts for "skip the hooks" is blocked …
t_bypasses_blocked() {
  local cmd bad=0
  for cmd in 'git commit -n -m x' 'git commit -anm x' 'git commit --no-veri -m x' \
             'git -c core.hooksPath=/dev/null commit -m x' 'HUSKY=0 git commit -m x' \
             'SKIP=flake8 git commit -m x' 'git -C sub commit -n' \
             'git add . && git commit --no-verify -m x' 'bash -c "git commit -n -m x"' \
             'git push --no-verify origin main'; do
    run_hook block-no-verify "$cmd" | grep -qx 'rc=2' || { echo "  not blocked: $cmd"; bad=1; }
  done
  return $bad
}
check "block-no-verify blocks -n, clusters, prefixes, core.hooksPath, HUSKY/SKIP, chains" t_bypasses_blocked

# The parser must never see LESS than bash does — each of these hid a bypass
# from an earlier draft of the parser (a mid-word `#`, a quoted or `<<<` "heredoc"
# swallowing the next line), and the rest are constructs it cannot see through,
# where the literal-text floor of the old hook still applies.
t_parser_differentials_blocked() {
  local cmd bad=0
  for cmd in 'git commit foo#x --no-verify' $'echo "<<EOF"\ngit commit --no-verify -m x' \
             $'cat <<<EOF\ngit commit -n -m x' $'echo hi # <<EOF\ngit commit --no-verify\nEOF' \
             $'git add . \\\n && git commit \\\n -n -m x' '$(echo git) commit --no-verify' \
             'echo x | xargs git commit --no-verify -m' "git -c alias.ci='commit -n' ci -m x" \
             "git -c alias.ci='!git commit -n' ci" 'git --config-env=core.hooksPath=H commit -m x' \
             'GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.hooksPath GIT_CONFIG_VALUE_0=/x git commit -m x' \
             'export HUSKY=0; git commit -m x' 'eval "git commit --no-verify"' \
             'git commit --no-verify -m "unterminated' $'bash <<\'EOF\'\ngit commit -n -m x\nEOF' \
             $'cat <<EOF | sh\ngit commit -anm x\nEOF' 'timeout 5 git commit -n -m x' \
             '{ git commit -n -m x; }' 'if git commit -n -m x; then :; fi' 'nice -n 5 git commit -n' \
             'find . -exec git commit -n \\;' 'bash -ec "git commit -n"' \
             "python3 -c \"import os; os.system('git commit --no-verify')\"" \
             'F=--no-verify; git commit $F -m x' 'git commit {-n,-m} x' 'git $SUB --no-verify' \
             'git config core.hooksPath /dev/null' \
             'bash -c "git commit -m --no-verify"; myfn --no-verify' "git commit \$'-n' -m x" \
             $'echo $\'it\\\'s\' # <<EOF\ngit commit --no-verify\nEOF' \
             'git commit -[n] -m x' '/usr/lib/git-core/git-commit -n -m x' \
             'GIT_CONFIG_GLOBAL=/tmp/x git commit -m x' 'HOME=/tmp/x git commit -m x' \
             $'cat <<\'E\'OF\nx\nEOF\ngit commit -n -m x' $'echo $((1<<2))\ngit commit --no-verify' \
             'git -c include.path=/tmp/x commit -m x' 'git config core.hooksPath /x --get' \
             $'python3 <<EOF\nimport os; os.system("git commit --no-verify")\nEOF' \
             "python3 -c \"import subprocess; subprocess.run(['git','commit','-n','-m','x'])\"" \
             'git config -f get core.hooksPath /x' 'git --git-dir=/tmp/r/.git commit -m x' \
             "git -c alias.p='!sh -c \"git commit -n\"' p" \
             $'cat <<EOF > x.sh\ngit commit --no-verify\nEOF\nbash x.sh' 'cd $X && git ci -m x' \
             "git config alias.ci 'commit -n'" 'gi? commit --no-verify' '$G commit -n -m x' \
             'git config alias.zz commit; git zz -n -m x' 'git am -3n x.mbox' 'git am --no-v x.mbox' \
             "ssh host 'git commit -n -m x'" 'cd /nonexistent-dir && git zz -m x' \
             'echo $((1<<2)); SKIP=x git commit -m x' 'foo git commit -m --no-verify' \
             "printf '[core]\\nhooksPath=/x\\n' >> .git/config && git commit -m x" \
             "echo 'exit 0' > .git/hooks/pre-commit" 'chmod -x .git/hooks/pre-commit' \
             'git commit -m x 2>&1 -n' 'git commit -m x &> log --no-verify' \
             'git -c alias.a=b -c alias.b=c -c alias.c=d -c alias.d=e a' \
             'HUSKY=$X git commit -m x' 'HUSKY=false git commit -m x'; do
    run_hook block-no-verify "$cmd" | grep -qx 'rc=2' || { echo "  not blocked: $cmd"; bad=1; }
  done
  return $bad
}
check "block-no-verify agrees with bash on comments/heredocs and floors opaque commands" t_parser_differentials_blocked

# An alias from the user's git config is resolved, not taken at face value.
t_configured_alias() {
  local r; r="$(mktemp -d)"; git -C "$r" init -q; git -C "$r" config alias.ci 'commit -n'
  local o; o="$(run_hook block-no-verify "git -C $r ci -m x")"
  local o2; o2="$(cd "$r" && run_hook block-no-verify 'cd $UNSET_DIR && git ci -m x')"; rm -rf "$r"
  grep -qx 'rc=2' <<<"$o" && grep -qx 'rc=2' <<<"$o2"
}
check "block-no-verify resolves aliases from git config" t_configured_alias

# … and text that only MENTIONS a flag is not.
t_false_positives_allowed() {
  local cmd bad=0
  for cmd in 'git commit -m "docs: explain --no-verify"' 'git commit -mn' 'git commit -m -n' \
             'git push -n origin main' 'git merge -n topic' 'git commit -m "$MSG" -F "$TMP"' \
             'git config --get core.hooksPath' 'grep -rn hooksPath cli/' 'git commit src/*.js -m x' \
             "python3 -c 'print(1)'" "git config alias.lg 'log --oneline -n 20'" \
             'git commit --no-edit' "ssh host 'git status'" 'echo $((1<<2))' 'ls .git/hooks' \
             "git commit -m 'msg' >/dev/null 2>&1" 'git commit -m x 2>&1 | tee log' \
             $'git commit -m "$(cat <<\'EOF\'\nfix: it\'s --no-verify-free\nEOF\n)"' \
             $'cat <<EOF > notes.sh\ngit commit -n\nEOF'; do
    run_hook block-no-verify "$cmd" | grep -qx 'rc=0' || { echo "  wrongly blocked: $cmd"; bad=1; }
  done
  return $bad
}
check "block-no-verify allows messages, push/merge -n, \$MSG values and heredoc messages" t_false_positives_allowed

# Degraded mode is loud: an unparseable payload or a missing Python warns.
t_degraded_warns() {
  local out nopy
  out="$(printf 'not json' | bash "$HOOKS/block-no-verify.sh" 2>&1)" || return 1
  grep -q 'WARNING: block-no-verify could not check' <<<"$out" || return 1
  nopy="$(mktemp -d)"; ln -s "$(command -v cat)" "$nopy/cat"
  out="$(payload 'git commit -n' | PATH="$nopy" "$BASH" "$HOOKS/block-no-verify.sh" 2>&1)"; local rc=$?
  rm -rf "$nopy"
  [[ $rc -eq 0 ]] && grep -q 'WARNING: block-no-verify' <<<"$out"
}
check "block-no-verify warns (and lets through) when it cannot check" t_degraded_warns

# ── git-push-reminder ────────────────────────────────────────────────────────
t_push_reminds() { local o; o="$(run_hook git-push-reminder 'git push origin main')"; grep -qx 'rc=0' <<<"$o" && grep -q 'REMINDER' <<<"$o"; }
check "git-push-reminder reminds on 'git push' (without blocking)" t_push_reminds

t_push_silent() { ! run_hook git-push-reminder 'git status' | grep -q 'REMINDER'; }
check "git-push-reminder stays silent on other commands" t_push_silent

# ── detect-secrets (scans the STAGED files of the current repo) ──────────────
REPO="$(mktemp -d)"; OTHER=""; trap 'rm -rf "$REPO" "$OTHER"' EXIT
git -C "$REPO" init -q
git -C "$REPO" config user.email t@example.com
git -C "$REPO" config user.name t
printf 'const key = "AKIA%s";\n' ABCDEFGHIJKLMNOP > "$REPO/config.js"
git -C "$REPO" add config.js

t_secrets_blocks() { local o; o="$(cd "$REPO" && run_hook detect-secrets 'git commit -m add')"; grep -qx 'rc=2' <<<"$o" && grep -q 'config.js' <<<"$o"; }
check "detect-secrets blocks a commit with a staged AWS key" t_secrets_blocks

t_secrets_ignores_other() { (cd "$REPO" && run_hook detect-secrets 'git status') | grep -qx 'rc=0'; }
check "detect-secrets ignores non-commit commands" t_secrets_ignores_other

# #249: the commit's repository is found through `git -C` and `cd`.
OTHER="$(mktemp -d)"
git -C "$OTHER" init -q
printf 'const key = "AKIA%s";\n' ABCDEFGHIJKLMNOP > "$OTHER/settings.js"
git -C "$OTHER" add settings.js
t_secrets_dash_c() { local o; o="$(cd "$REPO" && run_hook detect-secrets "git -C $OTHER commit -m add")"; grep -qx 'rc=2' <<<"$o" && grep -q 'settings.js' <<<"$o"; }
check "detect-secrets scans the repository named by git -C" t_secrets_dash_c

t_secrets_cd() { local o; o="$(cd / && run_hook detect-secrets "cd $OTHER && git  commit -m add")"; grep -qx 'rc=2' <<<"$o" && grep -q 'settings.js' <<<"$o"; }
check "detect-secrets follows cd and doubled whitespace" t_secrets_cd

# The scan runs before the user approves the command, in a directory the
# command names: a hostile clone's core.fsmonitor must not run.
t_secrets_no_fsmonitor() {
  local r; r="$(mktemp -d)"; git -C "$r" init -q
  printf 'k="AKIA%s"\n' ABCDEFGHIJKLMNOP > "$r/a.js"; git -C "$r" add a.js
  git -C "$r" config core.fsmonitor "touch $r/PWNED; false"
  local o; o="$(run_hook detect-secrets "git -C $r commit -m x")"
  local pwned=no; [[ -e "$r/PWNED" ]] && pwned=yes; rm -rf "$r"
  grep -qx 'rc=2' <<<"$o" && [[ $pwned == no ]]
}
check "detect-secrets never runs a scanned repo's core.fsmonitor" t_secrets_no_fsmonitor

# A commit through an alias (git ci) is scanned too.
t_secrets_alias() { git -C "$OTHER" config alias.ci commit; local o; o="$(cd / && run_hook detect-secrets "git -C $OTHER ci -m add")"; grep -qx 'rc=2' <<<"$o" && grep -q 'settings.js' <<<"$o"; }
check "detect-secrets scans a commit made through an alias" t_secrets_alias

# A commit it cannot locate (command substitution, unbalanced quoting) is
# scanned in the current repository rather than let through unscanned.
t_secrets_opaque() { local o; o="$(cd "$REPO" && run_hook detect-secrets 'out=$(git commit -m "add')"; grep -qx 'rc=2' <<<"$o" && grep -q 'config.js' <<<"$o"; }
check "detect-secrets scans the current repo when it cannot locate the commit" t_secrets_opaque

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
