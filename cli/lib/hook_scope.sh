# hook_scope.sh — keep the edit hooks inside the open project.
#
# Sourced by the hooks that run project tooling after an edit (auto-format,
# typecheck). Those tools execute project code: eslint.config.js,
# .prettierrc.js, mypy plugins, MSBuild targets. Inside the project the user
# opened, that is the same trust Claude Code already has. A file anywhere else —
# a clone under /tmp the agent is inspecting, a dependency's source — is not: an
# edit there was approved, running that tree's code was not.
#
# The root is CLAUDE_PROJECT_DIR (set by Claude Code for hooks), else the git
# top level of the working directory, else the working directory. Paths are
# compared physically (pwd -P), so a symlink inside the project that points
# outside it does not count as inside. bash 3.2 compatible.

OCTOPUS_PROJECT_ROOT=""

# octopus_in_project <file> — 0 when <file>'s directory is inside the project
# root; sets OCTOPUS_PROJECT_ROOT (physical) for bounding later walks.
octopus_in_project() {
  # On Windows, Claude Code sends C:\x\y paths; `dirname` only splits on /,
  # so a backslash path would resolve to "." and every file would look
  # inside. Git Bash accepts C:/x/y.
  local file="${1//\\//}" root dir
  root="${CLAUDE_PROJECT_DIR:-}"
  root="${root//\\//}"
  [[ -n "$root" ]] || root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
  [[ -n "$root" ]] || root="$PWD"
  root="$(cd "$root" 2>/dev/null && pwd -P)" || return 1
  dir="$(cd "$(dirname "$file")" 2>/dev/null && pwd -P)" || return 1
  OCTOPUS_PROJECT_ROOT="$root"
  [[ "$dir" == "$root" || "$dir" == "$root"/* ]]
}

# octopus_nearest_project <file> <glob>... — the nearest directory at or above
# <file> holding a match for one of the globs, never above the project root.
# Prints nothing when there is none.
octopus_nearest_project() {
  local file="${1//\\//}"; shift
  local dir g
  dir="$(cd "$(dirname "$file")" 2>/dev/null && pwd -P)" || return 0
  while :; do
    for g in "$@"; do
      compgen -G "$dir/$g" >/dev/null 2>&1 && { echo "$dir"; return 0; }
    done
    [[ "$dir" == "$OCTOPUS_PROJECT_ROOT" || "$dir" == "/" ]] && return 0
    dir="$(dirname "$dir")"
  done
}
