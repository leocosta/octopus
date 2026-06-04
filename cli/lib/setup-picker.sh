#!/usr/bin/env bash
# cli/lib/setup-picker.sh — Single-screen setup picker (fzf or bash fallback).
# Exports: PICKER_BUNDLES (array), PICKER_HOOKS, PICKER_WORKFLOW,
#          PICKER_REVIEWERS, PICKER_MCP_ENABLED
# Sourced by cli/lib/setup.sh — never executed directly.

_PICKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PICKER_RELEASE_ROOT="$(cd "$_PICKER_DIR/../.." && pwd)"

# shellcheck source=./ui.sh
source "$_PICKER_DIR/ui.sh"

# Defaults (overwritten by run_picker)
PICKER_BUNDLES=("starter")
PICKER_HOOKS="true"
PICKER_WORKFLOW="true"
PICKER_REVIEWERS=""
PICKER_MCP_ENABLED="false"
PICKER_CUSTOMIZE="false"
PICKER_EXCLUDE=()

# ---------------------------------------------------------------------------
# fzf resolution: system fzf → bundled fzf → empty (bash fallback)
# ---------------------------------------------------------------------------
_picker_resolve_fzf() {
  if command -v fzf &>/dev/null; then
    echo "fzf"
    return
  fi
  local os arch bin
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  [[ "$arch" == "x86_64" ]] && arch="amd64"
  [[ "$arch" == "aarch64" || "$arch" == "arm64" ]] && arch="arm64"
  bin="$_PICKER_RELEASE_ROOT/bin/fzf/${os}-${arch}/fzf"
  if [[ -x "$bin" ]]; then
    echo "$bin"
    return
  fi
  echo ""
}

_PICKER_FZF="$(_picker_resolve_fzf)"

# ---------------------------------------------------------------------------
# Bundle auto-discovery — enumerate $RELEASE/bundles/*.yml in stable order
# (starter first, then alphabetical) so new bundles surface in the picker
# without code changes.
# ---------------------------------------------------------------------------
_PICKER_BUNDLES=()
_PICKER_BUNDLE_DESCS=()

_picker_load_bundles() {
  _PICKER_BUNDLES=()
  _PICKER_BUNDLE_DESCS=()
  local bundles_dir="$_PICKER_RELEASE_ROOT/bundles"
  [[ -d "$bundles_dir" ]] || return 0

  local ordered=()
  if [[ -f "$bundles_dir/starter.yml" ]]; then
    ordered+=("starter")
  fi
  local f name
  for f in "$bundles_dir"/*.yml; do
    [[ -f "$f" ]] || continue
    name="$(basename "$f" .yml)"
    [[ "$name" == "starter" ]] && continue
    ordered+=("$name")
  done

  for name in "${ordered[@]}"; do
    f="$bundles_dir/$name.yml"
    local desc
    desc="$(grep -m1 '^description:' "$f" | sed 's/^description:[[:space:]]*//' | sed 's/^"//;s/"$//' || true)"
    _PICKER_BUNDLES+=("$name")
    _PICKER_BUNDLE_DESCS+=("${desc:-(no description)}")
  done
}

_picker_load_bundles

_PICKER_FEATURES=(hooks workflow reviewers mcp customize)
_PICKER_FEATURE_DESCS=(
  "destructive-guard, session-start"
  "pr-open, pr-merge, release"
  "→ prompted after install"
  "→ prompted after install"
  "→ deselect individual skills from the chosen bundles"
)
# Built-in defaults — used only when manifest absent OR key missing.
_PICKER_FEATURE_DEFAULTS=(true true false false false)

# ---------------------------------------------------------------------------
# Current state — read existing .octopus.yml so the picker reflects what's
# already in effect instead of opening with everything unchecked.
# ---------------------------------------------------------------------------
_CURRENT_BUNDLES=()
_CURRENT_HOOKS=""
_CURRENT_WORKFLOW=""
_CURRENT_MCP=""

