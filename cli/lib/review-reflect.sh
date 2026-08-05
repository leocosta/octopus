# review-reflect.sh — Adversarially filter review findings before they are reported.
#
# Usage:
#   octopus.sh review-reflect prepare --base <ref> --ref <ref> --file <report>
#   octopus.sh review-reflect apply   --base <ref> --ref <ref> --file <report> \
#                                     --verdicts <tsv> [--filtered <tsv>]
#
# RM-171. `prepare` emits the adjudication payload — the eligible findings and
# the window of code each one points at. A sonnet sub-agent returns
# "<id>\tkeep|reject\t<reason>". `apply` rewrites the report from those verdicts:
# a rejected blocker demotes to ADVISORY, a rejected non-blocker is dropped into
# --filtered for the record (RM-176).
#
# Exit status:
#   0  ok
#   1  prepare only: nothing was eligible — skip the model call
#   2  usage or repository error

# See the note in audit-scope.sh: `cli/octopus.sh` sources this with -e active.
# `prepare` returning 1 is a routine outcome, not a failure, and the scan's
# greps are allowed to match nothing.
set +e
set -uo pipefail

REVIEW_REFLECT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./reflect-payload.sh
source "$REVIEW_REFLECT_LIB_DIR/reflect-payload.sh"

_review_reflect_usage() {
  echo "Usage: octopus.sh review-reflect prepare --base <ref> --ref <ref> --file <report>"
  echo "       octopus.sh review-reflect apply --base <ref> --ref <ref> --file <report> --verdicts <tsv> [--filtered <tsv>]"
}

SUB="${1:-}"
shift 2>/dev/null || true

BASE="main"; REF="HEAD"; REPORT=""; VERDICTS=""; FILTERED=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base) BASE="${2:-}"; shift 2 ;;
    --ref) REF="${2:-}"; shift 2 ;;
    --file) REPORT="${2:-}"; shift 2 ;;
    --verdicts) VERDICTS="${2:-}"; shift 2 ;;
    --filtered) FILTERED="${2:-}"; shift 2 ;;
    -h|--help) _review_reflect_usage; exit 0 ;;
    *) echo "review-reflect: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "review-reflect: not a git repository" >&2
  exit 2
fi

if [[ -z "$REPORT" || ! -f "$REPORT" ]]; then
  echo "review-reflect: --file <report>: no such file: ${REPORT:-<missing>}" >&2
  exit 2
fi

case "$SUB" in
  prepare)
    reflect_prepare "$BASE" "$REF" "$REPORT"
    exit $?
    ;;
  apply)
    if [[ -z "$VERDICTS" ]]; then
      echo "review-reflect: apply requires --verdicts <tsv>" >&2
      exit 2
    fi
    reflect_apply "$BASE" "$REF" "$REPORT" "$VERDICTS" "$FILTERED"
    exit 0
    ;;
  *)
    _review_reflect_usage >&2
    exit 2
    ;;
esac
