#!/usr/bin/env bash
# cli/lib/setup-wizard.sh — Interactive TUI wizard for .octopus.yml configuration
#
# Guides users through all manifest fields with multi-select UI.
# TUI backend priority: fzf > whiptail > dialog > pure bash
#
# Shares the visual vocabulary of cli/lib/ui.sh so the wizard flows into the
# rest of setup.sh without dialect shifts.

# shellcheck source=./ui.sh
_WIZARD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_WIZARD_DIR/ui.sh"

# ---------------------------------------------------------------------------
# Backend detection
# ---------------------------------------------------------------------------

WIZARD_BACKEND=""
WIZARD_IS_WINDOWS=0  # 1 when running under Git Bash / MSYS2 / Cygwin
# Mirror ui.sh capability flags so existing WIZARD_COLORS / WIZARD_UNICODE
# branches (fzf marker selection, ASCII fallbacks in bash multiselect) keep
# working with a single source of truth.
WIZARD_COLORS="$UI_COLORS"
WIZARD_UNICODE="$UI_UNICODE"

_detect_platform() {
  # Detect MSYS2 / Git Bash / Cygwin
  if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin \
     || -n "${MSYSTEM:-}" || -n "${CYGWIN:-}" ]]; then
    WIZARD_IS_WINDOWS=1
  fi
}

_detect_tui_backend() {
  if command -v fzf &>/dev/null; then
    WIZARD_BACKEND="fzf"
  elif (( ! WIZARD_IS_WINDOWS )) && command -v whiptail &>/dev/null; then
    WIZARD_BACKEND="whiptail"
  elif (( ! WIZARD_IS_WINDOWS )) && command -v dialog &>/dev/null; then
    WIZARD_BACKEND="dialog"
  else
    WIZARD_BACKEND="bash"
  fi
}

# ---------------------------------------------------------------------------
# Sober fzf palette
# ---------------------------------------------------------------------------
# whiptail and dialog ship themes that are deeply tied to their color model
# (blue-on-blue windows); trying to override them to "neutral" tends to
# produce unreadable combinations across different terminals. The default
# newt/dialog theme is readable everywhere and safer than a hand-rolled one.
#
# fzf is the only backend whose defaults we nudge: we ask it to inherit the
# terminal foreground/background (so it blends with the scrollback) and
# restrict color to a single cyan accent for focus markers.
#
# Set OCTOPUS_WIZARD_THEME=default to disable the fzf override entirely.

_apply_wizard_theme() {
  [[ "${OCTOPUS_WIZARD_THEME:-sober}" == "default" ]] && return

  export FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS:-} --color=fg:-1,bg:-1,hl:cyan,fg+:-1,bg+:-1,hl+:cyan,border:8,info:8,prompt:cyan,pointer:cyan,marker:cyan,header:8,gutter:-1,spinner:cyan"
}

# ---------------------------------------------------------------------------
# Colors / formatting helpers (thin aliases to cli/lib/ui.sh primitives)
# ---------------------------------------------------------------------------

_bold()  { _ui_bold  "$*"; }
_cyan()  { _ui_cyan  "$*"; }
_green() { _ui_green "$*"; }
_dim()   { _ui_dim   "$*"; }
_hr()    { ui_divider 60; }

# ---------------------------------------------------------------------------
# Core UI primitives
# ---------------------------------------------------------------------------

# _multiselect <title> <description> <items_varname> <defaults_varname>
# Sets WIZARD_SELECTED (array) on return.
WIZARD_SELECTED=()

_multiselect() {
  local title="$1"
  local desc="$2"
  local -n _items="$3"
  local -n _defaults="$4"

  case "$WIZARD_BACKEND" in
    fzf)    _multiselect_fzf    "$title" "$desc" _items _defaults ;;
    whiptail) _multiselect_whiptail "$title" "$desc" _items _defaults ;;
    dialog)   _multiselect_dialog   "$title" "$desc" _items _defaults ;;
    *)        _multiselect_bash     "$title" "$desc" _items _defaults ;;
  esac
}

_multiselect_fzf() {
  local title="$1"
  local desc="$2"
  local -n __items="$3"
  local -n __defaults="$4"

  # Build pre-selected list for fzf
  local header
  header="$(printf '%s\n%s\n%s' "$(_bold "$title")" "$desc" "TAB=toggle  ENTER=confirm  (none = skip)")"

  # Choose markers based on Unicode support
  local pre_sel marker pointer
  (( WIZARD_UNICODE )) && pre_sel="✓ " || pre_sel="* "
  (( WIZARD_UNICODE )) && marker="✓"   || marker=">"
  (( WIZARD_UNICODE )) && pointer="▶"  || pointer=">"

  # Mark defaults with a prefix so fzf can pre-select via --bind
  local input=()
  local item
  for item in "${__items[@]}"; do
    local is_default=0
    local def
    for def in "${__defaults[@]}"; do
      [[ "$def" == "$item" ]] && is_default=1 && break
    done
    if (( is_default )); then
      input+=("${pre_sel}$item")
    else
      input+=("  $item")
    fi
  done

  # Use fzf with a toggle-all binding; strip the prefix on output
  local raw
  raw=$(printf '%s\n' "${input[@]}" | \
    fzf --multi \
        --prompt="  " \
        --header="$header" \
        --height=~40% \
        --layout=reverse \
        --border=rounded \
        --marker="$marker" \
        --pointer="$pointer" \
        --bind='space:toggle' \
        --bind='ctrl-a:toggle-all' \
        --ansi \
        2>/dev/tty) || true

  WIZARD_SELECTED=()
  while IFS= read -r line; do
    # Strip leading pre_sel prefix or spaces and trim
    line="${line#"${pre_sel}"}"
    line="${line#  }"
    line="${line#"${line%%[! ]*}"}"  # ltrim
    [[ -n "$line" ]] && WIZARD_SELECTED+=("$line")
  done <<< "$raw"
}

_multiselect_whiptail() {
  local title="$1"
  local desc="$2"
  local -n __items="$3"
  local -n __defaults="$4"

  local args=()
  local item
  for item in "${__items[@]}"; do
    local state="OFF"
    local def
    for def in "${__defaults[@]}"; do
      [[ "$def" == "$item" ]] && state="ON" && break
    done
    args+=("$item" "" "$state")
  done

  local result
  result=$(whiptail --title "$title" \
    --checklist "$desc\n\nSPACE=toggle  ENTER=confirm" \
    20 60 12 "${args[@]}" \
    3>&1 1>&2 2>&3) || { WIZARD_SELECTED=(); return 0; }

  WIZARD_SELECTED=()
  # whiptail returns quoted items
  eval "local raw_arr=($result)"
  WIZARD_SELECTED=("${raw_arr[@]}")
}

_multiselect_dialog() {
  local title="$1"
  local desc="$2"
  local -n __items="$3"
  local -n __defaults="$4"

  local args=()
  local item
  for item in "${__items[@]}"; do
    local state="off"
    local def
    for def in "${__defaults[@]}"; do
      [[ "$def" == "$item" ]] && state="on" && break
    done
    args+=("$item" "" "$state")
  done

  local result
  result=$(dialog --title "$title" \
    --checklist "$desc" \
    20 60 12 "${args[@]}" \
    2>&1 >/dev/tty) || { WIZARD_SELECTED=(); return 0; }

  WIZARD_SELECTED=()
  eval "local raw_arr=($result)"
  WIZARD_SELECTED=("${raw_arr[@]}")
}

