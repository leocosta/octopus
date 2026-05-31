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

# Watermark — per-root "since you last looked", user-scoped (never the repo).
KB_STATE_DIR="${KB_STATE_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/octopus/briefing-state}"
kb_watermark_get() { local f="$KB_STATE_DIR/$1"; if [[ -f "$f" ]]; then cat "$f"; else echo 0; fi; }
kb_watermark_set() { mkdir -p "$KB_STATE_DIR"; printf '%s\n' "$2" >"$KB_STATE_DIR/$1"; }

# Resolve the "since" epoch for a root: --since window > stored watermark > 7d default.
kb_since() {
  local root="$1" wm
  if [[ -n "${KB_SINCE:-}" ]]; then date -d "$KB_SINCE ago" +%s 2>/dev/null && return; fi
  wm="$(kb_watermark_get "$root")"
  if [[ "$wm" -gt 0 ]]; then echo "$wm"; return; fi
  date -d '7 days ago' +%s
}

# Target roots: an explicit --root id, else every resolved root.
kb_targets() {
  if [[ -n "${KB_ROOT:-}" ]]; then printf '%s\n' "$KB_ROOT"
  else kr_load | cut -d'|' -f1; fi
}

# Last-update epoch of a node, by cascade: frontmatter `updated:` → git
# last-commit → filesystem mtime (same signal as knowledge-hygiene).
kb_last_update() {
  local f="$1" v
  v="$(awk -F': *' '$1=="updated"{print $2; exit} /^---/ && NR>1 {exit}' "$f")"
  if [[ -n "$v" ]] && v="$(date -d "$v" +%s 2>/dev/null)"; then printf '%s' "$v"; return; fi
  v="$(git -C "$(dirname "$f")" log -1 --format=%ct -- "$f" 2>/dev/null)"
  [[ -n "$v" ]] && { printf '%s' "$v"; return; }
  stat -c %Y "$f"
}

# changed: nodes whose last update is newer than the since-epoch.
kb_changed() {
  local root="$1" since="$2" node
  while read -r node; do
    if [[ "$(kb_last_update "$node")" -gt "$since" ]]; then
      echo "changed|$root|$node|updated"
    fi
  done < <(kr_nodes "$root")
}

OCTOPUS_BIN="$KB_DIR/../octopus.sh"

# attention: fold knowledge-hygiene's warn-tier findings (overdue/stale/broken).
kb_attention() {
  "$OCTOPUS_BIN" hygiene --root "$1" 2>/dev/null \
  | awk -F'|' -v r="$1" '$1=="warn"{print "attention|" r "|" $4 "|" $3 " " $5}'
}

# connection: weekly only — fold knowledge-synthesize's cross-node candidates.
kb_connections() {
  "$OCTOPUS_BIN" synthesize --root "$1" 2>/dev/null \
  | awk -F'|' -v r="$1" '$1=="shared-target" || $1=="co-mention" {print "connection|" r "|" $3 "|" $1}'
}

# Emit the briefing sections for each target root, grouped by root.
kb_run() {
  local root since
  for root in $(kb_targets); do
    echo "## $root"
    since="$(kb_since "$root")"
    kb_changed "$root" "$since"
    kb_attention "$root"
    if [[ "$KB_MODE" == weekly ]]; then kb_connections "$root"; fi
  done
}
