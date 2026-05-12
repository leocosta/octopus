#!/usr/bin/env bash
# cli/lib/setup-picker.sh — Single-screen setup picker (fzf or bash fallback).
# Exports: PICKER_BUNDLE, PICKER_HOOKS, PICKER_WORKFLOW,
#          PICKER_REVIEWERS, PICKER_MCP_ENABLED
# Sourced by cli/lib/setup.sh — never executed directly.

_PICKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=./ui.sh
source "$_PICKER_DIR/ui.sh"

# Defaults (overwritten by run_picker)
PICKER_BUNDLE="starter"
PICKER_HOOKS="true"
PICKER_WORKFLOW="true"
PICKER_REVIEWERS=""
PICKER_MCP_ENABLED="false"

# ---------------------------------------------------------------------------
# fzf resolution: system fzf → bundled fzf → empty (bash fallback)
# ---------------------------------------------------------------------------
_picker_resolve_fzf() {
  if command -v fzf &>/dev/null; then
    echo "fzf"
    return
  fi
  local release_dir
  release_dir="$(cd "$_PICKER_DIR/../.." && pwd)"
  local os arch bin
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] && arch="amd64"
  [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && arch="arm64"
  bin="$release_dir/bin/fzf/${os}-${arch}/fzf"
  if [[ -x "$bin" ]]; then
    echo "$bin"
    return
  fi
  echo ""
}

_PICKER_FZF="$(_picker_resolve_fzf)"

# ---------------------------------------------------------------------------
# Bundle and feature definitions
# ---------------------------------------------------------------------------
_PICKER_BUNDLES=(starter docs quality growth backend)
_PICKER_BUNDLE_DESCS=(
  "implement, debug, review-pr, delegate, doc-adr"
  "ADRs, specs, plans, roadmap, continuous-learning"
  "audit-all (security/money/tenant), review-contracts"
  "launch-feature, launch-release, content-images"
  "backend-patterns, test-e2e"
)
_PICKER_FEATURES=(hooks workflow reviewers mcp)
_PICKER_FEATURE_DESCS=(
  "destructive-guard, session-start"
  "pr-open, pr-merge, release"
  "→ prompted after install"
  "→ prompted after install"
)
_PICKER_FEATURE_DEFAULTS=(true true false false)

# ---------------------------------------------------------------------------
# fzf picker — single multi-select screen
# ---------------------------------------------------------------------------
_picker_run_fzf() {
  local fzf_bin="$1"

  # Build display lines. Format: "bundle:<name>  <desc>" or "feature:[on/  ] <name>  <desc>"
  local lines=()
  local i
  lines+=("  ── Bundle ─────────────────────────────────────────────────")
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    lines+=("bundle:${_PICKER_BUNDLES[$i]}  ${_PICKER_BUNDLE_DESCS[$i]}")
  done
  lines+=("  ── Features ────────────────────────────────────────────────")
  for (( i=0; i<${#_PICKER_FEATURES[@]}; i++ )); do
    local prefix
    [[ "${_PICKER_FEATURE_DEFAULTS[$i]}" == "true" ]] && prefix="[on] " || prefix="[  ] "
    lines+=("feature:${prefix}${_PICKER_FEATURES[$i]}  ${_PICKER_FEATURE_DESCS[$i]}")
  done

  local header
  header="  TAB/SPACE = toggle   ENTER = confirm   Ctrl-C = cancel"

  local selected
  selected=$(printf '%s\n' "${lines[@]}" | \
    "$fzf_bin" \
      --multi \
      --no-sort \
      --layout=reverse \
      --header="$header" \
      --height=~60% \
      --border=rounded \
      --prompt="  Octopus Setup › " \
      --pointer="▶" \
      --marker="✓" \
      2>/dev/tty) || { ui_warn "Setup cancelled."; exit 0; }

  # Parse bundle (first bundle: line selected; if none, keep default)
  local bundle_line
  bundle_line=$(printf '%s\n' "$selected" | grep "^bundle:" | head -1 || true)
  if [[ -n "$bundle_line" ]]; then
    PICKER_BUNDLE=$(printf '%s' "$bundle_line" | sed 's/^bundle:\([^ ]*\).*/\1/')
  fi

  # Parse features: selected feature lines are enabled; unselected follow their defaults
  # Since fzf multi-select means TAB-selected = chosen, we reset defaults and apply selections
  # Default-on features (hooks, workflow) stay true unless user explicitly deselected them.
  # We use a simpler model: whatever feature lines appear in the output are "enabled".
  PICKER_HOOKS="false"
  PICKER_WORKFLOW="false"
  local feat_lines
  feat_lines=$(printf '%s\n' "$selected" | grep "^feature:" || true)
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    local fname
    fname=$(printf '%s' "$line" | sed 's/^feature:\[.*\] \([^ ]*\).*/\1/')
    case "$fname" in
      hooks)     PICKER_HOOKS="true" ;;
      workflow)  PICKER_WORKFLOW="true" ;;
      reviewers) PICKER_REVIEWERS="__ask__" ;;
      mcp)       PICKER_MCP_ENABLED="true" ;;
    esac
  done <<< "$feat_lines"
}

# ---------------------------------------------------------------------------
# Bash fallback — numbered list + read
# ---------------------------------------------------------------------------
_picker_run_bash() {
  echo ""
  echo "  Available bundles:"
  local i
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    printf "    %d. %-12s %s\n" "$((i+1))" "${_PICKER_BUNDLES[$i]}" "${_PICKER_BUNDLE_DESCS[$i]}"
  done
  echo ""
  printf "  Bundle [1]: "
  local choice
  read -r choice </dev/tty
  choice="${choice:-1}"
  if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#_PICKER_BUNDLES[@]} )); then
    PICKER_BUNDLE="${_PICKER_BUNDLES[$((choice-1))]}"
  else
    PICKER_BUNDLE="starter"
  fi

  echo ""
  echo "  Features (Enter = keep default, y/n = change):"
  _picker_bash_yn "  Hooks (destructive-guard, session-start)" "y" \
    && PICKER_HOOKS="true" || PICKER_HOOKS="false"
  _picker_bash_yn "  Workflow commands (pr-open, pr-merge, release)" "y" \
    && PICKER_WORKFLOW="true" || PICKER_WORKFLOW="false"
  _picker_bash_yn "  Configure reviewers" "n" \
    && PICKER_REVIEWERS="__ask__" || PICKER_REVIEWERS=""
  _picker_bash_yn "  Configure MCP servers" "n" \
    && PICKER_MCP_ENABLED="true" || PICKER_MCP_ENABLED="false"
  echo ""
}

_picker_bash_yn() {
  local prompt="$1" default="$2"
  local hint
  [[ "$default" == "y" ]] && hint="[Y/n]" || hint="[y/N]"
  printf "%s %s " "$prompt" "$hint"
  local reply
  read -r reply </dev/tty
  reply="${reply:-$default}"
  [[ "${reply,,}" == "y" ]]
}

# ---------------------------------------------------------------------------
# Public entry point
# ---------------------------------------------------------------------------
run_picker() {
  if [[ -n "$_PICKER_FZF" ]]; then
    _picker_run_fzf "$_PICKER_FZF"
  else
    _picker_run_bash
  fi
}