_multiselect_bash() {
  local title="$1"
  local desc="$2"
  local -n __items="$3"
  local -n __defaults="$4"

  echo ""
  echo "$(_bold "$title")"
  [[ -n "$desc" ]] && echo "$(_dim "$desc")"
  echo "$(_dim "Type numbers separated by spaces to select (e.g. 1 3), or press ENTER to keep defaults.")"
  echo ""

  local i=1
  local checked=()
  local item
  for item in "${__items[@]}"; do
    local state=" "
    local def
    for def in "${__defaults[@]}"; do
      [[ "$def" == "$item" ]] && state="x" && break
    done
    checked+=("$state")
    printf "  [%s] %d. %s\n" "$state" "$i" "$item"
    (( i++ ))
  done

  echo ""
  printf "> "
  local input
  read -r input

  # If empty, keep defaults
  if [[ -z "$input" ]]; then
    WIZARD_SELECTED=()
    local j=0
    for item in "${__items[@]}"; do
      [[ "${checked[$j]}" == "x" ]] && WIZARD_SELECTED+=("$item")
      (( j++ ))
    done
    return 0
  fi

  # Toggle specified numbers
  for num in $input; do
    if [[ "$num" =~ ^[0-9]+$ ]] && (( num >= 1 && num <= ${#__items[@]} )); then
      local idx=$(( num - 1 ))
      if [[ "${checked[$idx]}" == "x" ]]; then
        checked[$idx]=" "
      else
        checked[$idx]="x"
      fi
    fi
  done

  WIZARD_SELECTED=()
  local j=0
  for item in "${__items[@]}"; do
    [[ "${checked[$j]}" == "x" ]] && WIZARD_SELECTED+=("$item")
    (( j++ ))
  done
}

# _ask_yn <prompt> <default: y|n>
# Returns 0 for yes, 1 for no.
# Dispatches to the active TUI backend so yes/no prompts share the wizard's
# visual style instead of dropping to a bare shell read.
_ask_yn() {
  local prompt="$1"
  local default="${2:-y}"

  case "$WIZARD_BACKEND" in
    fzf)
      local pos pointer
      [[ "$default" == "y" ]] && pos=1 || pos=2
      (( WIZARD_UNICODE )) && pointer="▶" || pointer=">"
      local choice
      choice=$(printf 'Yes\nNo\n' | \
        fzf --prompt="  $prompt  " \
            --header="$(_dim "ENTER=confirm  ESC=use default ($default)")" \
            --height=~15% \
            --layout=reverse \
            --border=rounded \
            --pointer="$pointer" \
            --bind="load:pos($pos)" \
            --ansi \
            2>/dev/tty) || choice=""
      if [[ -z "$choice" ]]; then
        [[ "$default" == "y" ]] && return 0 || return 1
      fi
      [[ "$choice" == "Yes" ]] && return 0 || return 1
      ;;
    whiptail)
      local args=(--title "Octopus Setup" --yesno "$prompt" 10 60)
      [[ "$default" == "n" ]] && args=(--defaultno "${args[@]}")
      whiptail "${args[@]}"
      ;;
    dialog)
      local args=(--title "Octopus Setup" --yesno "$prompt" 10 60)
      [[ "$default" == "n" ]] && args=(--defaultno "${args[@]}")
      dialog "${args[@]}" 2>/dev/null
      ;;
    *)
      # Bash fallback: inline prompt — no TUI backend to dispatch to.
      local hint
      if [[ "$default" == "y" ]]; then
        hint="[Y/n]"
      else
        hint="[y/N]"
      fi
      printf "%s %s " "$(_bold "$prompt")" "$(_dim "$hint")"
      local reply
      read -r reply
      reply="${reply,,}"
      case "$reply" in
        y|yes) return 0 ;;
        n|no)  return 1 ;;
        *)     [[ "$default" == "y" ]] && return 0 || return 1 ;;
      esac
      ;;
  esac
}

# _ask_text <prompt> <default>
# Sets WIZARD_TEXT on return. Dispatches to the active TUI backend so free-text
# inputs share the wizard's visual style.
WIZARD_TEXT=""
_ask_text() {
  local prompt="$1"
  local default="${2:-}"

  case "$WIZARD_BACKEND" in
    fzf)
      # fzf has no inputbox widget; use --print-query on a single empty item so
      # Enter always terminates and returns whatever the user typed (or the
      # pre-filled query if untouched).
      local typed
      typed=$(echo "" | fzf \
        --prompt="  $prompt: " \
        --header="$(_dim "Type to edit  ENTER=confirm  ESC=keep default")" \
        --query="$default" \
        --print-query \
        --no-info \
        --height=~15% \
        --layout=reverse \
        --border=rounded \
        2>/dev/tty | head -1) || typed=""
      WIZARD_TEXT="${typed:-$default}"
      ;;
    whiptail)
      local result
      result=$(whiptail --title "Octopus Setup" \
        --inputbox "$prompt" 10 70 "$default" \
        3>&1 1>&2 2>&3) || result="$default"
      WIZARD_TEXT="${result:-$default}"
      ;;
    dialog)
      local result
      result=$(dialog --title "Octopus Setup" \
        --inputbox "$prompt" 10 70 "$default" \
        2>&1 >/dev/tty) || result="$default"
      WIZARD_TEXT="${result:-$default}"
      ;;
    *)
      local hint=""
      [[ -n "$default" ]] && hint=" $(_dim "(default: $default)")"
      printf "%s%s: " "$(_bold "$prompt")" "$hint"
      local reply
      read -r reply
      WIZARD_TEXT="${reply:-$default}"
      ;;
  esac
}

