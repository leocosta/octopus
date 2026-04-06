#!/usr/bin/env bash
# cli/lib/setup-wizard.sh — Interactive TUI wizard for .octopus.yml configuration
#
# Guides users through all manifest fields with multi-select UI.
# TUI backend priority: fzf > whiptail > dialog > pure bash

# ---------------------------------------------------------------------------
# Backend detection
# ---------------------------------------------------------------------------

WIZARD_BACKEND=""
WIZARD_IS_WINDOWS=0  # 1 when running under Git Bash / MSYS2 / Cygwin
WIZARD_COLORS=1      # 0 to suppress ANSI escape codes
WIZARD_UNICODE=1     # 0 to replace non-ASCII chars with ASCII equivalents

_detect_platform() {
  # Detect MSYS2 / Git Bash / Cygwin
  if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin \
     || -n "${MSYSTEM:-}" || -n "${CYGWIN:-}" ]]; then
    WIZARD_IS_WINDOWS=1
  fi

  # Disable colors when terminal requests it (NO_COLOR spec or dumb terminal)
  if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]]; then
    WIZARD_COLORS=0
  fi

  # Disable Unicode when locale is not UTF-8 (common on bare MSYS2 installs)
  if (( WIZARD_IS_WINDOWS )); then
    local locale_str="${LC_ALL:-}${LC_CTYPE:-}${LANG:-}"
    if [[ "$locale_str" != *[Uu][Tt][Ff]* ]]; then
      WIZARD_UNICODE=0
    fi
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
# Colors / formatting helpers
# ---------------------------------------------------------------------------

_bold()  { (( WIZARD_COLORS )) && printf '\033[1m%s\033[0m' "$*" || printf '%s' "$*"; }
_cyan()  { (( WIZARD_COLORS )) && printf '\033[36m%s\033[0m' "$*" || printf '%s' "$*"; }
_green() { (( WIZARD_COLORS )) && printf '\033[32m%s\033[0m' "$*" || printf '%s' "$*"; }
_dim()   { (( WIZARD_COLORS )) && printf '\033[2m%s\033[0m' "$*" || printf '%s' "$*"; }

_hr() {
  (( WIZARD_UNICODE )) && printf '%0.s─' $(seq 1 60) \
                       || printf '%0.s-' $(seq 1 60)
  printf '\n'
}

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
# Returns 0 for yes, 1 for no
_ask_yn() {
  local prompt="$1"
  local default="${2:-y}"

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
    "")    [[ "$default" == "y" ]] && return 0 || return 1 ;;
    *)     [[ "$default" == "y" ]] && return 0 || return 1 ;;
  esac
}

