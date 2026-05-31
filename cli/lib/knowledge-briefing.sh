#!/usr/bin/env bash
# cli/lib/knowledge-briefing.sh — knowledge-briefing deterministic core (RM-109).
#
# Computes the change-delta since a per-root watermark and composes the sibling
# engines (hygiene, synthesize) over the RM-106 registry. Sourced by
# cli/lib/briefing.sh; the SKILL.md wrapper narrates the grounded briefing.
#
# Findings are emitted one per line: section|root|node|detail
#   section ∈ { changed, attention, connection }

KB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-root.sh
source "$KB_DIR/knowledge-root.sh"

# Target roots: an explicit --root id, else every resolved root.
kb_targets() {
  if [[ -n "${KB_ROOT:-}" ]]; then printf '%s\n' "$KB_ROOT"
  else kr_load | cut -d'|' -f1; fi
}

# Emit the briefing sections for each target root, grouped by root.
kb_run() {
  local root
  for root in $(kb_targets); do
    echo "## $root"
  done
}
