# Spec: Permissions Manifest

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-03-30 |
| **Author** | <!-- Your name --> |
| **Status** | Implemented |
| **Roadmap** | RM-001 |
| **RFC** | N/A |

## Problem Statement

Octopus does not expose Claude Code's pre-approved permissions configuration in the `.octopus.yml` manifest. Teams must manually edit the generated `settings.json` to add `permissions.allow` and `permissions.deny`, which:
- Is not reproducible (`setup.sh` overwrites `settings.json` on every run)
- Has no intelligent per-language defaults
- Forces each developer to discover the syntax on their own

## Goals

1. New `permissions:` field in `.octopus.yml` with `allow:` and `deny:` subfields
2. `setup.sh` reads the field and injects it into `settings.json["permissions"]` during setup
3. Intelligent per-language defaults: when `permissions: true` (short form), inject a default list based on the project's `rules:`
4. The `roadmap-item: RM-001` field in this spec's frontmatter is honored by `/octopus:doc-spec`

## Non-Goals

- Do not implement a UI/wizard for permissions discovery
- Do not validate whether allow-list commands exist on the machine
- Do not support environment variables in the permissions syntax

## Design

### Overview

Add parsing of the `permissions:` field in `parse_octopus_yml()` and a new `deliver_permissions()` function that uses Python (following the same pattern as `deliver_hooks()`) to merge permissions into `settings.json`.

### Detailed Design

**Syntax in `.octopus.yml`:**

```yaml
# Explicit form
permissions:
  allow:
    - "Bash(git *)"
    - "Bash(gh *)"
    - "Bash(bun run *)"
    - "Bash(npx *)"
  deny:
    - "Bash(rm -rf *)"

# Short form — uses per-language defaults
permissions: true
```

**Per-language defaults** (when `permissions: true`):

| Language (detected via `rules:`) | Allow defaults |
|------------------------------------|---------------|
| node / typescript | `Bash(bun run *)`, `Bash(npm run *)`, `Bash(npx *)` |
| any | `Bash(git *)`, `Bash(gh *)` |

Language detection uses the `rules:` present in the manifest (e.g. `rules: [common, typescript]` → TypeScript).

**Variables in `setup.sh`** (to be added in `parse_octopus_yml()`):

```bash
declare -a OCTOPUS_PERMISSIONS_ALLOW=()
declare -a OCTOPUS_PERMISSIONS_DENY=()
OCTOPUS_PERMISSIONS_MODE=""   # "explicit" | "defaults" | ""
```

Parsing in the `permissions:` YAML block (follow the pattern of the `hooks:` block):
- `permissions: true` → `OCTOPUS_PERMISSIONS_MODE="defaults"`
- `permissions:` with subfields → `OCTOPUS_PERMISSIONS_MODE="explicit"`, populate arrays

**Function `deliver_permissions()`** (follow the pattern of `deliver_hooks()`):

```bash
deliver_permissions() {
  local agent="$1"
  if [[ "$OCTOPUS_PERMISSIONS_MODE" == "" ]]; then return; fi

  local settings_file="$PROJECT_ROOT/$MANIFEST_DELIVERY_HOOKS_TARGET"
  # (reuses the same settings.json target that hooks use)

  python3 - "$settings_file" ... << 'PYEOF'
  # Merge OCTOPUS_PERMISSIONS_ALLOW and DENY into settings["permissions"]
  PYEOF
}
```

The Python script must:
1. Read `settings.json`
2. Ensure `settings["permissions"]` exists as an object
3. Append (not overwrite) to `settings["permissions"]["allow"]` and `settings["permissions"]["deny"]`
4. Deduplicate entries
5. Save

**Call in the main flow** — add after `deliver_hooks()`:
```bash
deliver_permissions "$agent"
```

## Agent Support

| Agent | Supported | Notes |
|---|---|---|
| **claude** | Yes | Top-level `permissions.allow[]` and `permissions.deny[]` in `.claude/settings.json`. Native schema matches the Octopus allow/deny list model directly. |
| **opencode** | No | OpenCode uses a `permission` (singular) field with per-tool mode values (`"ask" \| "allow" \| "deny"` for `edit`, `bash`, `webfetch`, etc.). This schema is fundamentally different from Claude's command-pattern allow/deny lists and cannot be mapped without loss of meaning. |
| **gemini** | No | No `settings_json` delivery method; no native permissions concept. |
| **codex** | No | No `settings_json` delivery method; no native permissions concept. |
| **copilot** | No | No `settings_json` delivery method; no native permissions concept. |

`deliver_permissions()` only runs when `agent == "claude"`. If OpenCode adds a compatible allow/deny list API in the future, a separate `deliver_opencode_permissions()` function should be introduced rather than shoehorning it into the shared model.

## Migration / Backward Compatibility

- No breaking changes: the `permissions:` field is optional. If absent, current behavior is preserved
- The base `settings.json` at `agents/claude/settings.json` already has `"permissions": {}` — ready to receive the fields

## Implementation Plan

1. **`setup.sh`** — add variables `OCTOPUS_PERMISSIONS_ALLOW`, `OCTOPUS_PERMISSIONS_DENY`, `OCTOPUS_PERMISSIONS_MODE` alongside the other `declare` statements (line ~16)
2. **`setup.sh` → `parse_octopus_yml()`** — add parsing of the `permissions:` block following the pattern of the `hooks:` block (line ~64)
3. **`setup.sh`** — add function `deliver_permissions()` after `deliver_hooks()` (line ~701)
4. **`setup.sh`** — call `deliver_permissions "$agent"` in the main flow after `deliver_hooks`
5. **`tests/`** — add tests for `permissions: true` and the explicit form (follow the pattern of existing tests)

## Context for Agents

**Knowledge modules**: N/A
**Implementing roles**: N/A
**Related ADRs**: N/A
**Skills needed**: [security-scan]

**Constraints**:
- Pure bash + Python3 stdlib — no external dependencies
- Follow the exact pattern of `deliver_hooks()`: inline Python via heredoc, non-destructive merge
- Deduplicate entries when merging (a project may have an empty allow-list in the base `settings.json`)
- `permissions: true` must apply sensible defaults, not an empty list

## Testing Strategy

- `test_permissions_explicit`: manifest with `permissions: allow/deny` → `settings.json` contains the correct entries
- `test_permissions_defaults_node`: manifest with `permissions: true` and `rules: [common, typescript]` → Node defaults injected
- `test_permissions_absent`: manifest without `permissions:` → `settings.json["permissions"]` remains `{}`
- `test_permissions_dedup`: manifest with allow entries already present in the base settings → no duplicates

## Risks

- Language detection via `rules:` is heuristic — it may not work for multilingual repos. Mitigation: document the limitation, prefer the explicit form in those cases.
- The `settings.json` target is reused from hook delivery (`MANIFEST_DELIVERY_HOOKS_TARGET`) — assuming the field is the same. If an agent uses a different delivery method, it may not work. Verify that all relevant agents use `settings_json` as their hooks delivery method.

## Changelog

- **2026-03-30** — Initial draft
