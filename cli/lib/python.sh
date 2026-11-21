# python.sh — make `python3` mean a working Python 3 interpreter.
#
# Sourced (never executed) by the shim, setup.sh, cli/octopus.sh and every hook
# that parses JSON with Python. Octopus calls `python3` in ~40 places; on
# Windows that name is almost always the Microsoft Store App Execution Alias
# (%LOCALAPPDATA%\Microsoft\WindowsApps\python3.exe): it exists on PATH, prints
# "Python was not found…" and exits 9009 — even on machines WITH Python, since
# the python.org installer ships `python.exe` only. setup.sh then aborts before
# writing .claude/settings.json, and the guard hooks fail OPEN.
#
# Only Git Bash / MSYS / Cygwin can hit the alias, so everywhere else this file
# defines nothing but octopus_require_python — Linux and macOS (including the
# stock bash 3.2, which has no BASH_CMDS) run exactly as before.
#
# Resolution is by PATH lookup alone — no interpreter, no subshell: hooks source
# this on every Claude Code tool call. The alias is recognised by where it lives
# (…/WindowsApps/…); any other `python3` is trusted. Otherwise `python`, then the
# `py` launcher, is wrapped in a `python3` function, exported so child BASH
# scripts inherit it. Non-bash children (`sh -c python3`, Python subprocess) do
# not see shell functions and still get the alias — call python3 from bash.

_octopus_real_cmd() {
  hash "$1" 2>/dev/null || return 1   # PATH lookup into BASH_CMDS (bash 4+), no subshell
  local path="${BASH_CMDS[$1]-}"      # absent for a name that is a function
  [[ -n "$path" && "$path" != */WindowsApps/* ]]
}

OCTOPUS_PYTHON_MISSING=""
case "${OSTYPE:-}" in
  msys* | cygwin*)
    # A python3 FUNCTION is a resolution inherited from the parent (exported
    # below) — keep it. Children such as setup.sh re-source this file.
    if ! declare -F python3 >/dev/null && ! _octopus_real_cmd python3; then
      if _octopus_real_cmd python; then
        python3() { python "$@"; }
        export -f python3
      elif _octopus_real_cmd py; then
        python3() { py -3 "$@"; }
        export -f python3
      else
        OCTOPUS_PYTHON_MISSING=1
      fi
    fi
    ;;
esac

# octopus_require_python — fail with an actionable message when no interpreter
# was found. setup (which cannot run without Python) and `octopus doctor` use
# it; hooks do not, so a missing Python degrades a hook instead of blocking.
octopus_require_python() {
  [[ -z "$OCTOPUS_PYTHON_MISSING" ]] && return 0
  {
    echo "Python 3 is required but no interpreter was found (tried python3, python, py -3)."
    echo "On Windows, 'python3' is usually the Microsoft Store alias, not Python: install"
    echo "Python 3 from https://www.python.org/downloads/ (tick 'Add python.exe to PATH'),"
    echo "then open a new terminal and run the command again."
  } >&2
  return 1
}
