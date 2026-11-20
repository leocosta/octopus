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
# Resolution is by PATH lookup alone — no interpreter is spawned. Hooks source
# this on every Claude Code tool call, so a run-probe would tax every platform
# to fix one. The alias is recognised by where it lives (…/WindowsApps/…); any
# other `python3` is trusted. Otherwise `python`, then the `py` launcher, is
# wrapped in a `python3` function, exported so child bash scripts inherit it.

_octopus_real_cmd() {
  hash "$1" 2>/dev/null || return 1   # PATH lookup into BASH_CMDS, no subshell
  [[ "${BASH_CMDS[$1]}" != */WindowsApps/* ]]
}

if [[ -z "${OCTOPUS_PYTHON_RESOLVED:-}" ]]; then
  export OCTOPUS_PYTHON_RESOLVED=1
  if ! _octopus_real_cmd python3; then
    if _octopus_real_cmd python; then
      python3() { python "$@"; }
      export -f python3
    elif _octopus_real_cmd py; then
      python3() { py -3 "$@"; }
      export -f python3
    else
      export OCTOPUS_PYTHON_MISSING=1
    fi
  fi
fi

# octopus_require_python — fail with an actionable message when no interpreter
# was found. setup (which cannot run without Python) and `octopus doctor` use
# it; hooks do not, so a missing Python degrades a hook instead of blocking.
octopus_require_python() {
  [[ -z "${OCTOPUS_PYTHON_MISSING:-}" ]] && return 0
  {
    echo "Python 3 is required but no interpreter was found (tried python3, python, py -3)."
    echo "On Windows, 'python3' is usually the Microsoft Store alias, not Python: install"
    echo "Python 3 from https://www.python.org/downloads/ (tick 'Add python.exe to PATH'),"
    echo "then open a new terminal and run the command again."
  } >&2
  return 1
}
