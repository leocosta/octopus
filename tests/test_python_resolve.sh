#!/usr/bin/env bash
# cli/lib/python.sh — resolve a WORKING Python 3 under the name `python3`.
#
# On Windows, `python3` on PATH is usually the Microsoft Store App Execution
# Alias: it exists, prints "Python was not found…", and exits 9009. The
# python.org installer only ships `python.exe`, so even a machine WITH Python
# hits the alias. Every `python3` call in setup.sh and the hooks then fails —
# setup aborts before writing .claude/settings.json, and the guard hooks
# (`… | python3 … 2>/dev/null || echo ""`) silently fail open.
#
# These tests fake each binary on a private PATH and assert which one runs. The
# fake Store alias lives under a WindowsApps/ directory, as the real one does —
# that location, not a run-probe, is how the resolver recognises it.
set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB="$DIR/cli/lib/python.sh"
REAL_PY="$(command -v python3)"
BASH_BIN="$(command -v bash)"
PASS=0; FAIL=0
check() { local d="$1"; shift; if "$@"; then echo "PASS: $d"; PASS=$((PASS + 1)); else echo "FAIL: $d"; FAIL=$((FAIL + 1)); fi; }

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT

# make_bin <dir> <name> <behaviour>: stub | real
make_bin() {
  mkdir -p "$1"
  case "$3" in
    stub) printf '#!/bin/sh\necho "Python was not found; run without arguments to install from the Microsoft Store" >&2\nexit 9009\n' > "$1/$2" ;;
    real) printf '#!/bin/sh\nexec "%s" "$@"\n' "$REAL_PY" > "$1/$2" ;;
  esac
  chmod +x "$1/$2"
}

# run_with <bindir> <snippet>: source the lib under a PATH holding only <bindir>
# plus the bare tools bash needs, then run <snippet>.
run_with() {
  local tools="$tmp/tools"
  mkdir -p "$tools"
  for t in sh cat env bash; do ln -sf "$(command -v $t)" "$tools/$t"; done
  PATH="$1:$tools" "$BASH_BIN" -c "source '$LIB'; $2" 2>&1
}

# 1. Store alias as python3, real `python` present → python3 must work.
make_bin "$tmp/a/WindowsApps" python3 stub; make_bin "$tmp/a/bin" python real
A="$tmp/a/WindowsApps:$tmp/a/bin"
t_alias_falls_back() { [[ "$(run_with "$A" 'python3 -c "print(6*7)"')" == "42" ]]; }
check "Store-alias python3 falls back to a working python" t_alias_falls_back

# 2. The fallback reaches child bash processes (setup.sh runs as a subprocess).
t_exported() { [[ "$(run_with "$A" 'bash -c "python3 -c \"print(1)\""')" == "1" ]]; }
check "the resolved python3 is visible to child bash scripts" t_exported

# 3. Heredoc form used throughout setup.sh (`python3 - args <<EOF`).
t_heredoc() {
  [[ "$(run_with "$A" 'python3 - x y <<"PY"
import sys; print(sys.argv[1:])
PY')" == "['x', 'y']" ]]
}
check "heredoc invocation passes argv through" t_heredoc

# 4. A working python3 is left alone (no function shadowing it).
make_bin "$tmp/b" python3 real
t_untouched() { [[ "$(run_with "$tmp/b" 'type -t python3')" == "file" ]]; }
check "a working python3 is not shadowed" t_untouched

# 5. Only the `py` launcher (python.org with "Add to PATH" unticked).
make_bin "$tmp/c/WindowsApps" python3 stub; make_bin "$tmp/c/WindowsApps" python stub
mkdir -p "$tmp/c/bin"
printf '#!/bin/sh\n[ "$1" = "-3" ] && shift\nexec "%s" "$@"\n' "$REAL_PY" > "$tmp/c/bin/py"; chmod +x "$tmp/c/bin/py"
t_py_launcher() { [[ "$(run_with "$tmp/c/WindowsApps:$tmp/c/bin" 'python3 -c "print(7)"')" == "7" ]]; }
check "falls back to the py -3 launcher" t_py_launcher

# 6. Only Store aliases → octopus_require_python fails with an actionable message.
make_bin "$tmp/d/WindowsApps" python3 stub; make_bin "$tmp/d/WindowsApps" python stub
t_require_fails() {
  local out rc
  out="$(run_with "$tmp/d/WindowsApps" 'octopus_require_python; echo rc=$?')"
  rc="${out##*rc=}"
  [[ "$rc" == "1" ]] && grep -q 'Python 3 is required' <<<"$out"
}
check "octopus_require_python fails loudly when no interpreter works" t_require_fails

t_require_ok() { [[ "$(run_with "$A" 'octopus_require_python && echo ok')" == "ok" ]]; }
check "octopus_require_python succeeds after a fallback" t_require_ok

# 6b. Resolution spawns nothing: hooks source this on every tool call. A python3
#     that would record being run must not be run by merely sourcing the lib.
mkdir -p "$tmp/e"
printf '#!/bin/sh\ntouch "%s/spawned"\nexec "%s" "$@"\n' "$tmp" "$REAL_PY" > "$tmp/e/python3"
t_no_spawn() { rm -f "$tmp/spawned"; run_with "$tmp/e" 'true' >/dev/null; [[ ! -e "$tmp/spawned" ]]; }
check "sourcing the resolver spawns no interpreter" t_no_spawn

# 7. Every shipped hook that calls python3 loads the resolver first.
t_hooks_source_lib() {
  local f bad=0
  while IFS= read -r f; do
    if ! grep -qF 'cli/lib/python.sh' "$f"; then echo "  missing resolver: ${f#$DIR/}"; bad=1; fi
  done < <(grep -rlE '^[^#]*\bpython3\b' "$DIR/hooks" --include='*.sh')
  return $bad
}
check "every hook that calls python3 sources cli/lib/python.sh" t_hooks_source_lib

echo
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
