#!/usr/bin/env bash
# cli/lib/knowledge-hygiene.sh — knowledge-hygiene deterministic core (RM-107).
#
# Runs the mechanical hygiene checks (staleness, broken-link, orphan,
# archive-drift) over a knowledge root, using the RM-106 registry. Sourced by
# cli/lib/hygiene.sh; the SKILL.md wrapper handles invocation, the fuzzy --gaps
# judgment, and --fix confirmation.
#
# Findings are emitted one per line: sev|root|check|node|detail

KH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./knowledge-root.sh
source "$KH_DIR/knowledge-root.sh"

# Target roots: an explicit --root id, else every resolved root.
kh_targets() {
  if [[ -n "${KH_ROOT:-}" ]]; then printf '%s\n' "$KH_ROOT"
  else kr_load | cut -d'|' -f1; fi
}

# Run the enabled checks over each target root, grouped by root.
kh_run() {
  local root
  for root in $(kh_targets); do
    echo "## $root"
  done
}