# _select_one <title> <desc> <items_varname> <default>
# Sets WIZARD_TEXT on return
_select_one() {
  local title="$1"
  local desc="$2"
  local -n _so_items="$3"
  local default="$4"

  case "$WIZARD_BACKEND" in
    fzf)
      local header
      header="$(printf '%s\n%s' "$(_bold "$title")" "$desc")"
      local result
      result=$(printf '%s\n' "${_so_items[@]}" | \
        fzf --prompt="  " \
            --header="$header" \
            --height=~30% \
            --layout=reverse \
            --border=rounded \
            --pointer="▶" \
            2>/dev/tty) || result="$default"
      WIZARD_TEXT="${result:-$default}"
      ;;
    whiptail)
      local args=()
      local i=1
      local item
      for item in "${_so_items[@]}"; do
        args+=("$item" "" "$([[ "$item" == "$default" ]] && echo ON || echo OFF)")
        (( i++ ))
      done
      local result
      result=$(whiptail --title "$title" \
        --radiolist "$desc" \
        15 60 8 "${args[@]}" \
        3>&1 1>&2 2>&3) || result="$default"
      WIZARD_TEXT="${result:-$default}"
      ;;
    dialog)
      local args=()
      local item
      for item in "${_so_items[@]}"; do
        args+=("$item" "" "$([[ "$item" == "$default" ]] && echo on || echo off)")
      done
      local result
      result=$(dialog --title "$title" \
        --radiolist "$desc" \
        15 60 8 "${args[@]}" \
        2>&1 >/dev/tty) || result="$default"
      WIZARD_TEXT="${result:-$default}"
      ;;
    *)
      echo ""
      echo "$(_bold "$title")"
      [[ -n "$desc" ]] && echo "$(_dim "$desc")"
      echo ""
      local i=1
      local item
      local default_idx=1
      for item in "${_so_items[@]}"; do
        local marker=" "
        [[ "$item" == "$default" ]] && marker="*" && default_idx=$i
        printf "  [%s] %d. %s\n" "$marker" "$i" "$item"
        (( i++ ))
      done
      echo ""
      local _def_hint; _def_hint="$(_dim "(default: $default_idx)")"
      printf "> %s " "$_def_hint"
      local reply
      read -r reply
      if [[ "$reply" =~ ^[0-9]+$ ]] && (( reply >= 1 && reply <= ${#_so_items[@]} )); then
        WIZARD_TEXT="${_so_items[$(( reply - 1 ))]}"
      else
        WIZARD_TEXT="$default"
      fi
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Wizard state variables
# ---------------------------------------------------------------------------

WIZARD_AGENTS=()
WIZARD_RULES=()
WIZARD_SKILLS=()
WIZARD_ROLES=()
declare -A ROLE_SKILL_MAP=(
  ["backend-developer"]="backend-patterns audit-tenant audit-money audit-security debug"
  ["frontend-developer"]="test-e2e review-contracts debug"
  ["product-manager"]="doc-adr plan-backlog doc-lifecycle doc-design doc-plan"
  ["writer"]="doc-adr doc-design doc-plan continuous-learning"
  ["marketer"]="launch-feature launch-release"
  ["architect"]="audit-all review-contracts"
)
WIZARD_MCP=()
WIZARD_BUNDLES=()
WIZARD_LANGUAGE=""
WIZARD_LANGUAGE_DOCS=""
WIZARD_LANGUAGE_CODE=""
WIZARD_LANGUAGE_UI=""
WIZARD_LANGUAGE_EXPANDED=0
WIZARD_HOOKS=""
WIZARD_WORKFLOW=""
WIZARD_REVIEWERS=()
WIZARD_COMMANDS=()   # "name|description|run" entries
WIZARD_KNOWLEDGE=""

# Advanced settings (RM-011 through RM-016, Claude Code only)
WIZARD_ADVANCED_FLAGS=()      # subset of: worktree memory dream sandbox githubAction
WIZARD_PERMISSION_MODE=""     # "" | plan | auto | acceptEdits
WIZARD_OUTPUT_STYLE=""        # "" | concise | verbose | structured | explanatory

# ---------------------------------------------------------------------------
# Wizard steps
# ---------------------------------------------------------------------------

# _WIZARD_BANNER_SHOWN: print the big title once per wizard session; subsequent
# steps get a cheap separator. Keeps the scrollback continuous (no `clear`) so
# the wizard flows into setup.sh's ui_banner without a visual context switch.
_WIZARD_BANNER_SHOWN=0

_wizard_banner() {
  if (( _WIZARD_BANNER_SHOWN )); then
    echo ""
    _hr
    echo ""
    return
  fi
  _WIZARD_BANNER_SHOWN=1

  echo ""
  local title
  (( WIZARD_UNICODE )) && title="🐙 Octopus Setup Wizard" \
                       || title="** Octopus Setup Wizard **"
  ui_banner "$title"
  printf '  %s\n' "$(_dim "Configure your .octopus.yml interactively")"

  # Nudge toward fzf when we're using a fullscreen backend — inline fzf is the
  # sober scroll-friendly experience; whiptail/dialog themes can't really be
  # tamed without breaking readability on some terminals.
  case "$WIZARD_BACKEND" in
    whiptail|dialog)
      printf '  %s\n' "$(_dim "Tip: install fzf for an inline UI that blends with the terminal — 'sudo apt install fzf' / 'brew install fzf'.")"
      ;;
  esac
  echo ""
}

# _wizard_intro <step> <title> <description_lines...>
# Renders a group header: "Step X/N — Title" plus 1+ dim description lines.
# In --reconfigure mode, or when OCTOPUS_WIZARD_VERBOSE is unset, the
# description lines are suppressed — returning users already know what
# each group configures and don't need the explanatory paragraphs again.
_wizard_intro() {
  local step="$1"
  local title="$2"
  shift 2
  printf "  %s — %s\n\n" "$(_bold "Step $step")" "$(_cyan "$title")"

  # Compact mode: skip description lines in reconfigure unless explicitly verbose
  if [[ "${WIZARD_RECONFIGURE:-0}" == "1" && "${OCTOPUS_WIZARD_VERBOSE:-0}" != "1" ]]; then
    return 0
  fi

  local line
  for line in "$@"; do
    printf "  %s\n" "$(_dim "$line")"
  done
  printf "\n"
}

# _wizard_subheader <title> [one-line-description]
# Lightweight header used between sub-questions within a group. Does NOT
# print a banner or divider — just an indented arrow + title, so each sub
# picker flows naturally under the group's single banner.
_wizard_subheader() {
  local title="$1"
  local desc="${2:-}"
  local arrow
  (( WIZARD_UNICODE )) && arrow="››" || arrow=">>"
  printf "  %s %s\n" "$(_cyan "$arrow")" "$(_bold "$title")"
  if [[ -n "$desc" && "${WIZARD_RECONFIGURE:-0}" != "1" ]]; then
    printf "  %s\n" "$(_dim "$desc")"
  fi
  printf "\n"
}

# _wizard_hints <entry...>
# Entries are "name|description"; prints an aligned dim "name → description"
# table so the user sees per-item context before picking. Suppressed in
# reconfigure mode (returning users already know the catalog).
_wizard_hints() {
  if [[ "${WIZARD_RECONFIGURE:-0}" == "1" && "${OCTOPUS_WIZARD_VERBOSE:-0}" != "1" ]]; then
    return 0
  fi
  local entry name desc
  for entry in "$@"; do
    name="${entry%%|*}"
    desc="${entry#*|}"
    printf "  %s  %s\n" "$(_dim "$(printf '%-20s' "$name $UI_SYM_ARROW")")" "$(_dim "$desc")"
  done
  printf "\n"
}

_wizard_sub_agents() {
  local items=(claude copilot codex gemini opencode)
  local defaults=("${WIZARD_AGENTS[@]:-claude}")

  _wizard_subheader "Agents" "Which AI assistants Octopus configures for this repo."
  _wizard_hints \
    "claude|Claude Code: native subagents, skills, MCP, hooks" \
    "copilot|GitHub Copilot Chat / agent-mode instructions" \
    "codex|OpenAI Codex CLI" \
    "gemini|Gemini CLI" \
    "opencode|OpenCode (open-source agent)"

  _multiselect \
    "Select agents" \
    "Available: claude, copilot, codex, gemini, opencode" \
    items defaults

  WIZARD_AGENTS=("${WIZARD_SELECTED[@]}")

  if [[ ${#WIZARD_AGENTS[@]} -eq 0 ]]; then
    echo ""
    echo "  $(_dim "⚠  No agents selected. Defaulting to claude.")"
    WIZARD_AGENTS=(claude)
    sleep 1
  fi
}

_wizard_sub_rules() {
  local items=(typescript csharp python)
  local defaults=("${WIZARD_RULES[@]}")

  _wizard_subheader "Rules" "Language-specific coding guidelines. 'common' is always added."
  _wizard_hints \
    "typescript|lint, formatting, type-safety, React/Node patterns" \
    "csharp|.NET conventions, async, DI, LINQ" \
    "python|PEP 8, typing, virtualenv, testing"

  _multiselect \
    "Select rules" \
    "Available: typescript, csharp, python  (common is always added)" \
    items defaults

  WIZARD_RULES=("${WIZARD_SELECTED[@]}")
}

# Persona-driven bundle selection. Reads every bundle YAML with a
# persona_question and asks y/n. Foundation bundles (no persona question)
# are auto-included. Result lands in WIZARD_BUNDLES.
_wizard_sub_bundles() {
  _wizard_subheader "Bundles" \
    "Group skills + roles + rules by intent. Say yes to the ones that apply."

  local bundles_dir
  bundles_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/bundles"

  WIZARD_BUNDLES=()

  local file name desc category question default default_char

  # Pass 1: foundation bundles (always included).
  for file in "$bundles_dir"/*.yml; do
    name=$(awk '/^name: /{print $2; exit}' "$file")
    category=$(awk '/^category: /{print $2; exit}' "$file")
    desc=$(awk -F': ' '/^description: /{sub(/^description:[[:space:]]*/, ""); print; exit}' "$file")
    if [[ "$category" == "foundation" ]]; then
      WIZARD_BUNDLES+=("$name")
      printf "  ✓ %s — %s\n" "$name" "$desc"
    fi
  done

  # Pass 2: intent + stack bundles — ask the persona question.
  for file in "$bundles_dir"/*.yml; do
    name=$(awk '/^name: /{print $2; exit}' "$file")
    category=$(awk '/^category: /{print $2; exit}' "$file")
    [[ "$category" == "foundation" ]] && continue

    question=$(awk -F'"' '/^persona_question: /{print $2; exit}' "$file")
    default=$(awk '/^persona_default: /{print $2; exit}' "$file")
    [[ -z "$question" ]] && continue
    [[ -z "$default" ]] && default="false"

    default_char="n"
    [[ "$default" == "true" ]] && default_char="y"

    if _ask_yn "$question" "$default_char"; then
      WIZARD_BUNDLES+=("$name")
    fi
  done
}

# _skill_impact_table <skill_name...>
# Prints a table showing SKILL.md line count and ~token estimate per skill.
_skill_impact_table() {
  local skills=("$@")
  [[ ${#skills[@]} -eq 0 ]] && return 0

  local skills_dir
  skills_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)/skills"

  printf "\n  %s\n" "$(_dim "Impact of selected skills:")"
  printf "  %-30s %8s %10s\n" "Skill" "Lines" "~Tokens"
  printf "  %s\n" "$(printf '─%.0s' {1..50})"

  local total_lines=0 total_tokens=0
  local skill lines tokens
  for skill in "${skills[@]}"; do
    local skill_file="$skills_dir/$skill/SKILL.md"
    if [[ -f "$skill_file" ]]; then
      lines=$(wc -l < "$skill_file")
    else
      lines=0
    fi
    tokens=$(( lines * 4 ))
    total_lines=$(( total_lines + lines ))
    total_tokens=$(( total_tokens + tokens ))
    printf "  %-30s %8d %10d\n" "$skill" "$lines" "$tokens"
  done

  printf "  %s\n" "$(printf '─%.0s' {1..50})"
  printf "  %-30s %8d %10d\n" "Total" "$total_lines" "$total_tokens"
  printf "\n"
}

_wizard_sub_skills() {
  local items=(audit-all audit-money audit-security audit-tenant backend-patterns compress-skill context-budget continuous-learning debug doc-adr doc-design doc-lifecycle doc-plan dotnet implement launch-feature launch-release plan-backlog review-contracts review-pr test-e2e)
  local defaults=("${WIZARD_SKILLS[@]}")

  local -A recommended=()
  local role skill
  for role in "${WIZARD_ROLES[@]}"; do
    for skill in ${ROLE_SKILL_MAP[$role]:-}; do
      recommended[$skill]=1
    done
  done

  _wizard_subheader "Skills" "Reusable AI capabilities exposed as slash commands."

  local raw_hints=(
    "audit-all|run all quality audits in parallel with consolidated report"
    "audit-money|audit money-logic changes for split/tax/rounding bugs"
    "audit-security|scan diffs for secrets and vulnerabilities"
    "audit-tenant|audit multi-tenant data-scope enforcement (query filters, raw SQL, ownership)"
    "backend-patterns|apply repo/service/DI patterns"
    "compress-skill|shrink a SKILL.md by ~25% with diff review and invariants"
    "context-budget|monitor and trim the conversation context"
    "continuous-learning|capture lessons learned per session"
    "debug|apply the Octopus bug-fix protocol — reproduce, isolate, regression test, document"
    "doc-adr|record Architecture Decision Records"
    "doc-design|drive an interactive spec-design session filling Design, Testing, and adaptive sections"
    "doc-lifecycle|spec → PR → release helpers"
    "doc-plan|turn a completed spec into a bite-sized, TDD-style implementation plan under docs/plans/<slug>.md"
    "dotnet|.NET-specific build/test/format helpers"
    "implement|apply the Octopus workflow — TDD, plan gate, verification, simplify, commit cadence"
    "launch-feature|turn a shipped feature into a launch kit"
    "launch-release|themed release kit for existing users (HTML + channels + slides)"
    "plan-backlog|audit plans/ and roadmap for stale, orphan, or duplicate items"
    "review-contracts|detect API-vs-frontend drift in monorepos"
    "review-pr|apply the Octopus PR-feedback discipline — verify, ask, clarify, never performative"
    "test-e2e|scaffold end-to-end test suites"
  )

  local annotated_hints=()
  local hint skill_name desc
  for hint in "${raw_hints[@]}"; do
    skill_name="${hint%%|*}"
    desc="${hint#*|}"
    if [[ -n "${recommended[$skill_name]:-}" ]]; then
      annotated_hints+=("${skill_name}|★ ${desc}")
    else
      annotated_hints+=("${hint}")
    fi
  done

  _wizard_hints "${annotated_hints[@]}"

  if [[ ${#WIZARD_ROLES[@]} -gt 0 ]]; then
    local roles_joined
    roles_joined="$(IFS=", "; printf '%s' "${WIZARD_ROLES[*]}")"
    printf "  %s\n\n" "$(_dim "★ = recommended for: ${roles_joined}")"
  fi

  _multiselect \
    "Select skills" \
    "audit-all · audit-money · audit-security · audit-tenant · backend-patterns · compress-skill · context-budget · continuous-learning · debug · doc-adr · doc-design · doc-lifecycle · doc-plan · dotnet · implement · launch-feature · launch-release · plan-backlog · review-contracts · review-pr · test-e2e" \
    items defaults

  _skill_impact_table "${WIZARD_SELECTED[@]}"

  WIZARD_SKILLS=("${WIZARD_SELECTED[@]}")
}

_wizard_sub_roles() {
  local items=(architect backend-developer frontend-developer marketer product-manager writer)
  local defaults=("${WIZARD_ROLES[@]}")

  _wizard_subheader "Roles" "Specialized sub-agent personas; each carries its own instructions."
  _wizard_hints \
    "architect|system design review, cross-cutting concerns, quality gates" \
    "backend-developer|APIs, data modeling, server-side logic" \
    "frontend-developer|UI/UX, components, accessibility" \
    "marketer|platform-native posts and campaigns" \
    "product-manager|specs, roadmap, prioritization" \
    "writer|docs, READMEs, release notes"

  _multiselect \
    "Select roles" \
    "architect · backend-developer · frontend-developer · marketer · product-manager · writer" \
    items defaults

  WIZARD_ROLES=("${WIZARD_SELECTED[@]}")
}

_wizard_sub_mcp() {
  local items=(github notion slack postgres)
  local defaults=("${WIZARD_MCP[@]}")

  _wizard_subheader "MCP servers" "External tool integrations; env vars go in .env.octopus."
  _wizard_hints \
    "github|PR/issue/workflow access (GITHUB_TOKEN)" \
    "notion|databases and pages (OAuth, no env vars)" \
    "slack|channels and DMs (SLACK_BOT_TOKEN, SLACK_TEAM_ID)" \
    "postgres|read-only SQL access (DATABASE_URL)"

  _multiselect \
    "Select MCP servers" \
    "github · notion · slack · postgres" \
    items defaults

  WIZARD_MCP=("${WIZARD_SELECTED[@]}")
}

_wizard_sub_language() {
  _wizard_subheader "Language" "Language for AI-generated content; pick default for auto-detect."

  local lang_opts=("en" "pt-br" "es" "fr" "de" "zh" "other")
  local current_default="${WIZARD_LANGUAGE:-en}"

  _select_one \
    "Base language" \
    "Language for docs, code comments, and UI text" \
    lang_opts \
    "$current_default"

  local base="$WIZARD_TEXT"
  if [[ "$base" == "other" ]]; then
    _ask_text "Enter language code (e.g. ja, ko, it)" ""
    base="$WIZARD_TEXT"
  fi

  WIZARD_LANGUAGE="$base"
  WIZARD_LANGUAGE_EXPANDED=0

  echo ""
  if _ask_yn "Configure language per-scope (docs/code/ui separately)?" "n"; then
    WIZARD_LANGUAGE_EXPANDED=1
    echo ""
    _ask_text "Docs language (specs, ADRs, RFCs, README)" "$base"
    WIZARD_LANGUAGE_DOCS="$WIZARD_TEXT"

    _ask_text "Code language (code comments, commit messages, PR descriptions; identifiers always en)" "en"
    WIZARD_LANGUAGE_CODE="$WIZARD_TEXT"

    _ask_text "UI language (user-facing messages, app copy)" "$base"
    WIZARD_LANGUAGE_UI="$WIZARD_TEXT"
  fi
}

_wizard_sub_hooks() {
  _wizard_subheader "Hooks" "Lifecycle enforcement: block --no-verify, detect secrets, auto-format."

  local current_default="y"
  [[ "$WIZARD_HOOKS" == "false" ]] && current_default="n"

  if _ask_yn "Enable hooks?" "$current_default"; then
    WIZARD_HOOKS="true"
  else
    WIZARD_HOOKS="false"
  fi
}

_wizard_sub_workflow() {
  _wizard_subheader "Workflow commands" "/octopus:branch-create, :pr-open, :pr-review, ... (requires gh >= 2.0)."

  local gh_available=0
  command -v gh &>/dev/null && gh_available=1

  local current_default="y"
  if (( ! gh_available )); then
    echo "  $(_dim "⚠  'gh' CLI not found. You can still enable workflow and install gh later.")"
    echo ""
    current_default="n"
  fi
  [[ "$WIZARD_WORKFLOW" == "false" ]] && current_default="n"

  if _ask_yn "Enable workflow commands?" "$current_default"; then
    WIZARD_WORKFLOW="true"
  else
    WIZARD_WORKFLOW="false"
  fi
}

_wizard_sub_reviewers() {
  _wizard_subheader "Default reviewers" "Auto-assigned on /octopus:pr-review."

  local current_default=""
  if [[ ${#WIZARD_REVIEWERS[@]} -gt 0 ]]; then
    current_default="$(IFS=,; echo "${WIZARD_REVIEWERS[*]}")"
  fi

  _ask_text "GitHub usernames (comma-separated, or leave blank to skip)" "$current_default"

  WIZARD_REVIEWERS=()
  if [[ -n "$WIZARD_TEXT" ]]; then
    IFS=',' read -ra raw_reviewers <<< "$WIZARD_TEXT"
    local r
    for r in "${raw_reviewers[@]}"; do
      r="${r#"${r%%[! ]*}"}"  # ltrim
      r="${r%"${r##*[! ]}"}"  # rtrim
      [[ -n "$r" ]] && WIZARD_REVIEWERS+=("$r")
    done
  fi
}

_wizard_sub_commands() {
  _wizard_subheader "Custom commands" "Project slash commands (e.g. /octopus:db-reset)."

  WIZARD_COMMANDS=()

  # Gate: ask once whether to add any. Most users answer no.
  if ! _ask_yn "Add any custom commands?" "n"; then
    return 0
  fi

  while true; do
    echo ""
    _ask_text "  Command name (leave blank to finish)" ""
    local cmd_name="$WIZARD_TEXT"
    [[ -z "$cmd_name" ]] && break

    _ask_text "  Description" ""
    local cmd_desc="$WIZARD_TEXT"

    _ask_text "  Shell command to run (e.g. make db-reset)" ""
    local cmd_run="$WIZARD_TEXT"

    WIZARD_COMMANDS+=("${cmd_name}|${cmd_desc}|${cmd_run}")
    local _check; (( WIZARD_UNICODE )) && _check="✓" || _check="+"
    echo "  $(_green "$_check Added: /octopus:${cmd_name}")"
  done
}

_wizard_sub_knowledge() {
  _wizard_subheader "Knowledge modules" "Domain context Octopus injects into agents."

  local opts=("none" "auto-discover" "explicit-list")
  local default="none"
  [[ "$WIZARD_KNOWLEDGE" == "true" ]] && default="auto-discover"
  [[ "$WIZARD_KNOWLEDGE" != "" && "$WIZARD_KNOWLEDGE" != "false" && "$WIZARD_KNOWLEDGE" != "true" ]] && default="explicit-list"

  _select_one \
    "Knowledge configuration" \
    "none=skip · auto-discover=use all folders in knowledge/ · explicit-list=specify modules" \
    opts \
    "$default"

  case "$WIZARD_TEXT" in
    none)
      WIZARD_KNOWLEDGE="false"
      ;;
    auto-discover)
      WIZARD_KNOWLEDGE="true"
      ;;
    explicit-list)
      echo ""
      _ask_text "Module names (comma-separated, e.g. domain,architecture)" ""
      WIZARD_KNOWLEDGE="$WIZARD_TEXT"
      ;;
  esac
}

_wizard_sub_advanced_flags() {
  _wizard_subheader "Advanced flags" \
    "Boris-tip opt-ins: worktree, memory, dream, sandbox, githubAction."
  _wizard_hints \
    "worktree|Tolerate git worktrees for parallel sub-agent work (required by /batch)" \
    "memory|Auto-capture persistent memory across sessions" \
    "dream|Ship the 'dream' subagent that consolidates stale memory (requires memory)" \
    "sandbox|Run tool calls inside Claude Code's sandbox (defense-in-depth)" \
    "githubAction|Scaffold .github/workflows/claude.yml for automated PR review"

  local items=(worktree memory dream sandbox githubAction)
  local defaults=("${WIZARD_ADVANCED_FLAGS[@]}")

  _multiselect \
    "Enable advanced settings" \
    "TAB=toggle · ENTER=confirm" \
    items defaults

  WIZARD_ADVANCED_FLAGS=("${WIZARD_SELECTED[@]}")
}

_wizard_sub_permission_mode() {
  _wizard_subheader "Permission mode" \
    "auto = classifier auto-approves · plan = require plan mode · acceptEdits = auto-approve edits only."

  local perm_opts=("default (ask every time)" "auto" "plan" "acceptEdits")
  local perm_default="default (ask every time)"
  [[ -n "$WIZARD_PERMISSION_MODE" ]] && perm_default="$WIZARD_PERMISSION_MODE"
  _select_one \
    "Permission mode" \
    "Applies to Claude only" \
    perm_opts \
    "$perm_default"
  if [[ "$WIZARD_TEXT" == "default"* ]]; then
    WIZARD_PERMISSION_MODE=""
  else
    WIZARD_PERMISSION_MODE="$WIZARD_TEXT"
  fi
}

_wizard_sub_output_style() {
  _wizard_subheader "Output style" \
    "Standardize the tone of Claude's replies across the team."

  local style_opts=("default (each dev decides)" "concise" "verbose" "structured" "explanatory")
  local style_default="default (each dev decides)"
  [[ -n "$WIZARD_OUTPUT_STYLE" ]] && style_default="$WIZARD_OUTPUT_STYLE"
  _select_one \
    "Output style" \
    "Applies to Claude only" \
    style_opts \
    "$style_default"
  if [[ "$WIZARD_TEXT" == "default"* ]]; then
    WIZARD_OUTPUT_STYLE=""
  else
    WIZARD_OUTPUT_STYLE="$WIZARD_TEXT"
  fi
}

# ---------------------------------------------------------------------------
# Groups — 5 top-level steps composed from sub-questions above.
# Each group prints the banner (first call) + one step intro, then invokes
# its sub-questions. Sub-questions print their own subheader only.
# ---------------------------------------------------------------------------

_wizard_total_groups() {
  # Group 5 (advanced) is Claude-only; count it only when claude is selected.
  local a
  for a in "${WIZARD_AGENTS[@]}"; do
    [[ "$a" == "claude" ]] && { echo 5; return; }
  done
  echo 4
}

_wizard_group_basics() {
  _wizard_banner
  _wizard_intro "1/${WIZARD_TOTAL_GROUPS:-5}" "Basics" \
    "The minimum decisions every repo needs: which AI assistants to configure" \
    "and which language they should use for generated content."
  _wizard_sub_agents
  _wizard_sub_language
}

_wizard_group_capabilities() {
  _wizard_banner
  _wizard_intro "2/${WIZARD_TOTAL_GROUPS:-5}" "What the AI knows and does" \
    "Rules ('common' always added), reusable skills, specialized role personas," \
    "and curated knowledge modules injected into agent prompts." \
    "Every sub-section is optional."
  _wizard_sub_rules
  _wizard_sub_roles
  _wizard_sub_skills
  _wizard_sub_knowledge
}

_wizard_group_integrations() {
  _wizard_banner
  _wizard_intro "3/${WIZARD_TOTAL_GROUPS:-5}" "Integrations" \
    "External tool integrations via Model Context Protocol. Each server may" \
    "require secrets — fill them into .env.octopus after setup."
  _wizard_sub_mcp
}

_wizard_group_workflow() {
  _wizard_banner
  _wizard_intro "4/${WIZARD_TOTAL_GROUPS:-5}" "Team workflow" \
    "Quality gates (hooks) and developer-flow slash commands (/octopus:pr-*)." \
    "Reviewers asked only when workflow is enabled; custom commands only on opt-in."
  _wizard_sub_hooks
  _wizard_sub_workflow
  if [[ "$WIZARD_WORKFLOW" == "true" ]]; then
    _wizard_sub_reviewers
  fi
  _wizard_sub_commands
}

_wizard_group_advanced() {
  _wizard_banner
  _wizard_intro "5/${WIZARD_TOTAL_GROUPS:-5}" "Advanced Claude Code settings (optional)" \
    "Opt-ins for Claude Code behaviors standardized by Boris Cherny's tips." \
    "These only affect the Claude agent; other assistants ignore them." \
    "Safe to skip — every option defaults to Claude Code's native behavior."
  _wizard_sub_advanced_flags
  _wizard_sub_permission_mode
  _wizard_sub_output_style
}

# ---------------------------------------------------------------------------
# Pre-flight: Install scope (RM-018)
# ---------------------------------------------------------------------------

# _wizard_scope_prompt
# Sets $OCTOPUS_SCOPE via a single-select when the caller did not already
# provide one via CLI flag or env var. Skipped entirely when the scope is
# already pinned.
_wizard_scope_prompt() {
  # Scope already resolved (flag/env/manifest)? Skip.
  if [[ -n "${OCTOPUS_SCOPE_PINNED:-}" ]]; then return 0; fi

  _wizard_banner
  printf "  %s\n\n" "$(_bold "Install scope")"
  if [[ "${WIZARD_RECONFIGURE:-0}" != "1" ]]; then
    printf "  %s\n"   "$(_dim "This repository — config lives next to the code (default for project-specific rules).")"
    printf "  %s\n\n" "$(_dim "User account — config lives in ~/.config/octopus/ and merges with every CC session on this machine.")"
  fi

  local opts=("This repository" "User account")
  local default="This repository"
  [[ "${OCTOPUS_SCOPE:-repo}" == "user" ]] && default="User account"

  _select_one \
    "Where to install" \
    "Repo-scope layers on top of user-scope at agent-read time — you can do both." \
    opts \
    "$default"

  if [[ "$WIZARD_TEXT" == "User"* ]]; then
    export OCTOPUS_SCOPE="user"
  else
    export OCTOPUS_SCOPE="repo"
  fi
}

# ---------------------------------------------------------------------------
# Pre-flight: Quick vs Full setup
# ---------------------------------------------------------------------------

# _wizard_mode_prompt
# Returns via $WIZARD_MODE: "quick" or "full"
# Quick runs only basics (agents) + workflow (hooks + workflow flag), leaving
# every other field at empty/default. Users can rerun with --reconfigure to
# walk the full flow later.
_wizard_mode_prompt() {
  _wizard_banner
  printf "  %s\n\n" "$(_bold "Choose setup mode")"
  if [[ "${WIZARD_RECONFIGURE:-0}" != "1" ]]; then
    printf "  %s\n"   "$(_dim "Quick = 3 questions; everything else gets sensible empty defaults.")"
    printf "  %s\n\n" "$(_dim "Full  = 5 grouped steps; walk through every option.")"
  fi

  local opts=("Quick (3 questions)" "Full (5 steps)")
  local default="Quick (3 questions)"
  [[ "${WIZARD_RECONFIGURE:-0}" == "1" ]] && default="Full (5 steps)"

  _select_one \
    "Setup mode" \
    "Re-run 'octopus setup --reconfigure' any time to adjust." \
    opts \
    "$default"

  if [[ "$WIZARD_TEXT" == "Quick"* ]]; then
    WIZARD_MODE="quick"
  else
    WIZARD_MODE="full"
  fi
}

# ---------------------------------------------------------------------------
# YAML generation
# ---------------------------------------------------------------------------

_generate_octopus_yml() {
  local out=""

  out+="# Generated by octopus setup wizard"$'\n'
  out+="# Edit this file and re-run 'octopus setup' to apply changes"$'\n'

  # scope — emit only when explicitly 'user'; absence means 'repo' default.
  if [[ "${OCTOPUS_SCOPE:-repo}" == "user" ]]; then
    out+=$'\n'
    out+="scope: user"$'\n'
  fi

  # agents
  out+=$'\n'
  out+="agents:"$'\n'
  local agent
  for agent in "${WIZARD_AGENTS[@]}"; do
    out+="  - ${agent}"$'\n'
  done

  # rules
  if [[ ${#WIZARD_RULES[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="rules:"$'\n'
    local rule
    for rule in "${WIZARD_RULES[@]}"; do
      out+="  - ${rule}"$'\n'
    done
  fi

  # bundles (Quick mode emits these; Full mode may too)
  if [[ ${#WIZARD_BUNDLES[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="bundles:"$'\n'
    local bundle
    for bundle in "${WIZARD_BUNDLES[@]}"; do
      out+="  - ${bundle}"$'\n'
    done
  fi

  # skills (explicit extras on top of bundles; skip when bundles cover everything)
  if [[ ${#WIZARD_BUNDLES[@]} -eq 0 && ${#WIZARD_SKILLS[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="skills:"$'\n'
    local skill
    for skill in "${WIZARD_SKILLS[@]}"; do
      out+="  - ${skill}"$'\n'
    done
  fi

  # roles (explicit extras on top of bundles; skip when bundles cover everything)
  if [[ ${#WIZARD_BUNDLES[@]} -eq 0 && ${#WIZARD_ROLES[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="roles:"$'\n'
    local role
    for role in "${WIZARD_ROLES[@]}"; do
      out+="  - ${role}"$'\n'
    done
  fi

  # mcp
  if [[ ${#WIZARD_MCP[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="mcp:"$'\n'
    local mcp
    for mcp in "${WIZARD_MCP[@]}"; do
      out+="  - ${mcp}"$'\n'
    done
  else
    out+=$'\n'
    out+="mcp: []"$'\n'
  fi

  # language
  if [[ -n "$WIZARD_LANGUAGE" ]]; then
    out+=$'\n'
    if (( WIZARD_LANGUAGE_EXPANDED )); then
      out+="language:"$'\n'
      out+="  docs: ${WIZARD_LANGUAGE_DOCS}"$'\n'
      out+="  code: ${WIZARD_LANGUAGE_CODE}"$'\n'
      out+="  ui: ${WIZARD_LANGUAGE_UI}"$'\n'
    else
      out+="language: ${WIZARD_LANGUAGE}"$'\n'
    fi
  fi

  # hooks
  if [[ -n "$WIZARD_HOOKS" ]]; then
    out+=$'\n'
    out+="hooks: ${WIZARD_HOOKS}"$'\n'
  fi

  # workflow
  if [[ -n "$WIZARD_WORKFLOW" ]]; then
    out+=$'\n'
    out+="workflow: ${WIZARD_WORKFLOW}"$'\n'
  fi

  # reviewers
  if [[ ${#WIZARD_REVIEWERS[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="reviewers:"$'\n'
    local reviewer
    for reviewer in "${WIZARD_REVIEWERS[@]}"; do
      out+="  - ${reviewer}"$'\n'
    done
  fi

  # commands
  if [[ ${#WIZARD_COMMANDS[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="commands:"$'\n'
    local cmd
    for cmd in "${WIZARD_COMMANDS[@]}"; do
      local cmd_name="${cmd%%|*}"
      local rest="${cmd#*|}"
      local cmd_desc="${rest%%|*}"
      local cmd_run="${rest#*|}"
      out+="  - name: ${cmd_name}"$'\n'
      [[ -n "$cmd_desc" ]] && out+="    description: ${cmd_desc}"$'\n'
      [[ -n "$cmd_run"  ]] && out+="    run: ${cmd_run}"$'\n'
    done
  fi

  # knowledge
  if [[ -n "$WIZARD_KNOWLEDGE" && "$WIZARD_KNOWLEDGE" != "false" ]]; then
    out+=$'\n'
    if [[ "$WIZARD_KNOWLEDGE" == "true" ]]; then
      out+="knowledge: true"$'\n'
    else
      out+="knowledge:"$'\n'
      IFS=',' read -ra km_list <<< "$WIZARD_KNOWLEDGE"
      local km
      for km in "${km_list[@]}"; do
        km="${km#"${km%%[! ]*}"}"
        km="${km%"${km##*[! ]}"}"
        [[ -n "$km" ]] && out+="  - ${km}"$'\n'
      done
    fi
  fi

  # Advanced settings — Boris-tip passthroughs (RM-011 through RM-016)
  local advanced_flag
  local has_advanced=0
  for advanced_flag in "${WIZARD_ADVANCED_FLAGS[@]}"; do
    [[ -n "$advanced_flag" ]] && { has_advanced=1; break; }
  done
  if (( has_advanced )) || [[ -n "$WIZARD_PERMISSION_MODE" ]] || [[ -n "$WIZARD_OUTPUT_STYLE" ]]; then
    out+=$'\n'
    out+="# Advanced Claude Code settings (RM-011 through RM-016)"$'\n'
    for advanced_flag in "${WIZARD_ADVANCED_FLAGS[@]}"; do
      [[ -n "$advanced_flag" ]] && out+="${advanced_flag}: true"$'\n'
    done
    [[ -n "$WIZARD_PERMISSION_MODE" ]] && out+="permissionMode: ${WIZARD_PERMISSION_MODE}"$'\n'
    [[ -n "$WIZARD_OUTPUT_STYLE"    ]] && out+="outputStyle: ${WIZARD_OUTPUT_STYLE}"$'\n'
  fi

  printf '%s' "$out"
}

# ---------------------------------------------------------------------------
# Preview and confirm
# ---------------------------------------------------------------------------

_wizard_preview_and_confirm() {
  _wizard_banner
  echo "$(_bold "  Preview: .octopus.yml")"
  echo ""
  _hr

  local yaml
  yaml="$(_generate_octopus_yml)"
  echo "$yaml" | sed 's/^/  /'

  _hr
  echo ""
  _ask_yn "Write this .octopus.yml?" "y"
}

# ---------------------------------------------------------------------------
# Pre-fill from existing .octopus.yml (basic parsing)
# ---------------------------------------------------------------------------

_prefill_from_existing() {
  local yml="$1"
  [[ ! -f "$yml" ]] && return 0

  local section=""
  while IFS= read -r line; do
    # Skip comments and empty lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line// }" ]] && continue

    # Detect section headers (support camelCase keys like permissionMode, githubAction)
    if [[ "$line" =~ ^([a-zA-Z_]+): ]]; then
      section="${BASH_REMATCH[1]}"
      local val="${line#*: }"
      val="${val%"${val##*[! ]}"}"
      case "$section" in
        scope)          [[ -n "$val" ]] && { export OCTOPUS_SCOPE="$val"; OCTOPUS_SCOPE_PINNED=1; } ;;
        hooks)          [[ -n "$val" ]] && WIZARD_HOOKS="$val" ;;
        workflow)       [[ -n "$val" ]] && WIZARD_WORKFLOW="$val" ;;
        language)       [[ -n "$val" ]] && WIZARD_LANGUAGE="$val" ;;
        knowledge)      [[ "$val" == "true" || "$val" == "false" ]] && WIZARD_KNOWLEDGE="$val" ;;
        worktree)       [[ "$val" == "true" ]] && WIZARD_ADVANCED_FLAGS+=("worktree") ;;
        memory)         [[ "$val" == "true" ]] && WIZARD_ADVANCED_FLAGS+=("memory") ;;
        dream)          [[ "$val" == "true" ]] && WIZARD_ADVANCED_FLAGS+=("dream") ;;
        sandbox)        [[ "$val" == "true" ]] && WIZARD_ADVANCED_FLAGS+=("sandbox") ;;
        githubAction)   [[ "$val" == "true" ]] && WIZARD_ADVANCED_FLAGS+=("githubAction") ;;
        permissionMode) [[ -n "$val" ]] && WIZARD_PERMISSION_MODE="$val" ;;
        outputStyle)    [[ -n "$val" ]] && WIZARD_OUTPUT_STYLE="$val" ;;
      esac
    fi

    # List items
    if [[ "$line" =~ ^[[:space:]]+-[[:space:]]+(.*) ]]; then
      local item="${BASH_REMATCH[1]}"
      item="${item%"${item##*[! ]}"}"
      case "$section" in
        agents)    WIZARD_AGENTS+=("$item") ;;
        rules)     WIZARD_RULES+=("$item") ;;
        skills)    WIZARD_SKILLS+=("$item") ;;
        roles)     WIZARD_ROLES+=("$item") ;;
        mcp)       WIZARD_MCP+=("$item") ;;
        reviewers) WIZARD_REVIEWERS+=("$item") ;;
      esac
    fi

    # Language sub-keys
    if [[ "$section" == "language" ]]; then
      if [[ "$line" =~ ^[[:space:]]+docs:[[:space:]]+(.*) ]]; then
        WIZARD_LANGUAGE_DOCS="${BASH_REMATCH[1]}"
        WIZARD_LANGUAGE_EXPANDED=1
      elif [[ "$line" =~ ^[[:space:]]+code:[[:space:]]+(.*) ]]; then
        WIZARD_LANGUAGE_CODE="${BASH_REMATCH[1]}"
        WIZARD_LANGUAGE_EXPANDED=1
      elif [[ "$line" =~ ^[[:space:]]+ui:[[:space:]]+(.*) ]]; then
        WIZARD_LANGUAGE_UI="${BASH_REMATCH[1]}"
        WIZARD_LANGUAGE_EXPANDED=1
      fi
    fi
  done < "$yml"
}

# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

# run_setup_wizard <project_root> <release_dir> [--reconfigure]
run_setup_wizard() {
  local project_root="$1"
  local release_dir="$2"
  local reconfigure="${3:-}"

  # Non-interactive guard
  if [[ ! -t 0 || ! -t 1 ]]; then
    return 0  # caller will fall back to template copy
  fi

  _detect_platform    # sets WIZARD_IS_WINDOWS
  _detect_tui_backend # uses WIZARD_IS_WINDOWS to skip whiptail/dialog on Windows
  _apply_wizard_theme # tames the default loud palettes (override with OCTOPUS_WIZARD_THEME=default)

  # Pre-fill from existing config when reconfiguring
  if [[ "$reconfigure" == "--reconfigure" && -f "$project_root/.octopus.yml" ]]; then
    WIZARD_RECONFIGURE=1
    echo ""
    echo "  $(_dim "Pre-filling from existing .octopus.yml...")"
    _prefill_from_existing "$project_root/.octopus.yml"
    sleep 0.5
  else
    WIZARD_RECONFIGURE=0
    # Sensible defaults for fresh setup
    WIZARD_AGENTS=(claude)
    WIZARD_HOOKS="true"
    WIZARD_WORKFLOW="false"
    command -v gh &>/dev/null && WIZARD_WORKFLOW="true"
  fi

  # Pre-flight: scope (RM-018) — only asks if the caller didn't pin via
  # --scope / env / manifest.
  _wizard_scope_prompt

  # If the user picked a different scope in the prompt, the manifest target
  # changes too. Re-resolve project_root so _generate_octopus_yml writes to
  # the right location.
  if [[ "$OCTOPUS_SCOPE" == "user" ]]; then
    project_root="${XDG_CONFIG_HOME:-$HOME/.config}/octopus"
    mkdir -p "$project_root"
  fi

  # Pre-flight: Quick vs Full. Quick runs only Basics + Workflow hooks flag,
  # Full walks the 5 grouped steps.
  _wizard_mode_prompt

  if [[ "$WIZARD_MODE" == "quick" ]]; then
    # Quick: agents + bundles (via persona questions) + hooks + workflow.
    _wizard_banner
    _wizard_intro "1/3" "Agents" \
      "Which AI assistants should this repo configure?"
    _wizard_sub_agents
    _wizard_intro "2/3" "Bundles" \
      "Group skills + roles by intent — a few yes/no questions."
    _wizard_sub_bundles
    _wizard_intro "3/3" "Workflow" \
      "Quality gates and PR automation."
    _wizard_sub_hooks
    _wizard_sub_workflow
    if [[ "$WIZARD_WORKFLOW" == "true" ]]; then
      _wizard_sub_reviewers
    fi
  else
    # Full: compute total group count (5 or 4 depending on whether claude is
    # selected; agents is picked in group 1 so we peek at the default here
    # and recompute after the fact if the user changed it).
    WIZARD_TOTAL_GROUPS="$(_wizard_total_groups)"
    _wizard_group_basics
    # Recompute after user may have added/removed claude
    WIZARD_TOTAL_GROUPS="$(_wizard_total_groups)"
    _wizard_group_capabilities
    _wizard_group_integrations
    _wizard_group_workflow
    # Skip the advanced step entirely when claude is not configured
    local has_claude=0
    local a
    for a in "${WIZARD_AGENTS[@]}"; do
      [[ "$a" == "claude" ]] && { has_claude=1; break; }
    done
    if (( has_claude )); then
      _wizard_group_advanced
    fi
  fi

  # Preview and confirm
  if ! _wizard_preview_and_confirm; then
    echo ""
    echo "  $(_dim "Cancelled. No changes were made.")"
    exit 0
  fi

  # Write the file
  _generate_octopus_yml > "$project_root/.octopus.yml"

  echo ""
  local _check; (( WIZARD_UNICODE )) && _check="✓" || _check="ok"
  echo "  $(_green "$_check Written: $project_root/.octopus.yml")"
  echo "  $(_dim "Running octopus setup to apply configuration...")"
  echo ""
}
