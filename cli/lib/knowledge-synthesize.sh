#!/usr/bin/env bash
# cli/lib/knowledge-synthesize.sh — knowledge-synthesize deterministic core (RM-108).
#
# Computes ranked cross-node connection candidates over a knowledge root using
# the RM-106 registry. Sourced by cli/lib/synthesize.sh; the SKILL.md wrapper
# judges relevance and contradiction.
#
# Findings are emitted one per line: kind|root|a|b|signal|score

KS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-root.sh
source "$KS_DIR/knowledge-root.sh"

# Target roots: an explicit --root id, else every resolved root.
ks_targets() {
  if [[ -n "${KS_ROOT:-}" ]]; then printf '%s\n' "$KS_ROOT"
  else kr_load | cut -d'|' -f1; fi
}

# Extract candidate entities from a node, one per line, deduped:
#   [[mentions]], `code` spans, and Capitalized Multiword phrases.
# Filtered by a min length and a small stopword list. Root-agnostic.
# Each grep may legitimately find nothing — guard with `|| true` so a no-match
# (exit 1) does not trip the caller's set -e.
ks_entities() {
  local f="$1"
  { grep -oE '\[\[[^]]+\]\]' "$f" | sed -E 's/\[\[|\]\]//g' || true
    grep -oE '`[^`]+`' "$f" | tr -d '`' || true
    grep -oE '([A-Z][a-z]+ )+[A-Z][a-z]+' "$f" || true
  } | awk 'length($0)>=3 && $0 !~ /^(The|A|An|This|That|For|And|But|With|Of|In|On|To)$/' \
    | sort -u
}

# shared-target: node pairs whose link sets intersect (link the same third
# node). Rows are sorted so each pair is emitted in a stable order.
ks_shared_target() {
  local root="$1" node t rows
  rows="$(while read -r node; do
    kr_links "$root" "$node" | while read -r t; do printf '%s\t%s\n' "$node" "$t"; done
  done < <(kr_nodes "$root") | sort)"
  [[ -n "$rows" ]] || return 0
  awk -F'\t' -v root="$root" '
    { by[$2] = by[$2] FS $1 }
    END {
      for (t in by) {
        n = split(by[t], a, FS)
        for (i = 2; i <= n; i++)
          for (j = i + 1; j <= n; j++)
            print "shared-target|" root "|" a[i] "|" a[j] "|" t "|1"
      }
    }' <<<"$rows"
}

# co-mention: an entity appearing in >=2 nodes with no node of its own.
ks_co_mention() {
  local root="$1" node titles count ent
  titles="$(while read -r node; do basename "$node" .md; done < <(kr_nodes "$root"))"
  while read -r node; do ks_entities "$node"; done < <(kr_nodes "$root") \
  | sort | uniq -c \
  | while read -r count ent; do
      [[ "$count" -ge 2 ]] || continue
      grep -qixF "$ent" <<<"$titles" && continue   # has a home node → not a co-mention
      echo "co-mention|$root|$ent||$count"
    done
}

# Emit the connection candidates for each target root, grouped by root.
ks_run() {
  local root
  for root in $(ks_targets); do
    echo "## $root"
    ks_shared_target "$root"
    ks_co_mention "$root"
  done
}
