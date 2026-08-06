# review-session.sh — Persist and query review runs.
#
# Usage:
#   octopus.sh review-session record --base <ref> --ref <ref> --report <file> [--audits <file>] [--filtered <file>]
#   octopus.sh review-session list [--json]
#   octopus.sh review-session show <id|latest> [--severity A,B] [--json] [--filtered]
#
# RM-176. Writes the aggregated report to .octopus/reviews/<id>.json with each
# finding's origin, severity, anchor verdict (RM-170) and the per-audit
# skip/cached/scoped resolution (RM-172), so review output can be consumed by
# anything downstream instead of being recovered from a transcript.
#
# Exit: 0 ok, 1 nothing found, 2 usage/repository error.

# See the note in audit-scope.sh: `cli/octopus.sh` sources this with -e active.
# `show` on an unknown id and `list` with no records both return non-zero by
# design, and the record parser tolerates greps that match nothing.
set +e
set -uo pipefail

REVIEW_SESSION_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./review-record.sh
source "$REVIEW_SESSION_LIB_DIR/review-record.sh"

_review_session_usage() {
  echo "Usage: octopus.sh review-session record --base <ref> --ref <ref> --report <file> [--audits <file>] [--filtered <file>]"
  echo "       octopus.sh review-session list [--json]"
  echo "       octopus.sh review-session show <id|latest> [--severity A,B] [--json] [--filtered]"
  echo "       octopus.sh review-session judge <id|latest> --list"
  echo "       octopus.sh review-session judge <id|latest> (--finding N|--filtered N) --verdict <real|wont-fix|false|wrong-location> [--note T]"
  echo "       octopus.sh review-session judge <id|latest> --from <tsv>"
  echo "       octopus.sh review-session score [--json]"
}

_review_session_gitignore_guard() {
  local ignore=".gitignore" entry=".octopus/reviews/"
  [[ -f "$ignore" ]] && grep -qF "$entry" "$ignore" && return 0
  printf '%s\n' "$entry" >> "$ignore" 2>/dev/null || \
    echo "review-session: could not write $ignore — add '$entry' manually" >&2
  return 0
}

