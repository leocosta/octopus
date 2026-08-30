#!/usr/bin/env bash
# cli/lib/git-signals.sh — `octopus git-signals` subcommand (RM-184).
# Dispatched by cli/octopus.sh. Prints churn + co-change clusters for the repo,
# and — when given a diff range — whether the diff ENLARGES a cluster.
#
# Deterministic and dependency-free: git + awk only. No stack detection, no
# lizard/madge, no CI, no orphan ref. See ADR-012.

GS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./git-signals-lib.sh
source "$GS_DIR/git-signals-lib.sh"
# Optional: the layered config resolver. Absent config is not an error — the
# built-in defaults below are the contract.
# shellcheck source=./code-metrics-lib.sh
[[ -f "$GS_DIR/code-metrics-lib.sh" ]] && source "$GS_DIR/code-metrics-lib.sh"

GS_BASE=""; GS_REF=""; GS_WINDOW=""; GS_VERBOSE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)    GS_BASE="${2:-}"; shift 2 ;;
    --ref)     GS_REF="${2:-}"; shift 2 ;;
    --window)  GS_WINDOW="${2:-}"; shift 2 ;;
    --verbose) GS_VERBOSE=1; shift ;;
    -h|--help)
      cat <<'USAGE'
Usage: octopus git-signals [--base <ref>] [--ref <ref>] [--window <days>] [--verbose]

Prints co-change clusters — paths that repeatedly change in the same commit —
with per-path churn. With --base/--ref, also reports whether the diff enlarges
a cluster (touches >=2 members and adds a path that is not one).

Config (.octopus.yml, git_signals.cochange):
  window_days, min_support, min_cohesion, min_cluster,
  max_files_per_commit, max_findings
USAGE
      exit 0 ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

WINDOW="${GS_WINDOW:-$(gs_field_or cochange window_days 90)}"
MIN_SUPPORT="$(gs_field_or cochange min_support 5)"
MIN_COH="$(gs_field_or cochange min_cohesion 0.6)"
MIN_CLUSTER="$(gs_field_or cochange min_cluster 3)"
MAX_FILES="$(gs_field_or cochange max_files_per_commit 25)"
MAX_FINDINGS="$(gs_field_or cochange max_findings 1)"

echo "=== git-signals ==="
echo "window_days: $WINDOW"

STATUS="$(gs_status "$PWD" "$WINDOW" "$MIN_SUPPORT")"
echo "status: $STATUS"

# Absence of evidence is never reported as zero: on `unavailable` no cluster
# line is printed at all, so a caller cannot read silence as "no rigidity".
if [[ "$STATUS" != "ok" ]]; then
  echo ""
  echo "No clusters computed — the evidence is unavailable, not empty."
  exit 0
fi

CLUSTERS="$(mktemp)"; CHURN="$(mktemp)"; CHANGED="$(mktemp)"
trap 'rm -f "$CLUSTERS" "$CHURN" "$CHANGED"' EXIT

git log --since="${WINDOW} days ago" --format='C %H' --name-only 2>/dev/null \
  | gs_cochange "$MAX_FILES" "$MIN_SUPPORT" "$MIN_COH" "$MIN_CLUSTER" > "$CLUSTERS"
git log --since="${WINDOW} days ago" --numstat --format= 2>/dev/null \
  | gs_churn > "$CHURN"
gs_changed_paths "$GS_BASE" "$GS_REF" > "$CHANGED"

if [[ ! -s "$CLUSTERS" ]]; then
  echo ""
  echo "clusters: 0"
  exit 0
fi

# Rank: enlarging clusters first, then support, then size. The ceiling is where
# the "findings about THIS change, not ambient debt" criterion is enforced.
RANKED="$(mktemp)"; trap 'rm -f "$CLUSTERS" "$CHURN" "$CHANGED" "$RANKED"' EXIT
while read -r id; do
  [[ -z "$id" ]] && continue
  verdict="$(gs_verdict "$CLUSTERS" "$CHANGED" "$id")"
  touched="$(cut -f1 <<<"$verdict")"
  outsiders="$(cut -f2 <<<"$verdict")"
  enlarges="$(cut -f3 <<<"$verdict")"
  support="$(awk -v i="$id" '$1==i {print $2; exit}' "$CLUSTERS")"
  conf="$(awk -v i="$id" '$1==i {print $3; exit}' "$CLUSTERS")"
  size="$(awk -v i="$id" '$1==i' "$CLUSTERS" | wc -l)"
  rank=0; [[ "$enlarges" == "true" ]] && rank=1
  printf '%d\t%d\t%d\t%s\t%s\t%s\t%d\t%d\n' \
    "$rank" "$support" "$size" "$id" "$conf" "$enlarges" "$touched" "$outsiders" >> "$RANKED"
done < <(cut -f1 "$CLUSTERS" | sort -un)

sort -k1,1nr -k2,2nr -k3,3nr "$RANKED" | head -n "$MAX_FINDINGS" | \
while IFS=$'\t' read -r _rank support size id conf enlarges touched outsiders; do
  echo ""
  echo "cluster:$id size:$size support:$support cohesion:$conf members_touched:$touched outsiders:$outsiders enlarges:$enlarges"
  awk -v i="$id" '$1==i {print $4}' "$CLUSTERS" | while read -r path; do
    c="$(awk -v p="$path" '$2==p {print $1; exit}' "$CHURN")"
    t=false; grep -qxF "$path" "$CHANGED" && t=true
    echo "  member: $path churn:${c:-0} touched:$t"
  done
  if [[ "$enlarges" == "true" ]]; then
    while read -r path; do
      [[ -z "$path" ]] && continue
      awk -v i="$id" -v p="$path" '$1==i && $4==p {found=1} END {exit !found}' "$CLUSTERS" \
        || echo "  outsider: $path"
    done < "$CHANGED"
  fi
done

if [[ "$GS_VERBOSE" -eq 1 ]]; then
  echo ""
  echo "--- verbose: all clusters ---"
  cat "$CLUSTERS"
fi
