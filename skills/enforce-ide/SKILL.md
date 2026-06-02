---
name: enforce-ide
description: >
  Write a baseline `.editorconfig` and (opt-in) `.vscode/settings.json` +
  `.vscode/extensions.json` aligned with the project's chosen formatter
  and linter. Reinforces the project's conventions in the editor
  surface — the layer between the human's keystroke and the git commit.
  Detects stack via file extensions and existing configs. Respects
  existing files: merges keys conservatively, never overwrites a
  user-set value. Pairs with enforce-precommit and the guardrails
  bundle for defense-in-depth across loop / git / CI / IDE.
triggers:
  paths: [".editorconfig", ".vscode/settings.json", ".vscode/extensions.json", ".octopus.yml"]
  keywords: ["enforce ide", "editorconfig", "vscode settings", "guardrails ide", "editor consistency"]
---

# IDE Configuration Enforcement

## Overview

Three of the four enforcement layers (loop-level hooks, pre-commit,
CI) catch drift *after* a keystroke. The IDE layer catches it
*during* — format-on-save, lint-inline, EOL/indent conventions that
are wrong from the moment a character lands in the buffer.

This skill writes the IDE-level baseline so a developer's local
editor matches what pre-commit and CI will enforce. It is intentionally
conservative — IDE preferences are politically charged, and the goal
is project consistency, not personal-preference override.

## When to Engage

Engage when:

- The user adds `guardrails` to `.octopus.yml` for the first time.
- A new stack is added and `.editorconfig` does not yet cover it.
- The team standardizes on VS Code or its forks (Cursor, Windsurf,
  Code-OSS) and wants `.vscode/` opinions versioned.

Do not engage when:

- The user explicitly opts out via `enforce-ide.local.md` (e.g., team
  policy: "editor configs are personal, do not version").
- The project is library-only with no contributors beyond the original
  author.

## Protocol

### Step 1 — Detect stacks

Reuse the stack-detection logic from `enforce-precommit` (file
extension count + canonical manifests). If `enforce-precommit` ran
recently, its detected set is the truth.

### Step 1.5 — Resolve the workspace template

Before generating, resolve the `.editorconfig` source with this
precedence (highest wins):

1. **Project-local** — an existing `.editorconfig` in the repo, or
   `enforce-ide.local.md` directives. Intentional repo choices; preserved
   and merged on top (Step 2's conservative merge).
2. **Workspace template** — if the manifest sets `workspace:` and
   `<workspace>/templates/ide/<stack>.editorconfig` exists, use it as the
   **canonical base**, taking precedence over the generated default below.
   This lets a fleet manager curate one editor standard (see
   `fleet-bootstrap`).
3. **Generated default** — Step 2's stack-inferred baseline; the fallback
   when the workspace provides no template.

When a workspace template is used, Step 2 merges the repo's existing
sections on top of it rather than the built-in baseline.

### Step 2 — `.editorconfig` (always)

Write or merge `.editorconfig` with universal baseline plus per-stack
overrides:

```ini
root = true

[*]
indent_style = space
indent_size = 2
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{py}]
indent_size = 4

[*.{go}]
indent_style = tab

[Makefile]
indent_style = tab
```

Merge semantics: preserve every existing section and key; only add
sections that do not yet exist. Never change an existing value.

### Step 3 — `.vscode/extensions.json` (opt-in)

Default: skip unless `enforce_ide_vscode: true` in `.octopus.yml` or
the repo already has a `.vscode/` directory.

When written, recommend extensions per active stack:

| Stack | Recommended extensions |
|---|---|
| TypeScript / JavaScript | `biomejs.biome` OR `esbenp.prettier-vscode` + `dbaeumer.vscode-eslint` (match project choice) |
| Python | `charliermarsh.ruff` |
| C# / .NET | `ms-dotnettools.csharp` |
| Go | `golang.go` |
| Rust | `rust-lang.rust-analyzer` |
| Universal | `editorconfig.editorconfig` |

Merge semantics: append to `recommendations` array; never remove an
existing entry.

### Step 4 — `.vscode/settings.json` (opt-in, narrow)

Default: skip. When `enforce_ide_vscode: true`, write **only**
project-scoped formatter selection and format-on-save:

```json
{
  "editor.formatOnSave": true,
  "editor.codeActionsOnSave": {
    "source.fixAll": "explicit"
  },
  "[typescript]": { "editor.defaultFormatter": "biomejs.biome" },
  "[python]":     { "editor.defaultFormatter": "charliermarsh.ruff" }
}
```

Per-stack `defaultFormatter` only when the project unambiguously
declares the formatter (e.g., `biome.json` present → biome; otherwise
do not write the key).

Never write personal-preference keys (font, theme, window, terminal,
keybindings, telemetry).

### Step 5 — Verify

- Confirm `.editorconfig` parses (no syntax errors).
- Confirm `.vscode/*.json` is valid JSON with comments stripped (use
  JSONC parser).
- Log what was written and what was preserved.

## Output

```
[ok]   Detected stacks: TypeScript, Python
[ok]   Wrote .editorconfig (2 new sections, 4 preserved)
[skip] .vscode/ — enforce_ide_vscode not enabled, no existing .vscode/ found
[info] To enable .vscode/ defaults, set `enforce_ide_vscode: true` in .octopus.yml
```

## Anti-Patterns

- Writing personal-preference keys (font, theme, window layout) to
  `.vscode/settings.json` — that is personal config, not project
  config.
- Overwriting `.editorconfig` values the user set deliberately.
- Recommending extensions for stacks not present in the repo.
- Generating `.idea/`, `.fleet/`, or other IDE-specific directories —
  out of scope for this skill (separate skills would be required and
  the same political concerns apply).
- Auto-installing extensions (that is the developer's decision).

## Integration with Other Skills

- **`guardrails` bundle** — loads this skill alongside
  `enforce-precommit`.
- **`enforce-precommit`** — shares stack-detection. The formatter
  selected here matches what pre-commit will enforce.
- **`audit-config`** — periodically reviews whether `.editorconfig`
  drifted from `rules/common/coding-style.md`.

## References

- EditorConfig: https://editorconfig.org/
- VS Code settings reference: https://code.visualstudio.com/docs/getstarted/settings
