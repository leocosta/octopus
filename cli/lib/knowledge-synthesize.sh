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
# Extract candidate entities — deduped, one per line. Structural and
# language-neutral only: [[mentions]] and `code` spans. Free-text / multilingual
# entity detection (capitalized phrases, any-language proper nouns) is the
# SKILL.md's job (LLM), NOT the deterministic core — a hardcoded English regex
# and stopword list would miss accented pt-br entities (e.g. "Política Fiscal")
# and silo every other language.
# Each grep may legitimately find nothing — guard with `|| true` so a no-match
# (exit 1) does not trip the caller's set -e.
ks_entities() {
  local f="$1"
  { grep -oE '\[\[[^]]+\]\]' "$f" | sed -E 's/\[\[|\]\]//g' || true
    grep -oE '`[^`]+`' "$f" | tr -d '`' || true
  } | awk 'length($0)>=2' | sort -u
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
  local root="$1" node nodes titles count ent
  nodes="$(kr_nodes "$root")"
  titles="$(while read -r node; do basename "$node" .md; done <<<"$nodes")"
  while read -r node; do ks_entities "$node"; done <<<"$nodes" \
  | sort | uniq -c \
  | while read -r count ent; do
      [[ "$count" -ge 2 ]] || continue
      grep -qixF "$ent" <<<"$titles" && continue   # has a home node → not a co-mention
      echo "co-mention|$root|$ent||$count"
    done
}

# relevant: rank other nodes by shared-entity overlap with a focus node
# (the "forgotten-but-relevant" lookup), top-N.
KS_TOPN="${KS_TOPN:-10}"
ks_relevant() {
  local root="$1" focus="$2" node shared fents
  fents="$(ks_entities "$focus")"
  while read -r node; do
    [[ "$node" == "$focus" ]] && continue
    shared="$(comm -12 <(printf '%s\n' "$fents") <(ks_entities "$node") | wc -l)"
    if [[ "$shared" -gt 0 ]]; then echo "$shared|relevant|$root|$focus|$node|${shared} shared"; fi
  done < <(kr_nodes "$root") \
  | sort -t'|' -k1 -rn | head -n "$KS_TOPN" | cut -d'|' -f2-
}

# --fix: seed a relative link for a mention whose entity resolves to exactly
# one node title. Skips multi-target and already-linked cases. Reversible (a
# plain edit the user can git-revert).
ks_fix_links() {
  local root="$1" node ent nodes matches target rel
  nodes="$(kr_nodes "$root")"
  while read -r node; do
    while read -r ent; do
      [[ -n "$ent" ]] || continue
      matches="$(awk -v e="$ent" '
        { p=$0; sub(/.*\//,"",p); sub(/\.md$/,"",p); if (p==e) print }' <<<"$nodes")"
      [[ -n "$matches" && "$(wc -l <<<"$matches")" -eq 1 ]] || continue
      target="$matches"
      grep -qF "$(basename "$target")" "$node" && continue   # already linked
      rel="$(realpath --relative-to "$(dirname "$node")" "$target")"
      printf '\n[%s](%s)\n' "$ent" "$rel" >>"$node"
    done < <(ks_entities "$node")
  done <<<"$nodes"
}

# Emit the connection candidates for each target root, grouped by root.
ks_run() {
  local root
  for root in $(ks_targets); do
    echo "## $root"
    if [[ -n "${KS_NODE:-}" ]]; then
      ks_relevant "$root" "$KS_NODE"
    else
      ks_shared_target "$root"
      ks_co_mention "$root"
    fi
    if [[ "${KS_FIX:-0}" == 1 ]]; then ks_fix_links "$root"; fi
  done
}
