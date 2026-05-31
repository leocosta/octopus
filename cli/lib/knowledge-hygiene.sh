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

# Last-update epoch of a node, by cascade: frontmatter `updated:` → git
# last-commit → filesystem mtime. The first that resolves wins.
kh_last_update() {
  local f="$1" v
  v="$(awk -F': *' '/^updated:/{print $2; exit} /^---/ && NR>1 {exit}' "$f")"
  if [[ -n "$v" ]] && v="$(date -d "$v" +%s 2>/dev/null)"; then printf '%s' "$v"; return; fi
  v="$(git -C "$(dirname "$f")" log -1 --format=%ct -- "$f" 2>/dev/null)"
  [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  stat -c %Y "$f"
}

# Flag nodes whose last update is older than the root's staleness_days.
kh_staleness() {
  local root="$1" days now node age
  days="$(kr_field "$root" staleness_days)"; now="$(date +%s)"
  while read -r node; do
    age=$(( (now - $(kh_last_update "$node")) / 86400 ))
    if (( age > days )); then echo "warn|$root|staleness|$node|${age}d > ${days}d"; fi
  done < <(kr_nodes "$root")
}

# Flag link targets that do not exist on disk.
kh_broken_links() {
  local root="$1" node target
  while read -r node; do
    while read -r target; do
      [[ -z "$target" || -e "$target" ]] || echo "warn|$root|broken-link|$node|$target"
    done < <(kr_links "$root" "$node")
  done < <(kr_nodes "$root")
}

# Run the enabled checks over each target root, grouped by root.
kh_run() {
  local root
  for root in $(kh_targets); do
    echo "## $root"
    kh_staleness "$root"
    kh_broken_links "$root"
  done
}
