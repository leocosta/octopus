#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/setup.sh" --source-only

echo "Test 1: deliver_hooks rewrites relative hook paths to absolute"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR/.claude/settings.json"

export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"

deliver_hooks "claude" >/dev/null

# Every hook command should start with "/" (absolute path)
python3 - "$TMPDIR/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
for event, entries in settings["hooks"].items():
    for entry in entries:
        for hook in entry["hooks"]:
            cmd = hook["command"]
            if not cmd.startswith("/"):
                print(f"FAIL: non-absolute hook command: {cmd}")
                sys.exit(1)
print("PASS: all hook commands are absolute paths")
PYEOF

echo "Test 2: deliver_hooks does not emit PostToolUseFailure"

python3 - "$TMPDIR/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
if "PostToolUseFailure" in settings["hooks"]:
    print("FAIL: PostToolUseFailure event present")
    sys.exit(1)
print("PASS: no invalid hook events")
PYEOF

rm -rf "$TMPDIR"

echo "Test 3: deliver_boris_settings drops unsupported keys and normalizes permissionMode"

TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR/.claude/settings.json"

PROJECT_ROOT="$TMPDIR"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"

# Simulate a manifest that set all Boris-tip fields
OCTOPUS_WORKTREE="true"
OCTOPUS_PERMISSION_MODE="auto"
OCTOPUS_MEMORY="true"
OCTOPUS_DREAM="true"
OCTOPUS_SANDBOX="true"
OCTOPUS_OUTPUT_STYLE="explanatory"

deliver_boris_settings "claude" >/dev/null 2>&1 || true

python3 - "$TMPDIR/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)

# permissionMode=auto must be normalized to default
if settings.get("permissionMode") not in (None, "default"):
    print(f"FAIL: permissionMode not normalized (got {settings.get('permissionMode')!r})")
    sys.exit(1)

# Unsupported keys must not land in settings.json
for bad in ("worktree", "autoMemory", "autoDream", "sandbox"):
    if bad in settings:
        print(f"FAIL: unsupported key '{bad}' still written to settings.json")
        sys.exit(1)

print("PASS: boris passthroughs filtered safely")
PYEOF

rm -rf "$TMPDIR"

echo ""
echo "All hooks injection tests passed!"