_picker_load_current_state() {
  _CURRENT_BUNDLES=()
  _CURRENT_HOOKS=""
  _CURRENT_WORKFLOW=""
  _CURRENT_MCP=""

  local manifest="${MANIFEST_PATH:-${PROJECT_ROOT:-$PWD}/.octopus.yml}"
  [[ -f "$manifest" ]] || return 0

  local in_bundles=0 in_mcp=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    # New top-level key resets list-tracking
    if [[ "$line" =~ ^[a-zA-Z] ]]; then
      in_bundles=0
      in_mcp=0
    fi
    if [[ "$line" =~ ^bundles:[[:space:]]*$ ]]; then
      in_bundles=1
      continue
    fi
    if [[ "$line" =~ ^mcp:[[:space:]]*$ ]]; then
      in_mcp=1
      continue
    fi
    if [[ $in_bundles -eq 1 && "$line" =~ ^[[:space:]]+-[[:space:]]*([a-zA-Z][a-zA-Z0-9_-]*) ]]; then
      _CURRENT_BUNDLES+=("${BASH_REMATCH[1]}")
      continue
    fi
    if [[ $in_mcp -eq 1 && "$line" =~ ^[[:space:]]+-[[:space:]]*([a-zA-Z][a-zA-Z0-9_-]*) ]]; then
      _CURRENT_MCP="true"
      continue
    fi
    if [[ "$line" =~ ^hooks:[[:space:]]*(true|false) ]]; then
      _CURRENT_HOOKS="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^workflow:[[:space:]]*(true|false) ]]; then
      _CURRENT_WORKFLOW="${BASH_REMATCH[1]}"
    fi
  done < "$manifest"

  # RM-139: pre-check auto-detected / --stack profiles (stack-*/db-*) even on a
  # fresh repo, so the picker opens with the detected stack/DB already selected.
  # The user's final toggles stay authoritative (unchecking removes it).
  local _p
  for _p in ${SETUP_PROFILES:-}; do
    _picker_array_contains "$_p" "${_CURRENT_BUNDLES[@]}" || _CURRENT_BUNDLES+=("$_p")
  done
}

_picker_array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

_picker_effective_default() {
  # Args: feature_name index_in_defaults_array
  local fname="$1" idx="$2"
  case "$fname" in
    hooks)    [[ -n "$_CURRENT_HOOKS"    ]] && { echo "$_CURRENT_HOOKS";    return; } ;;
    workflow) [[ -n "$_CURRENT_WORKFLOW" ]] && { echo "$_CURRENT_WORKFLOW"; return; } ;;
    mcp)      [[ -n "$_CURRENT_MCP"      ]] && { echo "$_CURRENT_MCP";      return; } ;;
  esac
  echo "${_PICKER_FEATURE_DEFAULTS[$idx]}"
}

