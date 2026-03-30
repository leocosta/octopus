#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

base_settings() {
  mkdir -p "$TMPDIR/.claude"
  echo '{"permissions": {}, "hooks": {}}' > "$TMPDIR/.claude/settings.json"
  MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
  MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
}

reset_vars() {
  OCTOPUS_EFFORT_LEVEL=""
}

# --- test_effort_level_high ---
reset_vars
base_settings

OCTOPUS_EFFORT_LEVEL="high"
deliver_effort_level "claude"

python3 -c "
import json
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
assert data.get('effortLevel') == 'high', f'Expected high, got {data.get(\"effortLevel\")}'
print('PASS: test_effort_level_high')
" || { echo "FAIL: test_effort_level_high"; exit 1; }

# --- test_effort_level_max ---
reset_vars
base_settings

OCTOPUS_EFFORT_LEVEL="max"
deliver_effort_level "claude"

python3 -c "
import json
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
assert data.get('effortLevel') == 'max', f'Expected max, got {data.get(\"effortLevel\")}'
print('PASS: test_effort_level_max')
" || { echo "FAIL: test_effort_level_max"; exit 1; }

# --- test_effort_level_absent ---
reset_vars
base_settings

# Don't set OCTOPUS_EFFORT_LEVEL
deliver_effort_level "claude"

python3 -c "
import json
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
assert 'effortLevel' not in data, f'effortLevel should be absent, got {data.get(\"effortLevel\")}'
print('PASS: test_effort_level_absent')
" || { echo "FAIL: test_effort_level_absent"; exit 1; }

# --- test_effort_level_overwrite ---
reset_vars
mkdir -p "$TMPDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "effortLevel": "low"}' > "$TMPDIR/.claude/settings.json"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"

OCTOPUS_EFFORT_LEVEL="high"
deliver_effort_level "claude"

python3 -c "
import json
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
assert data.get('effortLevel') == 'high', f'Expected high (overwrite), got {data.get(\"effortLevel\")}'
print('PASS: test_effort_level_overwrite')
" || { echo "FAIL: test_effort_level_overwrite"; exit 1; }

# --- test_effort_level_invalid ---
reset_vars
base_settings

OCTOPUS_EFFORT_LEVEL="extreme"
if deliver_effort_level "claude" 2>/dev/null; then
  echo "FAIL: test_effort_level_invalid — should have failed for value 'extreme'"
  exit 1
else
  echo "PASS: test_effort_level_invalid"
fi

# --- test_effort_level_skips_non_claude ---
reset_vars
base_settings

OCTOPUS_EFFORT_LEVEL="high"
deliver_effort_level "opencode"

python3 -c "
import json
with open('$TMPDIR/.claude/settings.json') as f:
    data = json.load(f)
assert 'effortLevel' not in data, f'effortLevel should not be set for opencode, got {data.get(\"effortLevel\")}'
print('PASS: test_effort_level_skips_non_claude')
" || { echo "FAIL: test_effort_level_skips_non_claude"; exit 1; }

# --- test_effortLevel_parsed_from_yaml ---
reset_vars
cat > "$TMPDIR/.octopus.yml" << 'EOF'
effortLevel: max
rules:
  - common
agents:
  - claude
EOF

OCTOPUS_EFFORT_LEVEL=""
parse_octopus_yml "$TMPDIR/.octopus.yml"

[[ "$OCTOPUS_EFFORT_LEVEL" == "max" ]] || { echo "FAIL: test_effortLevel_parsed_from_yaml — got '$OCTOPUS_EFFORT_LEVEL'"; exit 1; }
echo "PASS: test_effortLevel_parsed_from_yaml"

rm -rf "$TMPDIR"