# ---------------------------------------------------------------------------
# _review_session_resolve_file <id|latest>
#
# Prints the record path, or exits 1. Shared by show/judge/score so `latest`
# means the same thing in all three.
# ---------------------------------------------------------------------------
_review_session_resolve_file() {
  local id="$1" file
  if [[ "$id" == "latest" ]]; then
    shopt -s nullglob
    local files=("$DIR"/*.json)
    shopt -u nullglob
    [[ ${#files[@]} -eq 0 ]] && { echo "review-session: no records yet" >&2; return 1; }
    # Sort by mtime, not filename: an id-collision suffix ("-2", "-3", ...)
    # sorts lexicographically *before* the unsuffixed name it collided with
    # ('-' < '.'), so re-running a review within the same second would make
    # the plain filename win even though it is the oldest of the batch.
    file="$(ls -t "${files[@]}" | head -n 1)"
  else
    file="$DIR/${id}.json"
  fi
  [[ -f "$file" ]] || { echo "review-session: no such record: $id" >&2; return 1; }
  printf '%s' "$file"
}

# Verdicts live beside the record, not inside it (RM-181). The record is written
# without jq on purpose, so a record is still produced in degraded environments;
# rewriting that JSON to add a field would put jq on the write path. Append-only
# TSV keeps the write path a `printf`.
_review_session_verdicts_file() { printf '%s' "${1%.json}.verdicts.tsv"; }

# A verdict a human gave, not a severity. The distinction that keeps the number
# honest is `wont-fix`: a real finding you chose not to act on is still a hit,
# and scoring it as a miss is the standard way to make a reviewer look worse
# than it is.
_REVIEW_VERDICTS="real wont-fix false wrong-location"

_review_session_valid_verdict() {
  [[ " $_REVIEW_VERDICTS " == *" ${1:-} "* ]]
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
    BASE="main"; REF="HEAD"; REPORT=""; AUDITS=""; FILTERED=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --base) BASE="${2:-}"; shift 2 ;;
        --ref) REF="${2:-}"; shift 2 ;;
        --report) REPORT="${2:-}"; shift 2 ;;
        --audits) AUDITS="${2:-}"; shift 2 ;;
        --filtered) FILTERED="${2:-}"; shift 2 ;;
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

    review_record_json "$BASE" "$REF" "$REPORT" "$AUDITS" "$FILTERED" > "$out" || {
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
        # Count only the findings, not every object carrying a "severity" key:
        # filtered[] entries carry one too (RM-171), so a plain grep over the
        # whole file reported "findings: N + filtered" and silently disagreed
        # with `list --json`, which counts `.findings | length`. review_record_json
        # always writes findings[] before filtered[], so stopping at the
        # "filtered": [ line is exact — and needs no jq, which the write path
        # and this default (non---json) query path both do without.
        n=$(awk '/"filtered": \[/ { exit } /"severity"/ { c++ } END { print c+0 }' "$f")
        printf '%s  %s findings\n' "$(basename "$f" .json)" "$n"
      done
    fi
    ;;

  show)
    ID="${1:-latest}"
    shift 2>/dev/null || true
    SEVERITY=""; JSON=""; SHOW_FILTERED=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --severity) SEVERITY="${2:-}"; shift 2 ;;
        --json) JSON=1; shift ;;
        --filtered) SHOW_FILTERED=1; shift ;;
        *) echo "review-session: unknown argument '$1'" >&2; exit 2 ;;
      esac
    done

    file="$(_review_session_resolve_file "$ID")" || exit 1

    # --filtered and --severity are about different arrays — --filtered wins
    # and ignores --severity.
    if [[ -n "$SHOW_FILTERED" ]]; then
      _review_session_require_jq || exit 2
      selected="$(jq '.filtered // []' "$file")"
      if [[ -n "$JSON" ]]; then
        printf '%s\n' "$selected"
      else
        printf '%s\n' "$selected" | jq -r '.[] | "\(.severity)\t[\(.origin)]\t\(.path):\(.line)\t\(.reason)"'
      fi
      exit 0
    fi

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

  judge)
    ID="${1:-latest}"
    shift 2>/dev/null || true
    SCOPE=""; INDEX=""; VERDICT=""; NOTE=""; FROM=""; LIST=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --finding)  SCOPE="finding";  INDEX="${2:-}"; shift 2 ;;
        --filtered) SCOPE="filtered"; INDEX="${2:-}"; shift 2 ;;
        --verdict)  VERDICT="${2:-}"; shift 2 ;;
        --note)     NOTE="${2:-}"; shift 2 ;;
        --from)     FROM="${2:-}"; shift 2 ;;
        --list)     LIST=1; shift ;;
        *) echo "review-session: unknown argument '$1'" >&2; exit 2 ;;
      esac
    done

    file="$(_review_session_resolve_file "$ID")" || exit 1
    verdicts="$(_review_session_verdicts_file "$file")"
    _review_session_require_jq || exit 2

    # --list: what is there to judge, and what has already been judged.
    if [[ -n "$LIST" ]]; then
      for scope in findings filtered; do
        label="finding"; [[ "$scope" == "filtered" ]] && label="filtered"
        n=0
        while IFS= read -r row; do
          [[ -z "$row" ]] && continue
          n=$((n + 1))
          given=""
          [[ -f "$verdicts" ]] && given="$(awk -F'\t' -v s="$label" -v i="$n" \
            '$1 == s && $2 == i { v = $3 } END { print v }' "$verdicts")"
          printf '%-8s %-3s %-14s %s\n' "$label" "$n" "${given:--}" "$row"
          # A finding's own text already carries "[origin: x]"; a filtered row's
          # reason does not, so only that side needs the origin prefixed.
        done < <(jq -r ".${scope} // [] | .[] | if .text then \"\(.severity) \(.text)\" else \"\(.severity) [\(.origin)] \(.reason)\" end" "$file")
      done
      exit 0
    fi

    # Batch: "<scope>\t<index>\t<verdict>[\t<note>]" per line.
    if [[ -n "$FROM" ]]; then
      [[ -f "$FROM" ]] || { echo "review-session: no such file: $FROM" >&2; exit 2; }
      applied=0
      while IFS=$'\t' read -r b_scope b_index b_verdict b_note; do
        [[ -z "${b_scope:-}" ]] && continue
        _review_session_valid_verdict "$b_verdict" || {
          echo "review-session: invalid verdict '$b_verdict' (expected: $_REVIEW_VERDICTS)" >&2
          exit 2
        }
        printf '%s\t%s\t%s\t%s\n' "$b_scope" "$b_index" "$b_verdict" "${b_note:-}" >> "$verdicts"
        applied=$((applied + 1))
      done < "$FROM"
      echo "review-session: recorded $applied verdict(s) in $verdicts"
      exit 0
    fi

    if [[ -z "$SCOPE" || -z "$INDEX" || -z "$VERDICT" ]]; then
      echo "review-session: judge needs --finding N or --filtered N, plus --verdict" >&2
      exit 2
    fi
    _review_session_valid_verdict "$VERDICT" || {
      echo "review-session: invalid verdict '$VERDICT' (expected: $_REVIEW_VERDICTS)" >&2
      exit 2
    }
    [[ "$INDEX" =~ ^[0-9]+$ ]] || { echo "review-session: index must be a number" >&2; exit 2; }

    # An index nobody can resolve would silently skew the score.
    arr="findings"; [[ "$SCOPE" == "filtered" ]] && arr="filtered"
    total="$(jq "(.${arr} // []) | length" "$file")"
    if [[ "$INDEX" -lt 1 || "$INDEX" -gt "$total" ]]; then
      echo "review-session: $SCOPE index $INDEX out of range (record has $total)" >&2
      exit 2
    fi

    printf '%s\t%s\t%s\t%s\n' "$SCOPE" "$INDEX" "$VERDICT" "$NOTE" >> "$verdicts"
    echo "review-session: $SCOPE $INDEX → $VERDICT"
    exit 0
    ;;

  score)
    JSON=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --json) JSON=1; shift ;;
        *) echo "review-session: unknown argument '$1'" >&2; exit 2 ;;
      esac
    done
    _review_session_require_jq || exit 2

    shopt -s nullglob
    records=("$DIR"/*.json)
    shopt -u nullglob
    [[ ${#records[@]} -eq 0 ]] && { echo "review-session: no records yet" >&2; exit 1; }

    all_verdicts="$(mktemp)"
    trap 'rm -f "$all_verdicts"' EXIT
    runs=0; total_findings=0
    for rec in "${records[@]}"; do
      runs=$((runs + 1))
      total_findings=$((total_findings + $(jq '(.findings // []) | length' "$rec")))
      v="$(_review_session_verdicts_file "$rec")"
      [[ -f "$v" ]] || continue
      # The verdicts file is append-only, so re-judging a finding leaves both
      # rows. Fold to last-wins before scoring — otherwise correcting a verdict
      # counts twice and the score is whatever you typed most often. `--list`
      # already resolves it the same way.
      while IFS=$'\t' read -r s i verdict; do
        [[ -z "${s:-}" ]] && continue
        arr="findings"; [[ "$s" == "filtered" ]] && arr="filtered"
        # Origin is needed per verdict, and only the record knows it.
        origin="$(jq -r "(.${arr} // [])[$((i - 1))].origin // \"unknown\"" "$rec" 2>/dev/null)"
        printf '%s\t%s\t%s\n' "$s" "$verdict" "$origin" >> "$all_verdicts"
      done < <(awk -F'\t' '
        $1 != "" { key = $1 FS $2; last[key] = $3; seen[key] = NR }
        END { for (k in last) { split(k, a, FS); printf "%s\t%s\t%s\n", a[1], a[2], last[k] } }
      ' "$v")
    done

    awk -F'\t' -v runs="$runs" -v total="$total_findings" -v json="${JSON:-}" '
      $1 == "finding" {
        judged++
        count[$2]++
        by_origin_total[$3]++
        if ($2 == "real" || $2 == "wont-fix") { hits++; by_origin_hit[$3]++ }
      }
      $1 == "filtered" {
        fjudged++
        # The reflection pass dropped these. It was right when the human agrees
        # they were not real.
        if ($2 == "false") fright++; else fwrong++
      }
      END {
        prec = (judged - count["wrong-location"] > 0) \
               ? hits / (judged - count["wrong-location"]) : 0
        if (json == "1") {
          printf "{\"runs\": %d, \"findings\": %d, \"judged\": %d, \"precision\": %.4f,", runs, total, judged, prec
          printf " \"real\": %d, \"wont_fix\": %d, \"false\": %d, \"wrong_location\": %d,",
            count["real"], count["wont-fix"], count["false"], count["wrong-location"]
          printf " \"filtered_judged\": %d, \"filtered_correct\": %d, \"filtered_wrong\": %d}\n",
            fjudged, fright, fwrong
          exit
        }
        printf "judged: %d of %d findings across %d run(s)\n\n", judged, total, runs
        if (judged == 0) { print "Nothing judged yet — run: octopus review-session judge latest --list"; exit }
        printf "precision          %.2f   (%d real+wont-fix of %d judged, excluding wrong-location)\n",
          prec, hits, judged - count["wrong-location"]
        printf "  real             %d\n", count["real"]
        printf "  wont-fix         %d\n", count["wont-fix"]
        printf "  false            %d\n", count["false"]
        printf "  wrong-location   %d\n", count["wrong-location"]
        print ""
        print "by origin"
        for (o in by_origin_total)
          printf "  %-16s %.2f  (%d judged)\n", o, by_origin_hit[o] / by_origin_total[o], by_origin_total[o]
        if (fjudged > 0) {
          print ""
          print "reflection pass (RM-171) — of what it dropped"
          printf "  judged           %d\n", fjudged
          printf "  correctly dropped %d\n", fright
          printf "  wrongly dropped  %d   <- real findings the filter removed\n", fwrong
        }
      }
    ' "$all_verdicts"
    exit 0
    ;;

  ""|-h|--help)
    _review_session_usage
    exit 2 ;;
  *)
    echo "review-session: unknown subcommand '$SUB'" >&2
    _review_session_usage >&2
    exit 2 ;;
esac
