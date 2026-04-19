#!/usr/bin/env bash
# cli/lib/ui.sh — Unified visual vocabulary for Octopus scripts.
#
# Provides consistent symbols, colors, and structured output primitives used by
# setup.sh, the setup wizard, and the workflow CLI. install.sh cannot source
# this file (it runs before the repo is on disk) but mirrors the same symbol
# set so the user sees a single visual dialect end-to-end.
#
# Respects NO_COLOR and TERM=dumb (https://no-color.org). Degrades Unicode to
# ASCII when the locale is not UTF-8 (common on Git Bash / MSYS2).
#
# Verbose mode: set OCTOPUS_VERBOSE=1 to show ui_detail lines. Default is off.

# Guard against double-source
[[ -n "${_OCTOPUS_UI_LOADED:-}" ]] && return 0
_OCTOPUS_UI_LOADED=1

UI_COLORS=1
UI_UNICODE=1
OCTOPUS_VERBOSE="${OCTOPUS_VERBOSE:-0}"

# NO_COLOR / dumb terminal / non-tty → no colors
if [[ -n "${NO_COLOR:-}" || "${TERM:-}" == "dumb" ]] || ! [[ -t 1 ]]; then
  UI_COLORS=0
fi

# Windows/Git Bash locale check: ASCII fallback when locale is not UTF-8
if [[ "${OSTYPE:-}" == msys* || "${OSTYPE:-}" == cygwin || -n "${MSYSTEM:-}" ]]; then
  _ui_locale="${LC_ALL:-}${LC_CTYPE:-}${LANG:-}"
  if [[ "$_ui_locale" != *[Uu][Tt][Ff]* ]]; then
    UI_UNICODE=0
  fi
  unset _ui_locale
fi

# ── Symbols ────────────────────────────────────────────────────────────────
if (( UI_UNICODE )); then
  UI_SYM_INFO="ℹ"
  UI_SYM_SUCCESS="✓"
  UI_SYM_WARN="⚠"
  UI_SYM_ERROR="✗"
  UI_SYM_STEP="▸"
  UI_SYM_ARROW="→"
  UI_SYM_BULLET="•"
  UI_SYM_HR="─"
else
  UI_SYM_INFO="i"
  UI_SYM_SUCCESS="+"
  UI_SYM_WARN="!"
  UI_SYM_ERROR="x"
  UI_SYM_STEP=">"
  UI_SYM_ARROW="->"
  UI_SYM_BULLET="*"
  UI_SYM_HR="-"
fi

# ── Color primitives (internal) ────────────────────────────────────────────
_ui_c() {
  local code="$1"; shift
  if (( UI_COLORS )); then
    printf '\033[%sm%s\033[0m' "$code" "$*"
  else
    printf '%s' "$*"
  fi
}
_ui_bold()   { _ui_c '1'  "$*"; }
_ui_dim()    { _ui_c '2'  "$*"; }
_ui_red()    { _ui_c '31' "$*"; }
_ui_green()  { _ui_c '32' "$*"; }
_ui_yellow() { _ui_c '33' "$*"; }
_ui_blue()   { _ui_c '34' "$*"; }
_ui_cyan()   { _ui_c '36' "$*"; }

# ── Public API ─────────────────────────────────────────────────────────────

# ui_info <msg>     — informational line (blue ℹ)
ui_info()    { printf '%s  %s\n' "$(_ui_blue   "$UI_SYM_INFO")"    "$*"; }

# ui_success <msg>  — success line (green ✓)
ui_success() { printf '%s  %s\n' "$(_ui_green  "$UI_SYM_SUCCESS")" "$*"; }

# ui_warn <msg>     — warning (yellow ⚠)
ui_warn()    { printf '%s  %s\n' "$(_ui_yellow "$UI_SYM_WARN")"    "$*"; }

# ui_error <msg>    — error (red ✗, goes to stderr)
ui_error()   { printf '%s  %s\n' "$(_ui_red    "$UI_SYM_ERROR")"   "$*" >&2; }

# ui_step <label>   — opens a phase with "▸ label"
ui_step()    { printf '%s  %s\n' "$(_ui_cyan   "$UI_SYM_STEP")"    "$(_ui_bold "$*")"; }

# ui_done [<detail>] — closes a phase successfully; indented ✓ line
ui_done() {
  local detail="${1:-done}"
  printf '   %s  %s\n' "$(_ui_green "$UI_SYM_SUCCESS")" "$(_ui_dim "$detail")"
}

# ui_skip [<detail>] — closes a phase as skipped (dim ✗-like)
ui_skip() {
  local detail="${1:-skipped}"
  printf '   %s  %s\n' "$(_ui_dim "$UI_SYM_BULLET")" "$(_ui_dim "$detail")"
}

# ui_banner <title> — section header, surrounded by blank lines
ui_banner() {
  printf '\n%s\n\n' "$(_ui_bold "$(_ui_cyan "=== $* ===")")"
}

# ui_kv <key> <value> — aligned key/value pair (columnar summary)
ui_kv() {
  printf '  %s %s\n' "$(_ui_dim "$(printf '%-12s' "$1")")" "$2"
}

# ui_detail <msg>   — sub-info, only emitted when OCTOPUS_VERBOSE=1
ui_detail() {
  (( OCTOPUS_VERBOSE )) || return 0
  printf '   %s  %s\n' "$(_ui_dim "$UI_SYM_ARROW")" "$(_ui_dim "$*")"
}

# ui_divider [width] — horizontal rule
ui_divider() {
  local width="${1:-60}"
  local i hr=""
  for (( i = 0; i < width; i++ )); do hr+="$UI_SYM_HR"; done
  printf '%s\n' "$(_ui_dim "$hr")"
}
