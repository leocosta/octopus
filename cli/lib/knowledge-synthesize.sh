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

# Emit the connection candidates for each target root, grouped by root.
ks_run() {
  local root
  for root in $(ks_targets); do
    echo "## $root"
  done
}
