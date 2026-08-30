#!/usr/bin/env bash
# cli/lib/git-signals-lib.sh — deterministic git-history signals (RM-184).
#
# Pure git + awk. No stack detection, no external tooling, no network, no
# orphan ref — these signals must run in any repo, in any language, with no
# Octopus bundle adopted and no CI.
#
# Following the code-metrics.sh / code-metrics-lib.sh split:
#   cli/lib/git-signals.sh     — command entry
#   cli/lib/git-signals-lib.sh — deterministic core (this file)
#
# Two signals:
#   churn      — how often each path changed in the window
#   co-change  — paths that repeatedly change in the SAME commit, which is the
#                evidence that a concept is spread across files and that every
#                extension pays a toll across all of them (ADR-012).

# ---------------------------------------------------------------------------
# Config — reuses the code-metrics layered resolver via CM_CONFIG_ROOT.
# Collapsing the three readers (kr_*, cm_*, this) is RM-185.
# ---------------------------------------------------------------------------

# Resolve a git_signals.<section>.<key>, falling back to a built-in default.
gs_field_or() {
  if declare -f cm_field_or &>/dev/null; then
    CM_CONFIG_ROOT=git_signals cm_field_or "$1" "$2" "$3"
  else
    printf '%s\n' "$3"
  fi
}

# ---------------------------------------------------------------------------
# Status — absence of evidence must never be reported as zero
# ---------------------------------------------------------------------------

# Echo "ok" or "unavailable:<reason>".
#   $1 — repo root (default: $PWD)
#   $2 — window in days
#   $3 — minimum commits required for the window to be judgeable
gs_status() {
  local root="${1:-$PWD}" window="${2:-90}" min_commits="${3:-5}"
  command -v git &>/dev/null || { echo "unavailable:no-git"; return 0; }
  git -C "$root" rev-parse --git-dir &>/dev/null \
    || { echo "unavailable:not-a-repo"; return 0; }
  if [[ "$(git -C "$root" rev-parse --is-shallow-repository 2>/dev/null)" == "true" ]]; then
    echo "unavailable:shallow-clone"; return 0
  fi
  local n
  n="$(git -C "$root" log --since="${window} days ago" --format='%H' 2>/dev/null | wc -l)"
  if [[ "$n" -lt "$min_commits" ]]; then echo "unavailable:empty-window"; return 0; fi
  echo "ok"
}

# ---------------------------------------------------------------------------
# Churn (moved here from code-metrics-lib.sh, RM-149)
# ---------------------------------------------------------------------------

# Aggregate per-file churn from `git log --numstat --format=` on stdin.
# Binary files (numstat "-") are skipped.
# Reads stdin, emits one `<churn>\t<path>` line per file.
gs_churn() {
  awk '
    NF == 3 && $1 != "-" { churn[$3] += $1 + $2 }
    END { for (f in churn) printf "%d\t%s\n", churn[f], f }
  '
}

# ---------------------------------------------------------------------------
# Co-change clusters
# ---------------------------------------------------------------------------

