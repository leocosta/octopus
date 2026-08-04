# review-anchor.sh — Verify that review findings cite real, changed code.
#
# Usage:
#   octopus.sh review-anchor [--base <ref>] [--ref <ref>] [--file <findings>]
#   ... | octopus.sh review-anchor --base main --ref HEAD
#
# RM-170. Reads finding lines (stdin by default), resolves each <path>:<line>
# citation against the diff, and reports a verdict per finding plus a summary.
# Never rewrites the report — the caller decides what to demote.
#
# Verdicts: anchored | not-in-diff | line-out-of-range | missing-file | no-anchor
#
# Exit status:
#   0  every finding that carries an anchor is anchored
#   1  at least one finding failed to anchor (the caller should demote those)
#   2  usage or repository error

# See the note in audit-scope.sh: `cli/octopus.sh` sources this with -e active.
# A finding line with no citation makes `anchor_extract`'s grep return 1, which
# under -e would abort mid-report instead of recording `no-anchor`.
set +e
set -uo pipefail

REVIEW_ANCHOR_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./anchor-verify.sh
source "$REVIEW_ANCHOR_LIB_DIR/anchor-verify.sh"

BASE="main"
REF="HEAD"
FINDINGS_FILE=""
QUIET=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --file) FINDINGS_FILE="${2:-}"; shift 2 ;;
    --quiet) QUIET=1; shift ;;
    -h|--help)
      echo "Usage: octopus.sh review-anchor [--base <ref>] [--ref <ref>] [--file <findings>]"
      exit 0 ;;
    *)
      echo "review-anchor: unknown argument '$1'" >&2
      exit 2 ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "review-anchor: not a git repository" >&2
  exit 2
fi

input="$(mktemp)"
trap 'rm -f "$input"' EXIT

if [[ -n "$FINDINGS_FILE" ]]; then
  if [[ ! -f "$FINDINGS_FILE" ]]; then
    echo "review-anchor: no such file: $FINDINGS_FILE" >&2
    exit 2
  fi
  cat "$FINDINGS_FILE" > "$input"
else
  cat > "$input"
fi

annotated="$(anchor_annotate_stream "$BASE" "$REF" < "$input")"

# `not-in-diff` is counted on its own and does NOT drive the exit status: a
# finding about pre-existing code reached through the diff is legitimate. Only
# locations that cannot exist — missing-file, line-out-of-range — are failures.
anchored=0; not_in_diff=0; failed=0; unanchored=0
while IFS= read -r row; do
  [[ -z "${row//[[:space:]]/}" ]] && continue
  case "${row%%$'\t'*}" in
    anchored) anchored=$((anchored + 1)) ;;
    not-in-diff) not_in_diff=$((not_in_diff + 1)) ;;
    no-anchor) unanchored=$((unanchored + 1)) ;;
    *) failed=$((failed + 1)) ;;
  esac
done <<< "$annotated"

if [[ -z "$QUIET" ]]; then
  printf '%s\n' "$annotated"
  echo ""
  echo "OCTOPUS_ANCHOR_SUMMARY anchored=$anchored not-in-diff=$not_in_diff failed=$failed no-anchor=$unanchored"
fi

[[ $failed -eq 0 ]]