# ---------------------------------------------------------------------------
# fzf picker — single multi-select screen with current-state pre-selection
# ---------------------------------------------------------------------------
_picker_run_fzf() {
  local fzf_bin="$1"
  _picker_load_current_state

  # Build selectable lines.
  local bundle_lines=() feature_lines=()
  local i fname effective
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    bundle_lines+=("bundle:${_PICKER_BUNDLES[$i]}  ${_PICKER_BUNDLE_DESCS[$i]}")
  done
  for (( i=0; i<${#_PICKER_FEATURES[@]}; i++ )); do
    fname="${_PICKER_FEATURES[$i]}"
    effective="$(_picker_effective_default "$fname" "$i")"
    local prefix
    [[ "$effective" == "true" ]] && prefix="[on] " || prefix="[  ] "
    feature_lines+=("feature:${prefix}${fname}  ${_PICKER_FEATURE_DESCS[$i]}")
  done

  # Section labels inserted between groups as visual separators. They sit in
  # the same list as the selectable rows (fzf has no native "non-selectable
  # middle line"), but the toggle binds further down guard against marking
  # them with ✓ — see the `transform:` binds for SPACE/TAB/BTAB.
  local all_lines=()
  all_lines+=("  ── Features ─────────────────────────────────────────────────")
  all_lines+=("${feature_lines[@]}")
  all_lines+=("  ── Bundles ──────────────────────────────────────────────────")
  all_lines+=("${bundle_lines[@]}")

  # Build pre-selection bind: for each bundle currently in .octopus.yml, and
  # each feature currently on, compute its 1-based position in all_lines and
  # toggle it on load. Positions count every row in all_lines (separators
  # included), so feature[0] is at row 2 (after the Features separator) and
  # bundle[0] is at row N+3 (after Features separator + N features + Bundle
  # separator). Separator rows themselves are guarded against toggle below.
  local preselect_positions=()
  local feat_pos
  for (( i=0; i<${#_PICKER_FEATURES[@]}; i++ )); do
    fname="${_PICKER_FEATURES[$i]}"
    effective="$(_picker_effective_default "$fname" "$i")"
    feat_pos=$((i + 2))  # +1 for 1-based, +1 for Features separator above
    if [[ "$effective" == "true" && ( "$fname" == "hooks" || "$fname" == "workflow" || "$fname" == "mcp" ) ]]; then
      preselect_positions+=("$feat_pos")
    fi
  done
  local bundle_pos_start=$(( ${#_PICKER_FEATURES[@]} + 3 ))  # +1 base, +2 separators
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    if _picker_array_contains "${_PICKER_BUNDLES[$i]}" "${_CURRENT_BUNDLES[@]}"; then
      preselect_positions+=("$(( bundle_pos_start + i ))")
    fi
  done

  local load_bind=""
  if [[ ${#preselect_positions[@]} -gt 0 ]]; then
    local p
    for p in "${preselect_positions[@]}"; do
      load_bind+="pos($p)+toggle+"
    done
    load_bind="${load_bind%+}"
  fi

  local header
  if [[ ${#_CURRENT_BUNDLES[@]} -gt 0 || -n "$_CURRENT_HOOKS$_CURRENT_WORKFLOW" ]]; then
    header="  SPACE/TAB = toggle   ENTER = confirm   Ctrl-C = cancel    (✓ = current config)"
  else
    header="  SPACE/TAB = toggle   ENTER = confirm   Ctrl-C = cancel"
  fi

  local fzf_args=(
    --multi
    --no-sort
    --layout=reverse
    --header="$header"
    --header-lines=0
    --height=~80%
    --border=rounded
    --prompt="  Octopus Setup › "
    --pointer="▶"
    --marker="✓"
    # Guard toggle on separator rows ("── Features ──" / "── Bundles ──"):
    # fzf's `transform:` action (fzf >= 0.52) lets us conditionally choose
    # the action per current line. On separator rows we substitute `ignore`
    # (or a plain `down`/`up` for tab/btab) so SPACE/TAB no longer mark
    # them with ✓. Older fzf treats `transform:` as unknown and falls back
    # to no-op; the separators stay visually toggleable but are still
    # filtered post-selection (see `grep "^bundle:"` / `grep "^feature:"`
    # parsing below).
    --bind='space:transform:[[ {} == *──* ]] && echo "ignore" || echo "toggle"'
    --bind='tab:transform:[[ {} == *──* ]] && echo "down" || echo "toggle+down"'
    --bind='btab:transform:[[ {} == *──* ]] && echo "up" || echo "toggle+up"'
  )
  [[ -n "$load_bind" ]] && fzf_args+=(--bind="load:$load_bind")

  local selected
  selected=$(printf '%s\n' "${all_lines[@]}" | \
    "$fzf_bin" "${fzf_args[@]}" 2>/dev/tty) || { ui_warn "Setup cancelled."; exit 0; }

  # Parse bundles — collect all selected bundle lines (multi-select)
  local bundle_lines_out
  bundle_lines_out=$(printf '%s\n' "$selected" | grep "^bundle:" || true)
  PICKER_BUNDLES=()
  if [[ -n "$bundle_lines_out" ]]; then
    while IFS= read -r bundle_line; do
      [[ -z "$bundle_line" ]] && continue
      PICKER_BUNDLES+=("$(printf '%s' "$bundle_line" | sed 's/^bundle:\([^ ]*\).*/\1/')")
    done <<< "$bundle_lines_out"
  fi

  # Parse features: selected features are ON, others are OFF (inclusion model
  # now that pre-selection mirrors current state).
  PICKER_HOOKS="false"
  PICKER_WORKFLOW="false"
  PICKER_REVIEWERS=""
  PICKER_MCP_ENABLED="false"
  PICKER_CUSTOMIZE="false"
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
      customize) PICKER_CUSTOMIZE="true" ;;
    esac
  done <<< "$feat_lines"

  # RM-146: optional second pass — deselect individual skills/roles from the
  # chosen bundles. Whatever the user unchecks becomes the manifest exclude:.
  if [[ "$PICKER_CUSTOMIZE" == "true" ]]; then
    _picker_member_deselect "$fzf_bin"
  fi
}

# Shallow union of the skills + roles + rules listed across the given bundle
# ymls (de-duplicated, stable order). Rules are included so a stack/db profile's
# rule (e.g. `typescript`) is deselectable too — `_apply_excludes` already drops
# from OCTOPUS_RULES. Pure/testable — no fzf, no globals consumed.
_picker_member_union() {
  local b f line in_list seen=" " name
  for b in "$@"; do
    f="$_PICKER_RELEASE_ROOT/bundles/$b.yml"
    [[ -f "$f" ]] || continue
    in_list=""
    while IFS= read -r line || [[ -n "$line" ]]; do
      case "$line" in
        skills:*|roles:*|rules:*) in_list="yes" ;;
        mcp:*|hooks:*|name:*|category:*|description:*|persona_*) in_list="" ;;
        [[:space:]]*-*)
          [[ -n "$in_list" ]] || continue
          name="${line#*- }"; name="${name%%#*}"; name="${name//[[:space:]]/}"
          [[ -z "$name" || "$name" == "[]" ]] && continue
          case "$seen" in *" $name "*) ;; *) seen+="$name "; printf '%s\n' "$name" ;; esac
          ;;
      esac
    done < "$f"
  done
}

# Phase-2 fzf: pre-check every member; PICKER_EXCLUDE = union minus what stays.
_picker_member_deselect() {
  local fzf_bin="$1"
  PICKER_EXCLUDE=()
  local -a _union=()
  while IFS= read -r m; do [[ -n "$m" ]] && _union+=("$m"); done \
    < <(_picker_member_union "${PICKER_BUNDLES[@]}")
  [[ ${#_union[@]} -eq 0 ]] && return 0

  # All members start checked (load:toggle every row); unchecking = exclude.
  local load_bind="" i
  for (( i=0; i<${#_union[@]}; i++ )); do load_bind+="pos($((i+1)))+toggle+"; done
  load_bind="${load_bind%+}"

  local kept
  kept=$(printf '%s\n' "${_union[@]}" | "$fzf_bin" \
    --multi --no-sort --layout=reverse --height=~80% --border=rounded \
    --prompt="  Keep these members › " --pointer="▶" --marker="✓" \
    --header="  SPACE/TAB = toggle   ENTER = confirm   (unchecked → excluded)" \
    --bind="load:$load_bind" 2>/dev/tty) || kept=""

  # Exclude = union members not in the kept set.
  local u keptnl=$'\n'"$kept"$'\n'
  for u in "${_union[@]}"; do
    case "$keptnl" in *$'\n'"$u"$'\n'*) ;; *) PICKER_EXCLUDE+=("$u") ;; esac
  done
}

# Map a space/comma-separated list of 1-based indices to the union members they
# select (for exclusion). Out-of-range and non-numeric tokens are ignored.
# Pure/testable — no tty, no globals. Mirrors the bundle index parsing.
_picker_indices_to_members() {
  local raw="$1"; shift
  local -a union=("$@")
  local norm tok
  norm=$(printf '%s' "$raw" | tr ',\t' '  ' | tr -s ' ')
  for tok in $norm; do
    [[ "$tok" =~ ^[1-9][0-9]*$ ]] || continue
    (( tok >= 1 && tok <= ${#union[@]} )) || continue
    printf '%s\n' "${union[$((tok-1))]}"
  done
}

# Bash-fallback counterpart of _picker_member_deselect: numbered union, the user
# enters the indices to EXCLUDE (default none → keep all). Sets PICKER_EXCLUDE.
_picker_member_deselect_bash() {
  PICKER_EXCLUDE=()
  local -a _union=()
  while IFS= read -r m; do [[ -n "$m" ]] && _union+=("$m"); done \
    < <(_picker_member_union "${PICKER_BUNDLES[@]}")
  [[ ${#_union[@]} -eq 0 ]] && return 0

  echo ""
  echo "  Members from your bundles (all kept by default):"
  local i
  for (( i=0; i<${#_union[@]}; i++ )); do
    printf "    %2d. %s\n" "$((i+1))" "${_union[$i]}"
  done
  printf "  Numbers to EXCLUDE — space/comma-separated [none]: "
  local raw; read -r raw </dev/tty; raw="${raw:-}"
  while IFS= read -r m; do [[ -n "$m" ]] && PICKER_EXCLUDE+=("$m"); done \
    < <(_picker_indices_to_members "$raw" "${_union[@]}")
}

# ---------------------------------------------------------------------------
# Bash fallback — numbered list + read, with [*] markers for current state
# ---------------------------------------------------------------------------
_picker_run_bash() {
  _picker_load_current_state

  echo ""
  echo "  Available bundles (✓ = currently in .octopus.yml):"
  local i marker
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    if _picker_array_contains "${_PICKER_BUNDLES[$i]}" "${_CURRENT_BUNDLES[@]}"; then
      marker="✓"
    else
      marker=" "
    fi
    printf "    %d. [%s] %-12s %s\n" "$((i+1))" "$marker" "${_PICKER_BUNDLES[$i]}" "${_PICKER_BUNDLE_DESCS[$i]}"
  done
  echo ""

  # Default for the input: numbers of currently-selected bundles, or "1" if none.
  local current_indices=()
  for (( i=0; i<${#_PICKER_BUNDLES[@]}; i++ )); do
    if _picker_array_contains "${_PICKER_BUNDLES[$i]}" "${_CURRENT_BUNDLES[@]}"; then
      current_indices+=("$((i+1))")
    fi
  done
  local default_input
  if [[ ${#current_indices[@]} -gt 0 ]]; then
    default_input="${current_indices[*]}"
  else
    default_input="1"
  fi

  PICKER_BUNDLES=()
  while true; do
    printf "  Bundle(s) — space or comma-separated [%s]: " "$default_input"
    local raw_choice
    read -r raw_choice </dev/tty
    raw_choice="${raw_choice:-$default_input}"
    local normalised
    normalised=$(printf '%s' "$raw_choice" | tr ',\t' '  ' | tr -s ' ')
    local invalid=() valid_picks=()
    local token
    for token in $normalised; do
      if [[ "$token" =~ ^[1-9][0-9]*$ ]] && (( token >= 1 && token <= ${#_PICKER_BUNDLES[@]} )); then
        valid_picks+=("${_PICKER_BUNDLES[$((token-1))]}")
      else
        invalid+=("$token")
      fi
    done
    if [[ ${#invalid[@]} -gt 0 ]]; then
      printf "  Invalid: %s — enter numbers 1–%d\n" "${invalid[*]}" "${#_PICKER_BUNDLES[@]}"
      continue
    fi
    if [[ ${#valid_picks[@]} -eq 0 ]]; then
      printf "  Enter at least one number.\n"
      continue
    fi
    PICKER_BUNDLES=("${valid_picks[@]}")
    break
  done

  # Feature defaults follow current state when present.
  local hooks_default workflow_default
  [[ "$_CURRENT_HOOKS" == "false" ]] && hooks_default="n" || hooks_default="y"
  [[ "$_CURRENT_WORKFLOW" == "false" ]] && workflow_default="n" || workflow_default="y"

  echo ""
  echo "  Features (Enter = keep current, y/n = change):"
  _picker_bash_yn "  Hooks (destructive-guard, session-start)" "$hooks_default" \
    && PICKER_HOOKS="true" || PICKER_HOOKS="false"
  _picker_bash_yn "  Workflow commands (pr-open, pr-merge, release)" "$workflow_default" \
    && PICKER_WORKFLOW="true" || PICKER_WORKFLOW="false"
  _picker_bash_yn "  Configure reviewers" "n" \
    && PICKER_REVIEWERS="__ask__" || PICKER_REVIEWERS=""
  _picker_bash_yn "  Configure MCP servers" "n" \
    && PICKER_MCP_ENABLED="true" || PICKER_MCP_ENABLED="false"

  # Granular member-deselect — parity with the fzf `customize` step.
  if _picker_bash_yn "  Customize (deselect individual skills/roles/rules)" "n"; then
    PICKER_CUSTOMIZE="true"
    _picker_member_deselect_bash
  fi
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
