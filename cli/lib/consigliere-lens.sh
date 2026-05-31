#!/usr/bin/env bash
# cli/lib/consigliere-lens.sh — deterministic lens-context helper (RM-110).
#
# Surfaces the grounded material the consigliere lens frames: a root's
# lens_profile, and per-node the sibling playbook.md + the political-risk and
# blocker lines of its state.md. Sourced by cli/lib/lens.sh; the consigliere
# role (RM-101, opus) applies the framing. Read-only — never writes the
# workspace (ADR-007).

CL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CL_OCTOPUS="$CL_DIR/../octopus.sh"

# The root's lens_profile (empty when the root declares none).
cl_profile() { "$CL_OCTOPUS" kr meta "$1" lens_profile; }

# Emit each `- ` bullet under a node's `## <heading>` section, tagged.
cl_section() {
  awk -v h="## $2" -v tag="$3" '$0==h{s=1; next} /^## /{s=0} s && /^- /{print tag "|" $0}' "$1"
}

# Grounded lens material for a node: the trio-sibling playbook, plus the node's
# Political risk and Blockers bullets.
cl_context() {
  local node="$1" playbook
  playbook="$(dirname "$node")/playbook.md"
  [[ -f "$playbook" ]] && echo "playbook|$playbook"
  cl_section "$node" "Political risk" risk
  cl_section "$node" "Blockers" blocker
}
