# hooks.sh — Install, inspect and remove Octopus git hooks.
#
# Usage:
#   octopus.sh hooks status
#   octopus.sh hooks install [--force]
#   octopus.sh hooks uninstall
#
# Octopus ships three git hooks (hooks/git/), and until now nothing installed or
# refreshed them. `post-checkout` and `post-merge` had been wired as three-line
# wrappers delegating to an absolute path, so they self-update; `pre-push` had
# been copied INLINE, froze at the version that copied it, and no command in the
# CLI could refresh it. Every hook fix since then shipped to main and reached
# nobody.
#
# The wrapper points at $HOME/.octopus-cli/current — the symlink `octopus
# update` re-points — and never at the versioned cache directory behind it. A
# wrapper naming a version is the bug this command exists to remove.
#
# Ownership is by marker: a hook carrying `# octopus:<name>` is ours to rewrite,
# anything else is left alone and reported.
#
# Exit status:
#   0  ok
#   1  status found something to fix (nothing was changed)
#   2  usage or repository error

# See the note in audit-scope.sh: `cli/octopus.sh` sources this with -e active.
# `status` returning 1 is a routine outcome, not a failure.
set +e
set -uo pipefail

HOOKS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOKS_RELEASE_ROOT="${HOOKS_RELEASE_ROOT:-$(cd "$HOOKS_LIB_DIR/../.." && pwd)}"
HOOKS_CACHE_ROOT="${OCTOPUS_CACHE_ROOT:-$HOME/.octopus-cli}"

# Managed hooks: "<git-hook-name> <script-basename>". One line per installed
# hook — rules-sync deliberately appears twice, git calls it on both events.
_HOOKS_MANAGED="
post-checkout rules-sync
post-merge rules-sync
pre-push pre-push-audit-suggest"

_hooks_usage() {
  echo "Usage: octopus.sh hooks status"
  echo "       octopus.sh hooks install [--force]"
  echo "       octopus.sh hooks uninstall"
}

