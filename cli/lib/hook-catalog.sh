# hook-catalog.sh — the agent hooks Octopus delivers, grouped for humans.
#
# Sourced by the setup picker and by `octopus hooks list|disable|enable`. The
# ids come from hooks/hooks.json — the file setup installs from — so the
# catalog can never list a hook that does not exist or miss a new one; a new id
# without a group below lands in "other" until it is classified.
#
# Groups, in the order a person deciding what to switch off cares about:
#   guards   block a tool call (exit 2): turning one off removes a protection
#   edits    run after Write/Edit, or advise on a command; never block
#   session  load/save context and review signals at session boundaries
#
# bash 3.2 compatible: no associative arrays.

_HOOK_CATALOG_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_HOOK_CATALOG_JSON="${OCTOPUS_HOOKS_JSON:-$_HOOK_CATALOG_DIR/../../hooks/hooks.json}"

# Delivered, but specific to the Octopus documentation site — never offered in
# user-facing lists (it is a no-op elsewhere). Still accepted by disable/enable.
_HOOK_CATALOG_INTERNAL=" mark-stale-translation "

# hook_catalog_ids — every hook id in hooks.json, in file order, de-duplicated.
hook_catalog_ids() {
  [[ -f "$_HOOK_CATALOG_JSON" ]] || return 0
  grep -o '"id":[[:space:]]*"[^"]*"' "$_HOOK_CATALOG_JSON" \
    | sed 's/.*"\([^"]*\)"$/\1/' | awk '!seen[$0]++'
}

# hook_catalog_visible_ids — the ids offered to users (internal ones hidden).
hook_catalog_visible_ids() {
  local id
  while IFS= read -r id; do
    [[ -n "$id" && "$_HOOK_CATALOG_INTERNAL" != *" $id "* ]] && printf '%s\n' "$id"
  done < <(hook_catalog_ids)
}

# hook_catalog_known <id> — 0 when <id> is a delivered hook.
hook_catalog_known() {
  local id
  while IFS= read -r id; do [[ "$id" == "$1" ]] && return 0; done < <(hook_catalog_ids)
  return 1
}

hook_catalog_group() {
  case "$1" in
    destructive-guard|detect-secrets|block-no-verify) echo guards ;;
    git-push-reminder|format-check|auto-format|typecheck|console-log-warn|console-log-check|mark-stale-translation) echo edits ;;
    load-context|save-state|reload-context|propose-knowledge-update|grounding-check|verification-check|review-log-capture|session-end|lifecycle-marker) echo session ;;
    *) echo other ;;
  esac
}

hook_catalog_group_title() {
  case "$1" in
    guards)  echo "Guards — block the tool call" ;;
    edits)   echo "Edit automation & advisories — never block" ;;
    session) echo "Session & context" ;;
    *)       echo "Other" ;;
  esac
}

hook_catalog_desc() {
  case "$1" in
    destructive-guard)        echo "blocks rm -rf, force-push, DROP TABLE, curl | bash …" ;;
    detect-secrets)           echo "blocks a commit whose staged files hold an API key or token" ;;
    block-no-verify)          echo "blocks commands that skip git hooks (--no-verify, -n, hooksPath)" ;;
    git-push-reminder)        echo "reminds to review the diff before git push" ;;
    format-check)             echo "notes design docs written outside docs/" ;;
    auto-format)              echo "runs the project formatter after each edit" ;;
    typecheck)                echo "runs the type checker / build after each edit" ;;
    console-log-warn)         echo "warns when debug output lands in a non-test file" ;;
    console-log-check)        echo "final sweep for debug output at the end of a turn" ;;
    load-context)             echo "loads the previous session's context at startup" ;;
    save-state)               echo "saves working state before context compaction" ;;
    reload-context)           echo "restores that state after compaction" ;;
    propose-knowledge-update) echo "queues knowledge updates from corrections in the session" ;;
    grounding-check)          echo "queues a grounding review when a turn ends with uncommitted changes" ;;
    verification-check)       echo "queues a verification review when code changed without a test run" ;;
    review-log-capture)       echo "logs review findings from the session for the team" ;;
    session-end)              echo "saves session state for recovery" ;;
    lifecycle-marker)         echo "marks session boundaries in the lifecycle log" ;;
    mark-stale-translation)   echo "Octopus docs site only" ;;
    *)                        echo "" ;;
  esac
}

# hook_catalog_rows — "group<TAB>id<TAB>description", visible hooks only,
# grouped in display order (guards, edits, session, other).
hook_catalog_rows() {
  local g id
  for g in guards edits session other; do
    while IFS= read -r id; do
      [[ -n "$id" && "$(hook_catalog_group "$id")" == "$g" ]] || continue
      printf '%s\t%s\t%s\n' "$g" "$id" "$(hook_catalog_desc "$id")"
    done < <(hook_catalog_visible_ids)
  done
}
