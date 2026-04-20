# Auto-format Hook Improvements

**Date:** 2026-04-20
**Scope:** `hooks/post-tool-use/auto-format.sh`

## Context

Octopus already ships an auto-format PostToolUse hook that runs after `Write|Edit`
on TS/JS/JSON, C#, and Python files. It works, but has gaps:

- Only formats — does not lint-fix (unused imports, import order, simple code
  smells that biome/eslint can auto-resolve).
- Uses `dotnet format --include` which is slow on large solutions because it
  loads the full project/SLN graph even for a single-file change.
- Swallows all formatter errors (`2>/dev/null || true`), so when a formatter
  legitimately fails (e.g., syntax error) the user sees nothing.

## Goals

1. Lint-fix alongside formatting for TS/JS.
2. Faster .NET path via CSharpier when available.
3. Preserve `.editorconfig` behavior (no regressions).
4. Surface formatter failures to the user without blocking the hook.

## Non-goals

- Changing `hooks.json` (matchers, timeout, ordering stay as-is).
- Touching `pre-tool-use/format-check.sh` or `post-tool-use/typecheck.sh`.
- Adding new language support.

## Design

### TS/JS/JSON cascade

New order (first match wins):

1. `biome check --write <file>` — formats, organizes imports, applies safe lint fixes.
2. `eslint --fix <file>` followed by `prettier --write <file>` — when biome is absent.
3. `npx --yes prettier --write <file>` — last-resort fallback.

Notes:

- `biome check --write` is a superset of `biome format --write`, so this is
  strictly additive for biome users.
- `eslint --fix` runs only if `eslint` is on `PATH`; otherwise skipped silently
  and we go straight to `prettier`.

### C# (.cs, .csx)

New order:

1. `csharpier format <file>` — CSharpier on `PATH` (covers both standalone installs
   and `dotnet tool install -g csharpier`, since `~/.dotnet/tools` is normally on
   `PATH`).
2. `dotnet format --include <file>` — existing fallback.

### EditorConfig

Biome, prettier, and csharpier all respect `.editorconfig` by default. The script
will not pass flags that override it. A header comment documents this.

### Error reporting

Introduce `run_formatter <tool-name> <cmd...>`:

- Captures combined stdout+stderr into a temp file.
- On non-zero exit: emits one line to stderr:
  `[auto-format] <tool-name> failed on <file> (exit N): <first non-empty line of output>`
- On success: silent.
- Always returns 0 so the hook itself never fails the tool call.

Python path gets the same treatment for consistency.

## Consequences

- Users with biome see lint autofix automatically — could surprise someone who
  relied only on format. Mitigated: biome's `--write` applies only "safe" fixes
  by default.
- CSharpier must be installed separately to benefit; absence is a no-op (falls
  back to existing behavior).
- Failure messages become visible. This is the intended change.

## Rollout

Single PR, no flag. The hook is per-repo (symlinked from the Octopus submodule),
so consumers pick it up on their next `octopus:update`.
