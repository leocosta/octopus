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
ks_entities() {
  local f="$1"
  { grep -oE '\[\[[^]]+\]\]' "$f" | sed -E 's/\[\[|\]\]//g'
    grep -oE '`[^`]+`' "$f" | tr -d '`'
    grep -oE '([A-Z][a-z]+ )+[A-Z][a-z]+' "$f"
  } | awk 'length($0)>=3 && $0 !~ /^(The|A|An|This|That|For|And|But|With|Of|In|On|To)$/' \
    | sort -u
}

# Emit the connection candidates for each target root, grouped by root.
ks_run() {
  local root
  for root in $(ks_targets); do
    echo "## $root"
  done
}
