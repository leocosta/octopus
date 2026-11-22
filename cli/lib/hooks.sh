# hooks.sh — Octopus hooks: the agent hooks (Claude Code & co.) and the git hooks.
#
# Usage:
#   octopus.sh hooks list                     agent hooks and whether each is on
#   octopus.sh hooks disable <id>... [--no-apply]
#   octopus.sh hooks enable <id>...  [--no-apply]
#   octopus.sh hooks status                   git hooks
#   octopus.sh hooks install [--force]
#   octopus.sh hooks uninstall
#
# disable/enable persist the choice in .octopus.yml (disabledHooks:) and re-run
# `octopus setup` so it takes effect; --no-apply only edits the file. Because it
# lives in the manifest, `octopus update` keeps it — the OCTOPUS_DISABLED_HOOKS
# env var alone lasted one setup run.
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

# shellcheck source=cli/lib/ui.sh
source "$HOOKS_LIB_DIR/ui.sh"

# Managed hooks: "<git-hook-name> <script-basename>". One line per installed
# hook — rules-sync deliberately appears twice, git calls it on both events.
_HOOKS_MANAGED="
post-checkout rules-sync
post-merge rules-sync
pre-push pre-push-audit-suggest"

_hooks_usage() {
  echo "Usage: octopus.sh hooks list"
  echo "       octopus.sh hooks disable <id>... [--no-apply]"
  echo "       octopus.sh hooks enable <id>...  [--no-apply]"
  echo "       octopus.sh hooks status"
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
  # Decided from the TARGET REPO, never from where this code happens to be
  # running. The first version asked whether $HOOKS_RELEASE_ROOT was an Octopus
  # tree, which made the answer depend on the caller: run from the working tree
  # it chose the working tree, run from the cache (as `octopus update` does when
  # it re-runs setup) it chose the release. The same repo then got different
  # hooks depending on which entry point touched it last, and this repo ended up
  # with two hooks on the release and one on the working tree.
  #
  # A repo carrying Octopus runs its own copy: a release would shadow the very
  # change under test. Both supported layouts count — the Octopus repo itself,
  # and Octopus vendored at <toplevel>/octopus (the path rules-sync.sh assumes).
  local top candidate
  top="$(git rev-parse --show-toplevel 2>/dev/null)"
  if [[ -n "$top" ]]; then
    for candidate in "$top" "$top/octopus"; do
      if [[ -f "$candidate/cli/octopus.sh" && -d "$candidate/hooks/git" ]]; then
        printf '%s' "$candidate"
        return 0
      fi
    done
  fi
  # A symlink, or the Windows junction install.ps1 makes (Git Bash sees a plain
  # directory there: -L is false).
  if [[ -L "$HOOKS_CACHE_ROOT/current" || -f "$HOOKS_CACHE_ROOT/current/cli/octopus.sh" ]]; then
    printf '%s' "$HOOKS_CACHE_ROOT/current"
    return 0
  fi
  printf '%s' "$HOOKS_RELEASE_ROOT"
}

