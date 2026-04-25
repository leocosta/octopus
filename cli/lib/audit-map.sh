#!/usr/bin/env bash
# cli/lib/audit-map.sh — Map a unified diff to relevant Octopus audit skill names.
#
# Public API:
#   audit_map_match <audit-name> <diff-file>  → exit 0 if matched, 1 otherwise
#   audit_map_all   <diff-file>               → emit matched audit names, one per line
#
# Sourced by pre-push-audit-suggest.sh and callable from tests.

AUDIT_MAP_OCTOPUS_DIR="${AUDIT_MAP_OCTOPUS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# Ordered output list (criticality order per spec).
readonly _AUDIT_ORDER=( audit-security audit-money audit-tenant review-contracts )

# ---------------------------------------------------------------------------
# _audit_map_resolve_patterns <audit-name>
# Prints the path to the resolved patterns.md file, or nothing on miss.
# Cascade: docs/<name>/patterns.md → skills/<name>/templates/patterns.md
# ---------------------------------------------------------------------------
_audit_map_resolve_patterns() {
  local name="$1"
  local root="$AUDIT_MAP_OCTOPUS_DIR"

  local candidates=(
    "$root/docs/${name}/patterns.md"
    "$root/skills/${name}/templates/patterns.md"
  )
  for f in "${candidates[@]}"; do
    if [[ -f "$f" ]]; then
      echo "$f"
      return 0
    fi
  done
  return 1
}

# ---------------------------------------------------------------------------
# _audit_map_path_tokens <patterns-file>
# Emits one path token per line from the "## Path tokens" section.
# ---------------------------------------------------------------------------
_audit_map_path_tokens() {
  local file="$1"
  awk '
    /^## Path tokens/ { in_section=1; next }
    /^## /            { in_section=0 }
    in_section        { gsub(/[,]/, "\n"); print }
  ' "$file" | tr -s '[:space:]' '\n' | grep -v '^$'
}

# ---------------------------------------------------------------------------
# _audit_map_content_regexes <patterns-file>
# Emits one ERE regex per line from the "## Content regex" section.
# Strips the markdown bullet prefix and backtick wrappers.
# ---------------------------------------------------------------------------
_audit_map_content_regexes() {
  local file="$1"
  awk '
    /^## Content regex/ { in_section=1; next }
    /^## /              { in_section=0 }
    in_section && /^[[:space:]]*-/ { print }
  ' "$file" | sed 's/^[[:space:]]*-[[:space:]]*//' \
            | sed 's/^`//; s/`.*$//'
}

# ---------------------------------------------------------------------------
# _audit_map_match_patterns <audit-name> <diff-file>
# Returns 0 if path tokens or content regexes hit the diff.
# ---------------------------------------------------------------------------
_audit_map_match_patterns() {
  local name="$1"
  local diff_file="$2"

  local patterns_file
  patterns_file="$(_audit_map_resolve_patterns "$name")" || {
    echo "octopus:audit-map: WARNING: no patterns.md found for '$name' — skipping." >&2
    return 1
  }

  # Extract changed file paths from diff (--- and +++ lines).
  local changed_paths
  changed_paths=$(grep -E '^(\+\+\+|---) ' "$diff_file" | sed 's|^[+-][+-][+-] [ab]/||')

  # Test path tokens first (fast filter).
  while IFS= read -r token; do
    [[ -z "$token" ]] && continue
    if echo "$changed_paths" | grep -qi "$token"; then
      return 0
    fi
  done < <(_audit_map_path_tokens "$patterns_file")

  # Test content regexes against added/removed lines.
  local diff_content
  diff_content=$(grep -E '^[+-]' "$diff_file" | grep -v '^[+-][+-][+-]')

  while IFS= read -r regex; do
    [[ -z "$regex" ]] && continue
    if echo "$diff_content" | grep -qE "$regex"; then
      return 0
    fi
  done < <(_audit_map_content_regexes "$patterns_file")

  return 1
}

# ---------------------------------------------------------------------------
# _audit_map_match_cross_stack <diff-file>
# Fires when diff touches paths belonging to 2+ stacks in .octopus.yml stacks:.
# ---------------------------------------------------------------------------
_audit_map_match_cross_stack() {
  local diff_file="$1"
  local manifest="$AUDIT_MAP_OCTOPUS_DIR/.octopus.yml"

  [[ -f "$manifest" ]] || return 1

  # Extract stacks: map (simple key: path/prefix lines under "stacks:").
  local -a stack_paths=()
  local in_stacks=0
  while IFS= read -r line; do
    if [[ "$line" =~ ^stacks: ]]; then
      in_stacks=1
      continue
    fi
    if (( in_stacks )); then
      [[ "$line" =~ ^[^[:space:]] && ! "$line" =~ ^stacks: ]] && break
      if [[ "$line" =~ ^[[:space:]]+[a-zA-Z_-]+:[[:space:]]*(.+) ]]; then
        stack_paths+=("${BASH_REMATCH[1]}")
      fi
    fi
  done < "$manifest"

  [[ ${#stack_paths[@]} -lt 2 ]] && return 1

  local changed_paths
  changed_paths=$(grep -E '^(\+\+\+|---) ' "$diff_file" | sed 's|^[+-][+-][+-] [ab]/||')

  local hits=0
  for prefix in "${stack_paths[@]}"; do
    prefix="${prefix%/}"
    if echo "$changed_paths" | grep -q "^${prefix}"; then
      (( hits++ ))
    fi
    (( hits >= 2 )) && return 0
  done

  return 1
}

# ---------------------------------------------------------------------------
# audit_map_match <audit-name> <diff-file>
# Public: returns 0 if the audit fires for this diff, 1 otherwise.
# ---------------------------------------------------------------------------
audit_map_match() {
  local name="$1"
  local diff_file="$2"

  if [[ "$name" == "review-contracts" ]]; then
    _audit_map_match_cross_stack "$diff_file"
  else
    _audit_map_match_patterns "$name" "$diff_file"
  fi
}

# ---------------------------------------------------------------------------
# audit_map_all <diff-file>
# Public: emits matched audit names one per line, in criticality order.
# ---------------------------------------------------------------------------
audit_map_all() {
  local diff_file="$1"
  for name in "${_AUDIT_ORDER[@]}"; do
    if audit_map_match "$name" "$diff_file"; then
      echo "$name"
    fi
  done
}
