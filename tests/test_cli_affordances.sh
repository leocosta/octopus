#!/usr/bin/env bash
# tests/test_cli_affordances.sh
# RM-114 — conventional CLI affordances built on the RM-113 registry:
# version/--version, list, help <cmd>, per-command --help, completions.
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLI="$SCRIPT_DIR/cli/octopus.sh"
SHIM="$SCRIPT_DIR/bin/octopus"
PASS=0; FAIL=0
check() {
  local desc="$1"; shift
  if "$@" &>/dev/null; then echo "PASS: $desc"; PASS=$((PASS + 1))
  else echo "FAIL: $desc"; FAIL=$((FAIL + 1)); fi
}

# --- version (shim) --------------------------------------------------------
ver_out() { OCTOPUS_CLI_CACHE_ROOT=/tmp/octopus-none-$$ bash "$SHIM" "$1" 2>&1; }
check "'octopus version' prints a non-empty version"  bash -c "[[ -n \"\$(OCTOPUS_CLI_CACHE_ROOT=/tmp/x-$$ bash '$SHIM' version 2>&1)\" ]]"
check "'octopus --version' works too"                 bash -c "OCTOPUS_CLI_CACHE_ROOT=/tmp/x-$$ bash '$SHIM' --version >/dev/null 2>&1"
check "version output names octopus"                  bash -c "OCTOPUS_CLI_CACHE_ROOT=/tmp/x-$$ bash '$SHIM' version 2>&1 | grep -qi octopus"

# --- list (machine-readable command names) ---------------------------------
LIST="$("$CLI" list 2>&1)"
check "'list' includes a workflow command (release)" grep -qx "release" <<<"$LIST"
check "'list' excludes helper libs (ui)"             bash -c "! grep -qx ui <<<\"$LIST\""

# --- help <cmd> (registry description) -------------------------------------
check "'help release' shows its description" bash -c "'$CLI' help release 2>&1 | grep -qi 'versioned release'"
check "'help <unknown>' errors"              bash -c "! '$CLI' help nope 2>/dev/null"

# --- help <cmd> works for a command without its own --help -----------------
check "'help pr-open' shows its summary" bash -c "'$CLI' help pr-open 2>&1 | grep -qi 'PR'"

# --- a command's OWN --help is preserved (not shadowed by the registry) -----
check "command-owned --help still works (run)" bash -c "'$CLI' run --help 2>&1 | grep -q 'Usage: octopus run'"

# --- completions -----------------------------------------------------------
check "'completions bash' emits a bash function" bash -c "'$CLI' completions bash 2>&1 | grep -q 'complete -F'"
check "'completions bash' lists global + workflow" bash -c "out=\$('$CLI' completions bash 2>&1); grep -q install <<<\"\$out\" && grep -q release <<<\"\$out\""
check "'completions fish' emits fish completions"  bash -c "'$CLI' completions fish 2>&1 | grep -q 'complete -c octopus'"
check "'completions zsh' emits zsh completions"    bash -c "'$CLI' completions zsh 2>&1 | grep -qi 'compdef'"
check "'completions badshell' errors"              bash -c "! '$CLI' completions badshell 2>/dev/null"

echo "PASS=$PASS FAIL=$FAIL"
test "$FAIL" -eq 0
