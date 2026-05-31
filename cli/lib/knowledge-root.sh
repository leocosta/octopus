#!/usr/bin/env bash
# cli/lib/knowledge-root.sh — knowledge-root registry loader (RM-106).
#
# Sourced by cli/lib/kr.sh. Parses the built-in defaults, resolves each root's
# path, and drops roots whose path is unset or absent. Override merging and the
# ADR-009 guard are layered on in later tasks.
#
# Engines (RM-107…109) never read these paths directly — only via `octopus kr`.

KR_LIB_DIR="${KR_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
KR_DEFAULTS="${KR_DEFAULTS:-$KR_LIB_DIR/knowledge-roots.default}"
# The repo where `octopus` was invoked; repo-relative roots resolve against it.
KR_PROJECT_ROOT="${KR_PROJECT_ROOT:-$PWD}"

# Resolve a declared path to an absolute path, or empty if unresolvable.
#   $VAR        → value from user config (env for now); empty if unset
#   /abs        → as-is
#   repo/rel    → $KR_PROJECT_ROOT/repo/rel
kr_expand_path() {
  local p="$1"
  case "$p" in
    '$OCTOPUS_MEMORY_DIR')    printf '%s' "${OCTOPUS_MEMORY_DIR:-}" ;;
    '$CONSIGLIERE_WORKSPACE') printf '%s' "${CONSIGLIERE_WORKSPACE:-}" ;;
    /*)                       printf '%s' "$p" ;;
    *)                        printf '%s/%s' "$KR_PROJECT_ROOT" "$p" ;;
  esac
}

# Emit one resolved line per present root:
#   id|abs_path|link_convention|archive_dir|staleness_days|lens_profile|write_policy
kr_load() {
  awk -F'|' '/^[^#]/ && NF>=2' "$KR_DEFAULTS" \
  | while IFS='|' read -r id path conv archive days lens policy; do
      local resolved; resolved="$(kr_expand_path "$path")"
      [[ -n "$resolved" && -e "$resolved" ]] || continue
      printf '%s|%s|%s|%s|%s|%s|%s\n' \
        "$id" "$resolved" "$conv" "$archive" "$days" "$lens" "$policy"
    done
}
