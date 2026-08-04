#!/usr/bin/env bash
# cli/lib/audit-prepass.sh — Deterministic file discovery for audit-* skills.
#
# Compiles the protocol previously described in skills/_shared/audit-pre-pass.md
# (RM-172). Semantics are ported verbatim: the candidate set produced here must
# equal the set the prose pipeline produced.
#
# Public API:
#   audit_prepass_file_patterns <skill>              → prints the resolved regex
#   audit_prepass_line_patterns <skill>              → prints the resolved regex (may be empty)
#   audit_prepass_candidates <skill> <base> [ref]    → prints candidate paths, one per line
#                                                      exit 1 = empty set (early exit)
#                                                      exit 2 = skill/pattern not resolvable
#   audit_prepass_diff <skill> <base> [ref]          → prints the scoped diff block
#                                                      exit 1 = early exit, nothing to review
#
# Sourced by the review orchestrator, by audit-* skills invoked standalone, and
# from tests. Sourcing has no side effects.

AUDIT_PREPASS_OCTOPUS_DIR="${AUDIT_PREPASS_OCTOPUS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# ---------------------------------------------------------------------------
# _audit_prepass_unquote <raw-yaml-scalar>
# Strips surrounding quotes and applies the YAML double-quoted escapes that the
# skill frontmatter actually uses. This matters: audit-security declares
# "…|\\.env" and audit-money declares "…|\\bdecimal\\b" — the regex the pipeline
# must run is \.env and \bdecimal\b, not the literal two-character \\ sequence.
# ---------------------------------------------------------------------------
_audit_prepass_unquote() {
  local v="$1"

  # Trim trailing whitespace.
  v="${v%"${v##*[![:space:]]}"}"

  if [[ ${#v} -ge 2 && ${v:0:1} == '"' && ${v: -1} == '"' ]]; then
    v="${v:1:${#v}-2}"
    v="${v//\\\"/\"}"
    v="${v//\\\\/\\}"
  elif [[ ${#v} -ge 2 && ${v:0:1} == "'" && ${v: -1} == "'" ]]; then
    v="${v:1:${#v}-2}"
    v="${v//\'\'/\'}"
  fi

  printf '%s' "$v"
}

# ---------------------------------------------------------------------------
# _audit_prepass_field <skill> <field>
# Reads pre_pass.<field> from skills/<skill>/SKILL.md frontmatter.
# The flat .octopus.yml reader is deliberately not reused — this block is nested.
# ---------------------------------------------------------------------------
_audit_prepass_field() {
  local skill="$1" field="$2"
  local file="$AUDIT_PREPASS_OCTOPUS_DIR/skills/${skill}/SKILL.md"

  [[ -f "$file" ]] || return 2

  local raw
  raw="$(
    awk -v field="$field" '
      NR == 1 && $0 !~ /^---[[:space:]]*$/ { exit }
      NR > 1 && /^---[[:space:]]*$/ { exit }
      /^pre_pass:[[:space:]]*$/ { inblock = 1; next }
      inblock && /^[^[:space:]#]/ { inblock = 0 }
      inblock {
        line = $0
        sub(/^[[:space:]]+/, "", line)
        if (index(line, field ":") == 1) {
          val = substr(line, length(field) + 2)
          sub(/^[[:space:]]+/, "", val)
          print val
          exit
        }
      }
    ' "$file"
  )"

  [[ -n "$raw" ]] || return 1
  _audit_prepass_unquote "$raw"
}

audit_prepass_file_patterns() {
  _audit_prepass_field "$1" "file_patterns"
}

audit_prepass_line_patterns() {
  # A missing line_patterns is legal — the filter is optional.
  _audit_prepass_field "$1" "line_patterns" || return 0
}

# ---------------------------------------------------------------------------
# audit_prepass_candidates <skill> <base> [ref]
# ---------------------------------------------------------------------------
audit_prepass_candidates() {
  local skill="$1" base="$2" ref="${3:-HEAD}"
  local file_patterns line_patterns

  file_patterns="$(audit_prepass_file_patterns "$skill")" || return 2
  [[ -n "$file_patterns" ]] || return 2

  local files
  files="$(git diff --name-only "${base}..${ref}" | grep -E "$file_patterns" || true)"
  [[ -n "$files" ]] || return 1

  line_patterns="$(audit_prepass_line_patterns "$skill")"
  if [[ -n "$line_patterns" ]]; then
    local kept="" f
    while IFS= read -r f; do
      [[ -n "$f" ]] || continue
      # Parity note (RM-172): the prose protocol greps '^+' over the raw diff,
      # which also sees the '+++ b/<path>' file header. Kept verbatim — changing
      # it would alter audit semantics, which this change explicitly does not do.
      if git diff "${base}..${ref}" -- "$f" | grep -E "^\+" | grep -qE "$line_patterns"; then
        kept+="${f}"$'\n'
      fi
    done <<< "$files"
    files="${kept%$'\n'}"
  fi

  [[ -n "$files" ]] || return 1
  printf '%s\n' "$files"
}

# ---------------------------------------------------------------------------
# audit_prepass_diff <skill> <base> [ref]
# Emits the block that replaces the full diff in the sub-agent prompt.
# ---------------------------------------------------------------------------
audit_prepass_diff() {
  local skill="$1" base="$2" ref="${3:-HEAD}"
  local files rc

  files="$(audit_prepass_candidates "$skill" "$base" "$ref")" || {
    rc=$?
    return "$rc"
  }

  printf '## Scoped files\n%s\n\n' "$files"
  # shellcheck disable=SC2086 — paths are intentionally word-split into args.
  git diff "${base}..${ref}" -- $(printf '%s ' $files)
}