# ---------------------------------------------------------------------------
# _hooks_portable_root <source-root>
#
# The default cache's `current` link is written as "$HOME/.octopus-cli/current",
# expanded by the shell git runs the hook in. Git Bash, WSL and native shells
# sharing one repo then each resolve their OWN install; a literal /home/u/... or
# /c/Users/u/... path only works in the shell that ran `install` (reproduced:
# hooks installed from WSL failed every `git checkout` made from Git Bash).
# Any other root — a vendored checkout, a custom cache root — is literal. Same
# rule as setup.sh's deliver_hooks, which writes the Claude Code hooks.
# ---------------------------------------------------------------------------
_hooks_portable_root() {
  if [[ -z "${OCTOPUS_CACHE_ROOT:-}${OCTOPUS_CLI_CACHE_ROOT:-}" && "$1" == "$HOME/.octopus-cli/current" ]]; then
    printf '%s' '$HOME/.octopus-cli/current'
  else
    printf '%s' "$1"
  fi
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
# _hooks_check_env_drift
#
# Shared concern with deliver_hooks() in setup.sh: _hooks_wrapper above bakes
# an absolute POSIX path (the source-root) into each wrapper. That path is
# tied to whichever shell ran `install` — a different shell reading the same
# .git/hooks/* later (e.g. native Windows git after installing from WSL)
# can't resolve it, and git's own hook invocation fails before this script
# ever runs, so nothing here can report it after the fact. This is the only
# reliable place to catch the drift — install always runs in a working shell.
# ---------------------------------------------------------------------------
_hooks_check_env_drift() {
  local top env_marker current_env prev_env
  top="$(git rev-parse --show-toplevel 2>/dev/null)" || return 0
  env_marker="$top/.octopus/setup-env"
  current_env="$(_octopus_host_env)"
  prev_env="$(cat "$env_marker" 2>/dev/null || true)"
  if [[ -n "$prev_env" && "$prev_env" != "$current_env" ]]; then
    echo "WARNING: Git hooks were last installed for '$prev_env' and this run is under '$current_env' — wrapper scripts in $DIR now point at $current_env paths. If you also use git from $prev_env against this repo, its hooks will fail until you re-run 'octopus hooks install' from there too."
  fi
  mkdir -p "$(dirname "$env_marker")" && printf '%s' "$current_env" > "$env_marker"
}

# ---------------------------------------------------------------------------
# _hooks_wrapper <script-basename> <source-root>
# ---------------------------------------------------------------------------
_hooks_wrapper() {
  printf '#!/usr/bin/env bash\n'
  printf '# octopus:%s\n' "$1"
  printf 'bash "%s/hooks/git/%s.sh" "$@"\n' "$(_hooks_portable_root "$2")" "$1"
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

# ---------------------------------------------------------------------------
# Agent hooks: list / disable / enable. Handled before the git-repository
# check below — they edit .octopus.yml, not .git/hooks.
# ---------------------------------------------------------------------------
# shellcheck source=cli/lib/hook-catalog.sh
source "$HOOKS_LIB_DIR/hook-catalog.sh"

_agent_manifest() {
  local root
  root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
  printf '%s/.octopus.yml\n' "$root"
}

# The ids .octopus.yml turns off: disabledHooks (inline or block list), plus
# destructive-guard when the older `destructiveGuard: false` is set.
_agent_disabled_ids() {
  python3 - "$1" <<'PYEOF'
import re, sys
off, in_list = [], False
for line in open(sys.argv[1], encoding="utf-8"):
    s = line.rstrip("\r\n")
    m = re.match(r"disabledHooks:\s*\[(.*)\]", s)
    if m:
        off += [x.strip().strip("'\"") for x in m.group(1).split(",") if x.strip()]
        in_list = False
        continue
    if re.match(r"disabledHooks:\s*(#.*)?$", s):
        in_list = True
        continue
    if in_list and re.match(r"\s+-\s*", s):
        off.append(re.sub(r"\s+#.*$", "", s.split("-", 1)[1]).strip().strip("'\""))
        continue
    if re.match(r"[A-Za-z]", s):
        in_list = False
    if re.match(r"destructiveGuard:\s*false\b", s):
        off.append("destructive-guard")
seen = []
for x in off:
    if x and x not in seen:
        seen.append(x)
print("\n".join(seen))
PYEOF
}

# _agent_write_disabled <manifest> <id>... — rewrite disabledHooks: with exactly
# these ids (removed when empty), right after `hooks:` when present. The older
# `destructiveGuard: false` is folded into the list, so the list is the single
# source of truth.
_agent_write_disabled() {
  local manifest="$1"; shift
  python3 - "$manifest" "$@" <<'PYEOF'
import re, sys
path, ids = sys.argv[1], sys.argv[2:]
raw = open(path, encoding="utf-8", newline="").read()
# Keep the file's own line ending, and never let Windows' text mode turn \n
# into \r\n behind our back (setup would then read "typecheck\r").
eol = "\r\n" if "\r\n" in raw else "\n"
lines = raw.replace("\r\n", "\n").split("\n")
out, skip = [], False
for s in lines:
    if skip and re.match(r"\s+-", s):
        continue
    skip = False
    if re.match(r"disabledHooks:\s*\[", s):
        continue
    if re.match(r"disabledHooks:\s*(#.*)?$", s):
        skip = True
        continue
    if re.match(r"destructiveGuard:\s*false\b", s):
        continue
    out.append(s)
block = (["disabledHooks:"] + ["  - " + i for i in ids]) if ids else []
at = next((k + 1 for k, s in enumerate(out) if re.match(r"hooks:\s", s)), None)
if block:
    if at is None:
        while out and out[-1] == "":
            out.pop()
        out += block + [""]
    else:
        out[at:at] = block
open(path, "w", encoding="utf-8", newline="").write(eol.join(out))
PYEOF
}

_agent_hooks_on() { grep -qE '^hooks:[[:space:]]*true\b' "$1"; }

_agent_list() {
  local manifest off g id desc last="" state
  manifest="$(_agent_manifest)"
  if [[ ! -f "$manifest" ]]; then
    echo "No .octopus.yml here — run 'octopus setup' first." >&2
    return 2
  fi
  off="$(_agent_disabled_ids "$manifest")"
  if _agent_hooks_on "$manifest"; then
    echo "Agent hooks (.octopus.yml: hooks: true)"
  else
    echo "Agent hooks — OFF for this repo: none of these run."
    echo "Turn them on with 'hooks: true' in .octopus.yml, then 'octopus setup'."
  fi
  while IFS=$'\t' read -r g id desc; do
    [[ -n "$id" ]] || continue
    if [[ "$g" != "$last" ]]; then
      echo ""
      echo "  $(hook_catalog_group_title "$g")"
      last="$g"
    fi
    state="on "
    grep -qxF -- "$id" <<<"$off" && state="off"
    printf '    %s  %-26s %s\n' "$state" "$id" "$desc"
  done < <(hook_catalog_rows)
  echo ""
  echo "Turn one off: octopus hooks disable <id>   ·   back on: octopus hooks enable <id>"
}

# _agent_toggle disable|enable <id>... [--no-apply]
_agent_toggle() {
  local action="$1"; shift
  local apply=1 ids=() id manifest off new=()
  for id in "$@"; do
    case "$id" in
      --no-apply) apply=0 ;;
      -*) echo "hooks $action: unknown option '$id'" >&2; return 2 ;;
      *) ids+=("$id") ;;
    esac
  done
  if [[ ${#ids[@]} -eq 0 ]]; then
    echo "Usage: octopus hooks $action <id>... (see 'octopus hooks list')" >&2
    return 2
  fi
  for id in "${ids[@]}"; do
    hook_catalog_known "$id" || { echo "hooks: unknown hook '$id' — see 'octopus hooks list'" >&2; return 2; }
  done
  manifest="$(_agent_manifest)"
  [[ -f "$manifest" ]] || { echo "No .octopus.yml here — run 'octopus setup' first." >&2; return 2; }

  off="$(_agent_disabled_ids "$manifest")"
  while IFS= read -r id; do
    [[ -n "$id" ]] || continue
    if [[ "$action" == "enable" ]] && printf '%s\n' "${ids[@]}" | grep -qxF -- "$id"; then
      continue
    fi
    new+=("$id")
  done <<<"$off"
  if [[ "$action" == "disable" ]]; then
    for id in "${ids[@]}"; do
      printf '%s\n' "${new[@]+"${new[@]}"}" | grep -qxF -- "$id" || new+=("$id")
    done
  fi
  _agent_write_disabled "$manifest" "${new[@]+"${new[@]}"}" || return 2
  if [[ "$action" == "disable" ]]; then
    echo "Disabled: ${ids[*]} (saved in .octopus.yml)"
  else
    echo "Enabled: ${ids[*]} (saved in .octopus.yml)"
  fi
  _agent_hooks_on "$manifest" \
    || echo "Note: hooks are off for this repo (no 'hooks: true') — nothing runs until it is set."

  if [[ $apply -eq 1 ]]; then
    echo "Applying with 'octopus setup'..."
    (cd "$(dirname "$manifest")" && bash "$HOOKS_LIB_DIR/../octopus.sh" setup) || return $?
  else
    echo "Run 'octopus setup' to apply."
  fi
}

case "$SUB" in
  list)    _agent_list; exit $? ;;
  disable) _agent_toggle disable "$@"; exit $? ;;
  enable)  _agent_toggle enable "$@"; exit $? ;;
esac

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
    # A $HOME-relative wrapper resolves in every shell — there is no drift to warn about.
    [[ "$DRY" == "true" || "$(_hooks_portable_root "$ROOT")" != "$ROOT" ]] || _hooks_check_env_drift
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