# ---------------------------------------------------------------------------
# _hooks_source_root
#
# Where the wrapper should point. Mirrors bin/octopus's resolution order, with
# one difference that is the entire point of this command: the cached release is
# named through the `current` symlink, never through the versioned directory it
# resolves to, so `octopus update` moves every installed hook at once.
# ---------------------------------------------------------------------------
_hooks_source_root() {
  # A repo carrying Octopus itself (this repo, or a submodule checkout) runs its
  # own working tree — a released copy would shadow the change under test.
  if [[ -f "$HOOKS_RELEASE_ROOT/cli/octopus.sh" && -d "$HOOKS_RELEASE_ROOT/hooks/git" \
        && "$HOOKS_RELEASE_ROOT" != "$HOOKS_CACHE_ROOT"/* ]]; then
    printf '%s' "$HOOKS_RELEASE_ROOT"
    return 0
  fi
  if [[ -L "$HOOKS_CACHE_ROOT/current" ]]; then
    printf '%s' "$HOOKS_CACHE_ROOT/current"
    return 0
  fi
  printf '%s' "$HOOKS_RELEASE_ROOT"
}

# ---------------------------------------------------------------------------
# _hooks_dir — where git actually looks, honouring core.hooksPath and worktrees.
# ---------------------------------------------------------------------------
_hooks_dir() {
  local configured
  configured="$(git config --get core.hooksPath 2>/dev/null)"
  if [[ -n "$configured" ]]; then
    # A relative hooksPath is relative to the top level, not to $PWD.
    if [[ "$configured" = /* ]]; then
      printf '%s' "$configured"
    else
      printf '%s/%s' "$(git rev-parse --show-toplevel)" "$configured"
    fi
    return 0
  fi
  printf '%s' "$(git rev-parse --git-path hooks)"
}

# ---------------------------------------------------------------------------
# _hooks_wrapper <script-basename> <source-root>
# ---------------------------------------------------------------------------
_hooks_wrapper() {
  printf '#!/usr/bin/env bash\n'
  printf '# octopus:%s\n' "$1"
  printf 'bash "%s/hooks/git/%s.sh" "$@"\n' "$2" "$1"
}

# ---------------------------------------------------------------------------
# _hooks_state <hook-path> <script-basename> <source-root>
#
#   missing  no file there
#   ok       ours, and already the wrapper we would write
#   stale    ours, but different — an inline copy, or naming an old path
#   foreign  a hook we did not write; never touched
# ---------------------------------------------------------------------------
_hooks_state() {
  local path="$1" script="$2" root="$3"

  [[ -e "$path" ]] || { echo "missing"; return 0; }
  grep -q "^# octopus:${script}\$" "$path" 2>/dev/null || { echo "foreign"; return 0; }

  if [[ "$(cat "$path")" == "$(_hooks_wrapper "$script" "$root")" ]]; then
    echo "ok"
  else
    echo "stale"
  fi
}

SUB="${1:-}"
shift 2>/dev/null || true

FORCE=""
SKIP=""
DRY="${OCTOPUS_DRY_RUN:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1; shift ;;
    --skip) SKIP="${SKIP} ${2:-}"; shift 2 ;;
    --dry-run) DRY="true"; shift ;;
    -h|--help) _hooks_usage; exit 0 ;;
    *) echo "hooks: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# `setup` gates the audit hook on the repo actually having an audit skill, so it
# needs a way to manage two of the three.
_hooks_skipped() { [[ " ${SKIP} " == *" $1 "* ]]; }

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "hooks: not a git repository" >&2
  exit 2
fi

ROOT="$(_hooks_source_root)"
DIR="$(_hooks_dir)"

case "$SUB" in
  status)
    needs_work=0
    printf 'source: %s\n' "$ROOT"
    printf 'hooks:  %s\n\n' "$DIR"
    while read -r name script; do
      [[ -z "$name" ]] && continue
      state="$(_hooks_state "$DIR/$name" "$script" "$ROOT")"
      printf '%-14s %-8s %s\n' "$name" "$state" "$script"
      [[ "$state" == "ok" ]] || needs_work=1
    done <<< "$_HOOKS_MANAGED"
    [[ $needs_work -eq 0 ]] || echo ""
    [[ $needs_work -eq 0 ]] || echo "Run 'octopus hooks install' to fix."
    exit $needs_work
    ;;

  install)
    mkdir -p "$DIR" || { echo "hooks: cannot create $DIR" >&2; exit 2; }
    changed=0
    while read -r name script; do
      [[ -z "$name" ]] && continue
      if _hooks_skipped "$name"; then
        printf '%-14s skipped\n' "$name"
        continue
      fi
      path="$DIR/$name"
      state="$(_hooks_state "$path" "$script" "$ROOT")"

      if [[ "$DRY" == "true" && "$state" != "ok" ]]; then
        printf '%-14s would be %s\n' "$name" \
          "$([[ "$state" == "foreign" ]] && echo "left alone (not ours)" || echo "written")"
        continue
      fi

      case "$state" in
        ok)
          printf '%-14s unchanged\n' "$name" ;;
        foreign)
          if [[ -n "$FORCE" ]]; then
            _hooks_wrapper "$script" "$ROOT" > "$path" && chmod +x "$path"
            printf '%-14s replaced (was not ours; --force)\n' "$name"
            changed=1
          else
            # Never clobber someone else's hook. Appending is not safe either —
            # an existing hook may exit before reaching the appended line.
            printf '%-14s SKIPPED — not an Octopus hook. Delegate manually or re-run with --force:\n' "$name"
            printf '               bash "%s/hooks/git/%s.sh" "$@"\n' "$ROOT" "$script"
          fi ;;
        *)
          _hooks_wrapper "$script" "$ROOT" > "$path" && chmod +x "$path"
          printf '%-14s %s\n' "$name" "$([[ "$state" == "missing" ]] && echo installed || echo updated)"
          changed=1 ;;
      esac
    done <<< "$_HOOKS_MANAGED"

    [[ $changed -eq 1 ]] && echo "" && echo "Hooks point at $ROOT — 'octopus update' moves them with it."
    exit 0
    ;;

  uninstall)
    while read -r name script; do
      [[ -z "$name" ]] && continue
      path="$DIR/$name"
      state="$(_hooks_state "$path" "$script" "$ROOT")"
      case "$state" in
        missing) printf '%-14s absent\n' "$name" ;;
        foreign) printf '%-14s left alone (not ours)\n' "$name" ;;
        *)       rm -f "$path" && printf '%-14s removed\n' "$name" ;;
      esac
    done <<< "$_HOOKS_MANAGED"
    exit 0
    ;;

  ""|-h|--help)
    _hooks_usage
    exit 2 ;;
  *)
    echo "hooks: unknown subcommand '$SUB'" >&2
    _hooks_usage >&2
    exit 2 ;;
esac
