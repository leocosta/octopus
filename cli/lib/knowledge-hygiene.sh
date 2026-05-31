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

# Read a frontmatter scalar field's value (empty if absent), stopping at the
# closing `---`.
kh_frontmatter() {
  awk -F': *' -v k="$2" '$1==k {print $2; exit} /^---/ && NR>1 {exit}' "$1"
}

# Last-update epoch of a node, by cascade: frontmatter `updated:` → git
# last-commit → filesystem mtime. The first that resolves wins.
kh_last_update() {
  local f="$1" v
  v="$(kh_frontmatter "$f" updated)"
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

# Read hygiene-specific per-root config (orphan_allowlist, terminal_status, …)
# directly from the override layers — these keys are not part of the kr schema.
kh_config() {
  local root="$1" field="$2" v u
  v="$(kr_override "$KR_PROJECT_YML" "$root" "$field")"
  u="$(kr_override "$KR_USER_YML" "$root" "$field")"; [[ -n "$u" ]] && v="$u"
  printf '%s' "$v"
}

# Entry nodes are legitimately unlinked-to and must not count as orphans.
KH_ENTRY_RE='/(README|index|roadmap)[^/]*$'

# Flag nodes with no inbound links, excluding entry patterns and the root's
# comma-separated orphan_allowlist.
kh_orphans() {
  local root="$1" allow inbound node
  allow="$(kh_config "$root" orphan_allowlist)"
  inbound="$(while read -r node; do kr_links "$root" "$node"; done < <(kr_nodes "$root") | sort -u)"
  while read -r node; do
    if grep -qE "$KH_ENTRY_RE" <<<"$node"; then continue; fi
    if [[ -n "$allow" && ",$allow," == *",$(basename "$node"),"* ]]; then continue; fi
    if ! grep -qxF "$node" <<<"$inbound"; then echo "info|$root|orphan|$node|no inbound links"; fi
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

# Flag nodes whose frontmatter status is terminal but that still live outside
# the root's archive dir.
kh_archive_drift() {
  local root="$1" arch terminal status node
  arch="$(kr_archive "$root")"; [[ -n "$arch" ]] || return 0
  terminal="$(kh_config "$root" terminal_status)"; terminal="${terminal:-done,closed,archived}"
  while read -r node; do
    [[ "$node" == "$arch"* ]] && continue
    status="$(kh_frontmatter "$node" status)"
    if [[ -n "$status" && ",$terminal," == *",$status,"* ]]; then
      echo "info|$root|archive-drift|$node|status=$status"
    fi
  done < <(kr_nodes "$root")
}

# Reversible fix: git mv each archive-drift node into the root's archive dir.
kh_fix_archive() {
  local root="$1" arch node
  arch="$(kr_archive "$root")"; [[ -n "$arch" ]] || return 0
  kh_archive_drift "$root" | while IFS='|' read -r _ _ _ node _; do
    mkdir -p "$arch"
    git mv "$node" "$arch" 2>/dev/null || mv "$node" "$arch"
  done
}

# Run the enabled checks over each target root, grouped by root.
# With KH_FIX, apply the reversible remedies after reporting.
kh_run() {
  local root
  for root in $(kh_targets); do
    echo "## $root"
    kh_staleness "$root"
    kh_broken_links "$root"
    kh_orphans "$root"
    kh_archive_drift "$root"
    if [[ "${KH_FIX:-0}" == 1 ]]; then kh_fix_archive "$root"; fi
  done
}
