#!/usr/bin/env bash
# cli/lib/anchor-verify.sh — Prove that a review finding points at real, changed code.
#
# RM-170. A finding cites <path>:<line> written by the model; nothing checked it.
# This resolves the citation against the diff, deterministically, before the
# report is printed or posted.
#
# Public API:
#   anchor_changed_lines <base> <ref> <path>        → post-image line numbers, one per line
#   anchor_verify <base> <ref> <path> <line>        → prints a verdict, always exit 0
#   anchor_extract <text>                           → prints "path<TAB>line" or nothing
#   anchor_annotate_stream <base> <ref>             → reads stdin, prints "verdict<TAB>line"
#
# Verdicts:
#   anchored           the line exists at <ref> and this diff touched it
#   not-in-diff        the line exists but the change did not touch it
#   line-out-of-range  the file exists but has fewer lines (or line < 1)
#   missing-file       no such file at <ref>
#   no-anchor          the text carries no <path>:<line> citation
#
# Sourced by cli/lib/review-anchor.sh and from tests. No side effects on source.

ANCHOR_VERIFY_OCTOPUS_DIR="${ANCHOR_VERIFY_OCTOPUS_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"

# ---------------------------------------------------------------------------
# anchor_changed_lines <base> <ref> <path>
# Post-image line numbers touched by the diff. Uses -U0 so the answer is the
# changed lines themselves, not their context.
# ---------------------------------------------------------------------------
anchor_changed_lines() {
  local base="$1" ref="$2" path="$3"

  git diff -U0 "${base}..${ref}" -- "$path" 2>/dev/null | awk '
    /^@@/ {
      # @@ -old,oldcount +new,newcount @@
      match($0, /\+[0-9]+(,[0-9]+)?/)
      spec = substr($0, RSTART + 1, RLENGTH - 1)
      split(spec, parts, ",")
      start = parts[1] + 0
      count = (length(parts) > 1) ? parts[2] + 0 : 1
      # count == 0 is a pure deletion: no post-image line to anchor to.
      for (i = 0; i < count; i++) print start + i
    }
  '
}

# ---------------------------------------------------------------------------
# anchor_verify <base> <ref> <path> <line>
# ---------------------------------------------------------------------------
anchor_verify() {
  local base="$1" ref="$2" path="$3" line="$4"

  if ! [[ "$line" =~ ^[0-9]+$ ]] || [[ "$line" -lt 1 ]]; then
    echo "line-out-of-range"
    return 0
  fi

  if ! git cat-file -e "${ref}:${path}" 2>/dev/null; then
    echo "missing-file"
    return 0
  fi

  local total
  total="$(git show "${ref}:${path}" 2>/dev/null | wc -l)"
  if [[ "$line" -gt "$total" ]]; then
    echo "line-out-of-range"
    return 0
  fi

  if anchor_changed_lines "$base" "$ref" "$path" | grep -qx "$line"; then
    echo "anchored"
  else
    echo "not-in-diff"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# anchor_extract <text>
# Pulls the first <path>:<line> citation out of a finding line.
# Paths are matched conservatively — a token containing a dot or a slash, so
# prose like "see line 12:" or a bare "TODO:" does not read as an anchor.
# ---------------------------------------------------------------------------
anchor_extract() {
  local text="$1"

  printf '%s\n' "$text" | grep -oE '[A-Za-z0-9_][A-Za-z0-9._/+-]*[/.][A-Za-z0-9._/+-]*:[0-9]+' \
    | head -1 \
    | awk -F: '{ printf "%s\t%s\n", $1, $2 }'
}

# ---------------------------------------------------------------------------
# anchor_annotate_stream <base> <ref>
# Reads finding lines on stdin, prints "<verdict>\t<original line>".
# Blank lines pass through untouched so report formatting survives.
# ---------------------------------------------------------------------------
anchor_annotate_stream() {
  local base="$1" ref="$2"
  local raw anchor path line verdict

  while IFS= read -r raw; do
    if [[ -z "${raw//[[:space:]]/}" ]]; then
      printf '\n'
      continue
    fi

    anchor="$(anchor_extract "$raw")"
    if [[ -z "$anchor" ]]; then
      printf 'no-anchor\t%s\n' "$raw"
      continue
    fi

    path="${anchor%%$'\t'*}"
    line="${anchor##*$'\t'}"
    verdict="$(anchor_verify "$base" "$ref" "$path" "$line")"
    printf '%s\t%s\n' "$verdict" "$raw"
  done
}
