# Spec: Setup UX Unification

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-04-18 |
| **Author** | Leonardo Costa |
| **Status** | Implemented |
| **Roadmap** | RM-008 |
| **RFC** | N/A |

## Problem Statement

The `octopus setup` flow traversed three scripts with three independent visual vocabularies:

- `install.sh` used its own `info`/`success`/`warn`/`error` helpers with ANSI color.
- `cli/lib/setup-wizard.sh` used alt-screen TUI widgets (fzf/whiptail/dialog) with local `_bold`/`_cyan`/`_dim`/`_hr` helpers.
- `setup.sh` raiz emitted bare `echo` lines with `WARNING:`/`ERROR:` prefixes and per-file `→` bullets.

Each boundary produced a dialect shift: installer logs, then wizard alt-screen, then a noisy setup log. The wizard itself mixed TUI multi-select with bare `read` prompts for yes/no and free-text, dropping out of the TUI mid-step. Each step offered one dim line of context, without explaining what the choice meant or what happened if skipped.

## Goals

1. One shared visual vocabulary across installer, wizard, and setup execution — same symbols, color policy, banners.
2. Grouped output during `setup.sh` execution: one `▸ Configuring <agent>` line per agent instead of per-file noise. Preserve full detail behind `OCTOPUS_VERBOSE=1`.
3. Wizard stays in TUI end-to-end: yes/no, single-select, multi-select, and free-text all dispatch to the active backend (fzf/whiptail/dialog) with a bash fallback.
4. Each wizard step explains what it configures, why it matters, and what happens if skipped. Multi-select steps show per-item descriptions before the picker opens.
5. Degrade gracefully without a TUI: bash fallback keeps the same numbered list / `[Y/n]` / `prompt (default)` shape.

## Non-Goals

- Do not force a subdued theme on whiptail/dialog. Their tightly-coupled color models produce unreadable combinations on mixed light/dark terminals; leave their defaults alone and nudge users toward fzf when they land on a fullscreen backend.
- Do not replace the TUI with pure inline prompts. Multi-select with TAB is materially better than "type numbers".
- Do not refactor the delivery functions inside `setup.sh` (per-file echoes stay; they are captured and filtered at the loop boundary).
- Do not deduplicate the shim body embedded in `install.sh` versus `bin/octopus` (tracked separately).

## Design

### `cli/lib/ui.sh` — shared primitives

One source of truth for symbols, colors, and layout:

| Helper | Purpose |
|---|---|
| `ui_info`, `ui_success`, `ui_warn`, `ui_error` | Diagnostic lines with colored symbol prefix (`ℹ ✓ ⚠ ✗`) |
| `ui_step <label>`, `ui_done [detail]`, `ui_skip [detail]` | Open / close a phase line (`▸ …` then indented `   ✓ …`) |
| `ui_banner <title>` | Section header `=== title ===` |
| `ui_kv <key> <value>` | Aligned columnar summary rows |
| `ui_detail <msg>` | Sub-info, silent unless `OCTOPUS_VERBOSE=1` |
| `ui_divider [width]` | Horizontal rule |

Respects `NO_COLOR`, `TERM=dumb`, and falls back to ASCII symbols when the locale is not UTF-8 (Windows/Git Bash).

### `setup.sh` integration

- Sources `cli/lib/ui.sh` at the top.
- Header and summary use `ui_banner` + `ui_kv` instead of bare `echo`.
- Per-agent delivery pipeline extracted into `_run_agent_pipeline`. In quiet mode (default), its stdout is captured to a temp log; `_replay_captured_diagnostics` surfaces only `WARNING:`/`ERROR:` lines as `ui_warn`/`ui_error`. In verbose mode, the full log is indented and replayed.
- All top-level `WARNING:`/`ERROR:` echoes replaced with `ui_warn`/`ui_error`.

### Wizard TUI dispatch

Three prompt primitives were rewritten to dispatch through `WIZARD_BACKEND`:

- `_ask_yn` — `fzf` Yes/No inline picker · `whiptail --yesno` · `dialog --yesno` · bash `[Y/n]` read.
- `_ask_text` — `fzf --print-query` inline input · `whiptail --inputbox` · `dialog --inputbox` · bash `prompt (default):` read.
- `_multiselect` and `_select_one` were already dispatched; no change.

`_wizard_banner` prints the full banner once per session and a dim `ui_divider` between subsequent steps — no `clear` call, scrollback stays continuous with `setup.sh`'s output.

### Step descriptions

Two helpers: `_wizard_intro <step> <title> <line...>` prints the step header plus N dim explanation lines ("what is it", "why it matters", "what happens if skipped"). `_wizard_hints "name|desc" …` renders an aligned `name → description` table before the picker opens so fzf multi-select stays clean while the user still sees per-item context.

Every step now carries 3–4 lines of intro; steps 1–5 (multi-select) also show per-item hints.

### Theme handling

Wizard invokes `_apply_wizard_theme` at entry. It exports a subdued `FZF_DEFAULT_OPTS` (`--color=fg:-1,bg:-1,hl:cyan,pointer:cyan,...`) so fzf blends with the terminal with a single cyan accent. whiptail/dialog defaults are left alone (overrides break readability across terminals).

When the detected backend is whiptail or dialog, the banner prints a one-line dim tip suggesting `sudo apt install fzf` / `brew install fzf` for the inline experience. `OCTOPUS_WIZARD_THEME=default` disables the fzf override.

### Backward compatibility

- Tests that grepped for literal `WARNING:`/`INFO:` prefixes were updated to match message content (run with `NO_COLOR=1` for deterministic output).
- `OCTOPUS_VERBOSE=1` preserves the pre-refactor verbose log.

## Testing Strategy

- `tests/test_full_setup.sh`: exercises the grouped per-agent output end-to-end.
- `tests/test_cli_deps.sh`, `tests/test_env_management.sh`: regression-check diagnostic surfacing via `NO_COLOR=1`.
- No new test files introduced — existing coverage is sufficient.

## Risks

- Warning/error replay relies on lines containing literal `WARNING:`/`ERROR:`. Any future diagnostic written via `ui_warn` before entering a per-agent capture block would not match the filter — all in-loop diagnostics must preserve the prefix format or use the ui helpers directly outside the pipeline.
- fzf `--print-query` with a single empty item is a workaround for the missing inputbox widget; future fzf versions may deprecate this pattern. If so, fall back to styled `read`.

## Changelog

- **2026-04-18** — Initial spec capturing the setup UX unification shipped alongside RM-005/006/007 closeout.