# _ask_text <prompt> <default>
# Sets WIZARD_TEXT on return
WIZARD_TEXT=""
_ask_text() {
  local prompt="$1"
  local default="${2:-}"

  local hint=""
  [[ -n "$default" ]] && hint=" $(_dim "(default: $default)")"

  printf "%s%s: " "$(_bold "$prompt")" "$hint"
  local reply
  read -r reply

  if [[ -z "$reply" ]]; then
    WIZARD_TEXT="$default"
  else
    WIZARD_TEXT="$reply"
  fi
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
WIZARD_MCP=()
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

# ---------------------------------------------------------------------------
# Wizard steps
# ---------------------------------------------------------------------------

_wizard_banner() {
  clear 2>/dev/null || true
  echo ""
  local title
  (( WIZARD_UNICODE )) && title="  🐙 Octopus Setup Wizard" \
                       || title="  ** Octopus Setup Wizard **"
  echo "$(_bold "$(_cyan "$title")")"
  echo "  $(_dim "Configure your .octopus.yml interactively")"
  echo ""
  _hr
  echo ""
}

_wizard_step_agents() {
  local items=(claude copilot codex gemini opencode)
  local defaults=("${WIZARD_AGENTS[@]:-claude}")

  _wizard_banner
  printf "  $(_bold "Step 1/11") — %s\n\n" "$(_cyan "AI Code Assistants (agents)")"
  printf "  %s\n\n" "$(_dim "Select which AI assistants this repo should be configured for.")"

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

_wizard_step_rules() {
  local items=(typescript csharp python)
  local defaults=("${WIZARD_RULES[@]}")

  _wizard_banner
  printf "  $(_bold "Step 2/11") — %s\n\n" "$(_cyan "Language Rules")"
  printf "  %s\n\n" "$(_dim "Select language-specific rule sets. 'common' is always included automatically.")"

  _multiselect \
    "Select rules" \
    "Available: typescript, csharp, python  (common is always added)" \
    items defaults

  WIZARD_RULES=("${WIZARD_SELECTED[@]}")
}

_wizard_step_skills() {
  local items=(adr backend-patterns context-budget continuous-learning dotnet e2e-testing feature-lifecycle security-scan)
  local defaults=("${WIZARD_SKILLS[@]}")

  _wizard_banner
  printf "  $(_bold "Step 3/11") — %s\n\n" "$(_cyan "Skills")"
  printf "  %s\n\n" "$(_dim "Reusable AI capabilities to inject. Select what's relevant to your project.")"

  _multiselect \
    "Select skills" \
    "adr · backend-patterns · context-budget · continuous-learning · dotnet · e2e-testing · feature-lifecycle · security-scan" \
    items defaults

  WIZARD_SKILLS=("${WIZARD_SELECTED[@]}")
}

_wizard_step_roles() {
  local items=(backend-specialist frontend-specialist product-manager tech-writer social-media)
  local defaults=("${WIZARD_ROLES[@]}")

  _wizard_banner
  printf "  $(_bold "Step 4/11") — %s\n\n" "$(_cyan "Roles / Personas")"
  printf "  %s\n\n" "$(_dim "Select AI sub-agent personas. Each role has specialized instructions and context.")"

  _multiselect \
    "Select roles" \
    "backend-specialist · frontend-specialist · product-manager · tech-writer · social-media" \
    items defaults

  WIZARD_ROLES=("${WIZARD_SELECTED[@]}")
}

_wizard_step_mcp() {
  local items=(github notion slack postgres)
  local defaults=("${WIZARD_MCP[@]}")

  _wizard_banner
  printf "  $(_bold "Step 5/11") — %s\n\n" "$(_cyan "MCP Servers")"
  printf "  %s\n\n" "$(_dim "Model Context Protocol servers to configure. Each may require env vars.")"

  echo "  $(_dim "  github  → GITHUB_TOKEN")"
  echo "  $(_dim "  notion  → OAuth (no env vars)")"
  echo "  $(_dim "  slack   → SLACK_BOT_TOKEN, SLACK_TEAM_ID")"
  echo "  $(_dim "  postgres→ DATABASE_URL")"
  echo ""

  _multiselect \
    "Select MCP servers" \
    "github · notion · slack · postgres" \
    items defaults

  WIZARD_MCP=("${WIZARD_SELECTED[@]}")
}

_wizard_step_language() {
  _wizard_banner
  printf "  $(_bold "Step 6/11") — %s\n\n" "$(_cyan "Language")"
  printf "  %s\n\n" "$(_dim "Configure the language for AI-generated content. Leave blank to let Octopus auto-detect.")"

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
    _ask_text "Docs language (specs, ADRs, commits, PRs)" "$base"
    WIZARD_LANGUAGE_DOCS="$WIZARD_TEXT"

    _ask_text "Code language (code comments; identifiers always en)" "en"
    WIZARD_LANGUAGE_CODE="$WIZARD_TEXT"

    _ask_text "UI language (user-facing messages, app copy)" "$base"
    WIZARD_LANGUAGE_UI="$WIZARD_TEXT"
  fi
}

_wizard_step_hooks() {
  _wizard_banner
  printf "  $(_bold "Step 7/11") — %s\n\n" "$(_cyan "Hooks")"
  printf "  %s\n\n" "$(_dim "Lifecycle hooks for Claude Code (pre-tool-use, post-tool-use, session-start, etc.).")"
  printf "  %s\n\n" "$(_dim "Hooks enforce quality checks: block --no-verify, detect secrets, auto-format, etc.")"

  local current_default="y"
  [[ "$WIZARD_HOOKS" == "false" ]] && current_default="n"

  if _ask_yn "Enable hooks?" "$current_default"; then
    WIZARD_HOOKS="true"
  else
    WIZARD_HOOKS="false"
  fi
}

_wizard_step_workflow() {
  _wizard_banner
  printf "  $(_bold "Step 8/11") — %s\n\n" "$(_cyan "Workflow Commands")"
  printf "  %s\n\n" "$(_dim "Enables /octopus:branch-create, /octopus:pr-open, /octopus:pr-review, etc.")"
  printf "  %s\n\n" "$(_dim "Requires: gh (GitHub CLI) >= 2.0 installed and authenticated.")"

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

_wizard_step_reviewers() {
  _wizard_banner
  printf "  $(_bold "Step 9/11") — %s\n\n" "$(_cyan "GitHub Reviewers")"
  printf "  %s\n\n" "$(_dim "Default reviewers automatically assigned to PRs via /octopus:pr-review.")"

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

_wizard_step_commands() {
  _wizard_banner
  printf "  $(_bold "Step 10/11") — %s\n\n" "$(_cyan "Custom Commands")"
  printf "  %s\n\n" "$(_dim "Define project-specific slash commands (e.g. /octopus:db-reset).")"

  WIZARD_COMMANDS=()

  while true; do
    echo ""
    if ! _ask_yn "Add a custom command?" "n"; then
      break
    fi

    echo ""
    _ask_text "  Command name (e.g. db-reset)" ""
    local cmd_name="$WIZARD_TEXT"
    [[ -z "$cmd_name" ]] && echo "  Skipped (empty name)." && continue

    _ask_text "  Description" ""
    local cmd_desc="$WIZARD_TEXT"

    _ask_text "  Shell command to run (e.g. make db-reset)" ""
    local cmd_run="$WIZARD_TEXT"

    WIZARD_COMMANDS+=("${cmd_name}|${cmd_desc}|${cmd_run}")
    local _check; (( WIZARD_UNICODE )) && _check="✓" || _check="+"
    echo "  $(_green "$_check Added: /octopus:${cmd_name}")"
  done
}

_wizard_step_knowledge() {
  _wizard_banner
  printf "  $(_bold "Step 11/11") — %s\n\n" "$(_cyan "Knowledge Modules")"
  printf "  %s\n\n" "$(_dim "Domain context injected into AI agents (stored under knowledge/ directory).")"

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

# ---------------------------------------------------------------------------
# YAML generation
# ---------------------------------------------------------------------------

_generate_octopus_yml() {
  local out=""

  out+="# Generated by octopus setup wizard"$'\n'
  out+="# Edit this file and re-run 'octopus setup' to apply changes"$'\n'

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

  # skills
  if [[ ${#WIZARD_SKILLS[@]} -gt 0 ]]; then
    out+=$'\n'
    out+="skills:"$'\n'
    local skill
    for skill in "${WIZARD_SKILLS[@]}"; do
      out+="  - ${skill}"$'\n'
    done
  fi

  # roles
  if [[ ${#WIZARD_ROLES[@]} -gt 0 ]]; then
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

    # Detect section headers
    if [[ "$line" =~ ^([a-z_]+): ]]; then
      section="${BASH_REMATCH[1]}"
      local val="${line#*: }"
      val="${val%"${val##*[! ]}"}"
      case "$section" in
        hooks)    [[ -n "$val" ]] && WIZARD_HOOKS="$val" ;;
        workflow) [[ -n "$val" ]] && WIZARD_WORKFLOW="$val" ;;
        language) [[ -n "$val" ]] && WIZARD_LANGUAGE="$val" ;;
        knowledge)[[ "$val" == "true" || "$val" == "false" ]] && WIZARD_KNOWLEDGE="$val" ;;
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

  _detect_platform    # sets WIZARD_IS_WINDOWS, WIZARD_COLORS, WIZARD_UNICODE
  _detect_tui_backend # uses WIZARD_IS_WINDOWS to skip whiptail/dialog on Windows

  # Pre-fill from existing config when reconfiguring
  if [[ "$reconfigure" == "--reconfigure" && -f "$project_root/.octopus.yml" ]]; then
    echo ""
    echo "  $(_dim "Pre-filling from existing .octopus.yml...")"
    _prefill_from_existing "$project_root/.octopus.yml"
    sleep 0.5
  else
    # Sensible defaults for fresh setup
    WIZARD_AGENTS=(claude)
    WIZARD_HOOKS="true"
    WIZARD_WORKFLOW="false"
    command -v gh &>/dev/null && WIZARD_WORKFLOW="true"
  fi

  # Run all steps
  _wizard_step_agents
  _wizard_step_rules
  _wizard_step_skills
  _wizard_step_roles
  _wizard_step_mcp
  _wizard_step_language
  _wizard_step_hooks
  _wizard_step_workflow
  _wizard_step_reviewers
  _wizard_step_commands
  _wizard_step_knowledge

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
