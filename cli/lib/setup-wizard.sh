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
# Renders the step header plus 1+ dim description lines so each step explains
# what it configures and why it matters before the picker opens.
_wizard_intro() {
  local step="$1"
  local title="$2"
  shift 2
  printf "  %s — %s\n\n" "$(_bold "Step $step")" "$(_cyan "$title")"
  local line
  for line in "$@"; do
    printf "  %s\n" "$(_dim "$line")"
  done
  printf "\n"
}

# _wizard_hints <entry...>
# Entries are "name|description"; prints an aligned dim "name → description"
# table so the user sees per-item context before picking.
_wizard_hints() {
  local entry name desc
  for entry in "$@"; do
    name="${entry%%|*}"
    desc="${entry#*|}"
    printf "  %s  %s\n" "$(_dim "$(printf '%-20s' "$name $UI_SYM_ARROW")")" "$(_dim "$desc")"
  done
  printf "\n"
}

_wizard_step_agents() {
  local items=(claude copilot codex gemini opencode)
  local defaults=("${WIZARD_AGENTS[@]:-claude}")

  _wizard_banner
  _wizard_intro "1/11" "AI Code Assistants (agents)" \
    "Which AI assistants Octopus configures for this repo. Each agent gets its" \
    "own instructions file, rules, skills and slash commands delivered." \
    "Pick one or more — pick none and Octopus defaults to claude."
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

_wizard_step_rules() {
  local items=(typescript csharp python)
  local defaults=("${WIZARD_RULES[@]}")

  _wizard_banner
  _wizard_intro "2/11" "Language Rules" \
    "Coding guidelines appended to agent instructions. Enforces style," \
    "testing, security and patterns per language. The 'common' set (core" \
    "principles, commit conventions, PR workflow) is always included." \
    "Skip this if your project mixes many languages or you prefer no rules."
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

_wizard_step_skills() {
  local items=(adr backend-patterns context-budget continuous-learning dotnet e2e-testing feature-lifecycle security-scan)
  local defaults=("${WIZARD_SKILLS[@]}")

  _wizard_banner
  _wizard_intro "3/11" "Skills" \
    "Reusable AI capabilities exposed as slash commands (/simplify, /loop, …)." \
    "Gives agents tooling for common operations without custom code." \
    "Pick only the ones relevant to your project to keep agents focused."
  _wizard_hints \
    "adr|record Architecture Decision Records" \
    "backend-patterns|apply repo/service/DI patterns" \
    "context-budget|monitor and trim the conversation context" \
    "continuous-learning|capture lessons learned per session" \
    "dotnet|.NET-specific build/test/format helpers" \
    "e2e-testing|scaffold end-to-end test suites" \
    "feature-lifecycle|spec → PR → release helpers" \
    "security-scan|scan diffs for secrets and vulnerabilities"

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
  _wizard_intro "4/11" "Roles / Personas" \
    "Specialized subagents invoked for focused tasks. Each role carries its" \
    "own instructions and domain context, keeping the main conversation clean." \
    "On Claude they map to native subagents; elsewhere they become role sections."
  _wizard_hints \
    "backend-specialist|APIs, data modeling, server-side logic" \
    "frontend-specialist|UI/UX, components, accessibility" \
    "product-manager|specs, roadmap, prioritization" \
    "tech-writer|docs, READMEs, release notes" \
    "social-media|platform-native posts and campaigns"

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
  _wizard_intro "5/11" "MCP Servers" \
    "Model Context Protocol servers: structured tool integrations agents can" \
    "call (query GitHub, read Notion, run SQL, post to Slack). Each server" \
    "may need env vars — fill them in .env.octopus after setup."
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

_wizard_step_language() {
  _wizard_banner
  _wizard_intro "6/11" "Language" \
    "Language for AI-generated content (specs, commits, PRs, UI strings)." \
    "Prevents agents from defaulting to the conversation language. Code" \
    "identifiers always stay in English." \
    "Pick a base language; optionally override per scope (docs/code/ui separately)."

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
  _wizard_intro "7/11" "Hooks" \
    "Lifecycle hooks Claude Code runs automatically around tool use, session" \
    "start, and context compaction." \
    "Quality gates they enforce: block --no-verify, detect secrets in diffs," \
    "auto-format on save, warn on console.log leftovers, trim stale transcripts." \
    "Skip to keep Claude Code unconstrained; nothing is enforced automatically."

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
  _wizard_intro "8/11" "Workflow Commands" \
    "Guided dev-flow slash commands: /octopus:branch-create, :pr-open," \
    ":pr-review, :pr-comments, :pr-merge, :release, :update." \
    "Enforces Octopus conventions — branch naming, Conventional Commits," \
    "PR template, squash merge, auto-assigned reviewers." \
    "Requires 'gh' (GitHub CLI) >= 2.0 installed and authenticated."

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
  _wizard_intro "9/11" "GitHub Reviewers" \
    "Default reviewers assigned automatically when /octopus:pr-review runs." \
    "Saves typing the same team members on every PR." \
    "Leave blank to skip — /octopus:pr-review will prompt each time."

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
  _wizard_intro "10/11" "Custom Commands" \
    "Your own project slash commands (/octopus:db-reset, :seed, :deploy-staging, ...)." \
    "Each command is a shell invocation wrapped so any configured agent can run it." \
    "Skip to finish without adding any — you can always re-run 'octopus setup --reconfigure'."

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
  _wizard_intro "11/11" "Knowledge Modules" \
    "Curated domain context (business rules, system overview, glossary) that" \
    "Octopus injects into agent prompts so they understand your project." \
    "Lives under 'knowledge/'; each subdirectory is a module." \
    "none = skip · auto-discover = use every folder · explicit-list = pick modules by name."

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
  _apply_wizard_theme # tames the default loud palettes (override with OCTOPUS_WIZARD_THEME=default)

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
