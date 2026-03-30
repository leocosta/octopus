# Spec: Effort Level in the Manifest

## Metadata

| Field | Value |
|---|---|
| **Date** | 2026-03-30 |
| **Author** | <!-- Your name --> |
| **Status** | Implemented |
| **Roadmap** | RM-004 |
| **RFC** | N/A |

## Problem Statement

Claude Code supports an `effortLevel` setting (`low | medium | high | max`) that controls the reasoning depth for every response. Currently, Octopus has no way to persist this value across sessions — developers either forget to set it or set it inconsistently. There is no project-level default.

Boris Cherny (tips 17 and 34) recommends using `high` for all standard work and `max` for hard debugging and architecture decisions. Without manifest support, each developer must remember to set this manually per session.

## Goals

1. New `effortLevel: low | medium | high | max` field in `.octopus.yml`
2. `setup.sh` reads the field and injects `"effortLevel": "<value>"` into `settings.json` during setup
3. Only the Claude agent receives this field — it is the only agent with a `settings_json` delivery method that uses this key
4. Invalid values are rejected with a clear error message

## Non-Goals

- Do not implement per-task effort overrides (only project-level default)
- Do not support the field for non-Claude agents
- Do not map effort levels to other agents' equivalent settings

## Design

### Overview

Add parsing of the `effortLevel:` field in `parse_octopus_yml()` and a new `deliver_effort_level()` function that injects the value into `settings.json`, following the same pattern as `deliver_permissions()`.

### Detailed Design

**Syntax in `.octopus.yml`:**

```yaml
effortLevel: high
```

Valid values: `low | medium | high | max`

**Variable in `setup.sh`** (to be added alongside the other `declare` statements):

```bash
OCTOPUS_EFFORT_LEVEL=""
```

**Parsing in `parse_octopus_yml()`** — add to the inline string-value handler (`^([a-z][a-z_]*):[[:space:]]+([^#\[]+)[[:space:]]*$`):

```bash
effort_level) OCTOPUS_EFFORT_LEVEL="$val" ;;
```

Note: the YAML key is `effortLevel` (camelCase), but the parser uses `[a-z][a-z_]*` which does not match capital letters. The key must be normalized. Two options:

- **Option A (preferred):** Accept `effortlevel` (lowercase) from the YAML and document it as `effortLevel` in examples, adding a pre-processing lowercase step only for this key.
- **Option B:** Extend the parser regex to support camelCase keys (`[a-zA-Z][a-zA-Z_]*`) and add a case for `effortLevel`.

Option B is simpler and consistent with the intention to support camelCase keys (`knowledge_dir` is already an exception). Extend the parser's inline-string regex to also match camelCase keys.

**Function `deliver_effort_level()`** — add after `deliver_permissions()`:

```bash
deliver_effort_level() {
  local agent="$1"
  if [[ -z "$OCTOPUS_EFFORT_LEVEL" ]]; then return; fi
  if [[ "$agent" != "claude" ]]; then return; fi

  local settings_file="$PROJECT_ROOT/$MANIFEST_DELIVERY_HOOKS_TARGET"
  if [[ ! -f "$settings_file" ]]; then
    echo "WARNING: settings.json not found at $MANIFEST_DELIVERY_HOOKS_TARGET. Skipping effortLevel for $agent."
    return
  fi

  echo "Injecting effortLevel into $MANIFEST_DELIVERY_HOOKS_TARGET for $agent..."

  python3 - "$settings_file" "$OCTOPUS_EFFORT_LEVEL" << 'PYEOF'
import json, sys

settings_path, effort_level = sys.argv[1], sys.argv[2]

valid = {"low", "medium", "high", "max"}
if effort_level not in valid:
    print(f"ERROR: Invalid effortLevel '{effort_level}'. Valid values: {sorted(valid)}", file=sys.stderr)
    sys.exit(1)

with open(settings_path) as f:
    settings = json.load(f)

settings["effortLevel"] = effort_level

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF
  echo "  → effortLevel=${OCTOPUS_EFFORT_LEVEL} injected into $MANIFEST_DELIVERY_HOOKS_TARGET"
}
```

**Call in the main flow** — add after `deliver_permissions "$agent"`:

```bash
deliver_effort_level "$agent"
```

### Agent Support

| Agent | Supported | Notes |
|---|---|---|
| **claude** | Yes | `effortLevel` is a top-level key in `.claude/settings.json`. |
| **opencode** | No | No equivalent `effortLevel` key in its settings schema. |
| **antigravity** | No | No `settings_json` delivery method. |
| **codex** | No | No `settings_json` delivery method. |
| **copilot** | No | No `settings_json` delivery method. |

`deliver_effort_level()` exits early for any agent that is not `claude`.

### Migration / Backward Compatibility

- The `effortLevel` field is optional. If absent, no value is written to `settings.json` and Claude Code uses its own default.
- Existing `.octopus.yml` files without the field are unaffected.
- If `settings.json` already contains an `effortLevel` key (e.g. manually set), `deliver_effort_level()` overwrites it with the manifest value — manifest is the source of truth.

## Implementation Plan

1. **`setup.sh`** — add variable `OCTOPUS_EFFORT_LEVEL=""` in the `declare` block (line ~35, after `OCTOPUS_PERMISSIONS_MODE`)
2. **`setup.sh` → `parse_octopus_yml()`** — extend the inline string-value `case` block to match `effortLevel` (camelCase): add a line `effortLevel) OCTOPUS_EFFORT_LEVEL="$val" ;;` and update the regex or normalization to accept camelCase keys
3. **`setup.sh`** — add function `deliver_effort_level()` after `deliver_permissions()` (line ~816)
4. **`setup.sh`** — call `deliver_effort_level "$agent"` in the main setup loop, after `deliver_permissions "$agent"`
5. **`tests/`** — add tests for: valid value injection, invalid value rejection, absent field leaves `settings.json` unchanged

## Context for Agents

**Knowledge modules**: N/A
**Implementing roles**: N/A
**Related ADRs**: N/A
**Skills needed**: N/A

**Constraints**:
- Pure bash + Python3 stdlib — no external dependencies
- Follow the exact pattern of `deliver_permissions()`: inline Python via heredoc, write back to `settings.json` with `indent=2` and trailing newline
- Validate the value in Python — do not validate only in bash
- Only applies to the `claude` agent — exit early for all others
- The field is a top-level key in `settings.json`, not nested under `permissions`

## Testing Strategy

- `test_effort_level_high`: manifest with `effortLevel: high` → `settings.json["effortLevel"] == "high"`
- `test_effort_level_max`: manifest with `effortLevel: max` → `settings.json["effortLevel"] == "max"`
- `test_effort_level_invalid`: manifest with `effortLevel: extreme` → setup exits with error
- `test_effort_level_absent`: manifest without `effortLevel` → `settings.json` does not contain `effortLevel`
- `test_effort_level_overwrite`: `settings.json` already has `effortLevel: low`, manifest sets `high` → value is overwritten to `high`

## Risks

- `effortLevel` as a top-level settings key may change in a future Claude Code release. Monitor the Claude Code changelog and update the injection key accordingly.
- The parser regex for inline values (`^([a-z][a-z_]*)`) does not currently match camelCase keys. Extending it requires care to avoid breaking existing key detection logic. Prefer a targeted fix (add `effortLevel` to a dedicated camelCase branch) over a broad regex change.

## Changelog

- **2026-03-30** — Initial draft
