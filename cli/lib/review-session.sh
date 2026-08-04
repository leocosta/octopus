# review-session.sh — Persist and query review runs.
#
# Usage:
#   octopus.sh review-session record --base <ref> --ref <ref> --report <file> [--audits <file>]
#   octopus.sh review-session list [--json]
#   octopus.sh review-session show <id|latest> [--severity A,B] [--json]
#
# RM-176. Writes the aggregated report to .octopus/reviews/<id>.json with each
# finding's origin, severity, anchor verdict (RM-170) and the per-audit
# skip/cached/scoped resolution (RM-172), so review output can be consumed by
# anything downstream instead of being recovered from a transcript.
#
# Exit: 0 ok, 1 nothing found, 2 usage/repository error.

set -uo pipefail

REVIEW_SESSION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./review-record.sh
source "$REVIEW_SESSION_LIB_DIR/review-record.sh"

_review_session_usage() {
  echo "Usage: octopus.sh review-session record --base <ref> --ref <ref> --report <file> [--audits <file>]"
  echo "       octopus.sh review-session list [--json]"
  echo "       octopus.sh review-session show <id|latest> [--severity A,B] [--json]"
}

_review_session_gitignore_guard() {
  local ignore=".gitignore" entry=".octopus/reviews/"
  [[ -f "$ignore" ]] && grep -qF "$entry" "$ignore" && return 0
  printf '%s\n' "$entry" >> "$ignore" 2>/dev/null || \
    echo "review-session: could not write $ignore — add '$entry' manually" >&2
  return 0
}

_review_session_require_jq() {
  command -v jq >/dev/null 2>&1 && return 0
  echo "review-session: jq is required for this query (the record itself is written without it)" >&2
  return 2
}

SUB="${1:-}"
shift 2>/dev/null || true

if ! git rev-parse --git-dir >/dev/null 2>&1; then
  echo "review-session: not a git repository" >&2
  exit 2
fi

DIR="$(review_record_dir)"

case "$SUB" in
  record)
    BASE="main"; REF="HEAD"; REPORT=""; AUDITS=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base) BASE="${2:-}"; shift 2 ;;
        --ref) REF="${2:-}"; shift 2 ;;
        --report) REPORT="${2:-}"; shift 2 ;;
        --audits) AUDITS="${2:-}"; shift 2 ;;
        *) echo "review-session: unknown argument '$1'" >&2; exit 2 ;;
      esac
    done

    if [[ -z "$REPORT" || ! -f "$REPORT" ]]; then
      echo "review-session: --report <existing-file> is required" >&2
      exit 2
    fi

    mkdir -p "$DIR" || { echo "review-session: cannot create $DIR" >&2; exit 2; }
    _review_session_gitignore_guard

    stamp="$(date -u +%Y%m%dT%H%M%SZ)"
    short="$(git rev-parse --short "$REF" 2>/dev/null || echo unknown)"
    id="${stamp}-${short}"
    # Two reviews of the same sha within the same second must not overwrite each
    # other — re-running a review after a fix is exactly that case.
    if [[ -e "$DIR/${id}.json" ]]; then
      n=2
      while [[ -e "$DIR/${id}-${n}.json" ]]; do n=$((n + 1)); done
      id="${id}-${n}"
    fi
    out="$DIR/${id}.json"

    review_record_json "$BASE" "$REF" "$REPORT" "$AUDITS" > "$out" || {
      echo "review-session: failed to write $out" >&2
      exit 2
    }

    count=$(review_record_parse "$BASE" "$REF" "$REPORT" | grep -c . || true)
    unanchored=$(review_record_parse "$BASE" "$REF" "$REPORT" \
      | awk -F'\t' '$5 == "missing-file" || $5 == "line-out-of-range"' | grep -c . || true)

    echo "OCTOPUS_REVIEW_SESSION=$id"
    echo "path: $out"
    echo "findings: $count (unanchored: $unanchored)"
    ;;

  list)
    JSON=""
    [[ "${1:-}" == "--json" ]] && JSON=1
    if [[ ! -d "$DIR" ]]; then
      echo "review-session: no records yet" >&2
      exit 1
    fi
    shopt -s nullglob
    files=("$DIR"/*.json)
    shopt -u nullglob
    if [[ ${#files[@]} -eq 0 ]]; then
      echo "review-session: no records yet" >&2
      exit 1
    fi
    if [[ -n "$JSON" ]]; then
      _review_session_require_jq || exit 2
      jq -s '[.[] | {created_at, base, ref, findings: (.findings | length)}]' "${files[@]}"
    else
      for f in "${files[@]}"; do
        n=$(grep -c '"severity"' "$f" || true)
        printf '%s  %s findings\n' "$(basename "$f" .json)" "$n"
      done
    fi
    ;;

  show)
    ID="${1:-latest}"
    shift 2>/dev/null || true
    SEVERITY=""; JSON=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --severity) SEVERITY="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        *) echo "review-session: unknown argument '$1'" >&2; exit 2 ;;
      esac
    done

    if [[ "$ID" == "latest" ]]; then
      shopt -s nullglob
      files=("$DIR"/*.json)
      shopt -u nullglob
      [[ ${#files[@]} -eq 0 ]] && { echo "review-session: no records yet" >&2; exit 1; }
      file="${files[-1]}"
    else
      file="$DIR/${ID}.json"
    fi

    [[ -f "$file" ]] || { echo "review-session: no such record: $ID" >&2; exit 1; }

    if [[ -z "$SEVERITY" && -n "$JSON" ]]; then
      cat "$file"
      exit 0
    fi

    _review_session_require_jq || exit 2

    if [[ -n "$SEVERITY" ]]; then
      filter="$(printf '%s' "$SEVERITY" | tr ',' '\n' | tr '[:lower:]' '[:upper:]' | jq -R . | jq -s .)"
      selected="$(jq --argjson want "$filter" '[.findings[] | select(.severity as $s | $want | index($s))]' "$file")"
    else
      selected="$(jq '.findings' "$file")"
    fi

    if [[ -n "$JSON" ]]; then
      printf '%s\n' "$selected"
    else
      printf '%s\n' "$selected" | jq -r '.[] | "\(.severity)\t[\(.origin)]\t\(.anchor)\t\(.text)"'
    fi
    ;;

  ""|-h|--help)
    _review_session_usage
    exit 2 ;;
  *)
    echo "review-session: unknown subcommand '$SUB'" >&2
    _review_session_usage >&2
    exit 2 ;;
esac