# Read `git log --format=C\ %H --name-only` on stdin and emit surviving
# clusters, one line per member:
#     <cluster_id>\t<support>\t<confidence>\t<path>
#
#   $1 — max_files_per_commit (commits wider than this are dropped)
#   $2 — min_support          (pair must co-occur at least this many times)
#   $3 — min_cohesion         (Jaccard: support / (commits(a) + commits(b) - support))
#   $4 — min_cluster          (minimum members for a cluster to survive)
#
# Cohesion is Jaccard, NOT support/min(a,b). A path touched by nearly every
# commit — a changelog, a lockfile — co-occurs with everything, and dividing by
# the smaller side would score it 1.0 against every partner and drag the whole
# repo into one cluster. Jaccard charges it for its own solo commits, so it
# scores near zero and drops out while the genuine trio stays at 1.0.
gs_cochange() {
  local maxf="$1" min_sup="$2" min_coh="$3" min_cluster="$4"
  awk -v maxf="$maxf" -v min_sup="$min_sup" -v min_coh="$min_coh" \
      -v min_cluster="$min_cluster" '
    function flush(  i, j, a, b, t) {
      if (n == 0) return
      if (n <= maxf) {
        for (i = 1; i <= n; i++) cnt[f[i]]++
        for (i = 1; i < n; i++) {
          for (j = i + 1; j <= n; j++) {
            a = f[i]; b = f[j]
            if (a > b) { t = a; a = b; b = t }
            sup[a SUBSEP b]++
          }
        }
      }
      n = 0; delete seen
    }
    function find(x) { while (parent[x] != x) { parent[x] = parent[parent[x]]; x = parent[x] } return x }
    function union(x, y,   rx, ry) {
      rx = find(x); ry = find(y)
      if (rx != ry) parent[rx] = ry
    }
    /^C / { flush(); next }
    NF == 0 { next }
    {
      # Dedupe paths inside one commit; a path counted twice would inflate
      # both its own commit count and every pair it belongs to.
      if ($0 in seen) next
      seen[$0] = 1
      f[++n] = $0
    }
    END {
      flush()
      # Surviving pairs become edges.
      for (k in sup) {
        split(k, p, SUBSEP); a = p[1]; b = p[2]
        if (sup[k] < min_sup) continue
        denom = cnt[a] + cnt[b] - sup[k]
        if (denom <= 0) continue
        conf = sup[k] / denom
        if (conf < min_coh) continue
        if (!(a in parent)) parent[a] = a
        if (!(b in parent)) parent[b] = b
        union(a, b)
        edge_sup[k] = sup[k]; edge_conf[k] = conf
      }
      # Group members by component root.
      for (p_ in parent) {
        r = find(p_)
        members[r] = (r in members) ? members[r] SUBSEP p_ : p_
        size[r]++
      }
      # Per-cluster support/confidence: the strongest pair characterises it.
      for (k in edge_sup) {
        split(k, p, SUBSEP); r = find(p[1])
        if (edge_sup[k] > csup[r]) csup[r] = edge_sup[k]
        if (edge_conf[k] > cconf[r]) cconf[r] = edge_conf[k]
      }
      id = 0
      for (r in members) {
        if (size[r] < min_cluster) continue
        id++
        m = members[r]; c = split(m, arr, SUBSEP)
        for (i = 1; i <= c; i++)
          printf "%d\t%d\t%.2f\t%s\n", id, csup[r], cconf[r], arr[i]
      }
    }
  '
}

# ---------------------------------------------------------------------------
# Diff verdict
# ---------------------------------------------------------------------------

# Decide whether the diff ENLARGES a cluster.
#   $1 — cluster file: "<id>\t<support>\t<confidence>\t<path>" lines
#   $2 — changed-paths file: one path per line
#   $3 — cluster id to evaluate
#
# Echoes: "<members_touched>\t<outsiders>\t<enlarges>"
#
# enlarges = members_touched >= 2 AND outsiders >= 1. Touching one member is
# passing through; touching two and adding a third is joining the cluster, and
# that new path will co-change with the others from here on.
gs_verdict() {
  local cluster_file="$1" changed_file="$2" id="$3"
  awk -v id="$id" '
    FNR == NR { if ($1 == id) member[$4] = 1; next }
    { changed[$0] = 1 }
    END {
      touched = 0; outsiders = 0
      for (p in changed) {
        if (p in member) touched++
        else outsiders++
      }
      enlarges = (touched >= 2 && outsiders >= 1) ? "true" : "false"
      printf "%d\t%d\t%s\n", touched, outsiders, enlarges
    }
  ' "$cluster_file" "$changed_file"
}

# List the paths a diff changed, one per line.
#   $1 — base ref, $2 — head ref (both optional; defaults to the working tree)
gs_changed_paths() {
  local base="${1:-}" ref="${2:-}"
  if [[ -n "$base" && -n "$ref" ]]; then
    git diff --name-only "$base...$ref" 2>/dev/null
  elif [[ -n "$base" ]]; then
    git diff --name-only "$base" 2>/dev/null
  else
    git diff --name-only HEAD 2>/dev/null
  fi
}
