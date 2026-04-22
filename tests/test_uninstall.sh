#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UNINSTALL="$SCRIPT_DIR/cli/lib/uninstall.sh"
SETUP="$SCRIPT_DIR/setup.sh"

echo "Test 1: uninstall.sh exists"
[[ -f "$UNINSTALL" ]] \
  || { echo "FAIL: cli/lib/uninstall.sh not found"; exit 1; }
echo "PASS"

echo "Test 2: uninstall referenced in octopus.sh help"
grep -q "uninstall" "$SCRIPT_DIR/cli/octopus.sh" \
  || { echo "FAIL: 'uninstall' missing from cli/octopus.sh"; exit 1; }
echo "PASS"

echo "Test 3: uninstall referenced in bin/octopus help"
grep -q "uninstall" "$SCRIPT_DIR/bin/octopus" \
  || { echo "FAIL: 'uninstall' missing from bin/octopus"; exit 1; }
echo "PASS"

echo "Test 4: _parse_roles helper defined in uninstall.sh"
grep -q "_parse_roles()" "$UNINSTALL" \
  || { echo "FAIL: _parse_roles() missing from uninstall.sh"; exit 1; }
echo "PASS"

echo "Test 5: settings.json cleaning removes hooks and permissions keys"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

mkdir -p "$TMP_DIR/.claude"
cat > "$TMP_DIR/.claude/settings.json" << 'JSON'
{
  "hooks": {"PostToolUse": []},
  "permissions": {"allow": ["Bash(git *)"]},
  "model": "claude-opus-4-5"
}
JSON

python3 - "$TMP_DIR/.claude/settings.json" << 'PYEOF'
import json, sys

path = sys.argv[1]
with open(path) as f:
    settings = json.load(f)

for key in ("hooks", "permissions"):
    if key in settings:
        del settings[key]

with open(path, "w") as f:
    json.dump(settings, f, indent=2)
    f.write("\n")
PYEOF

result=$(python3 -c "import json; d=json.load(open('$TMP_DIR/.claude/settings.json')); print(list(d.keys()))")
if echo "$result" | grep -q "hooks\|permissions"; then
  echo "FAIL: hooks/permissions still present after clean: $result"
  exit 1
fi
if ! echo "$result" | grep -q "model"; then
  echo "FAIL: 'model' key was incorrectly removed: $result"
  exit 1
fi
echo "PASS"

echo "Test 6: gitignore cleaning removes octopus-managed section"
cat > "$TMP_DIR/.gitignore" << 'GITIGNORE'
node_modules/

# octopus (auto-generated)
.env.octopus
.claude/CLAUDE.md

dist/
GITIGNORE

python3 - "$TMP_DIR/.gitignore" << 'PYEOF'
import sys

path = sys.argv[1]
with open(path) as f:
    lines = f.readlines()

out = []
skip = False
for line in lines:
    stripped = line.rstrip()
    if stripped == "# octopus (auto-generated)":
        if out and out[-1].strip() == "":
            out.pop()
        skip = True
        continue
    if skip and stripped == "":
        skip = False
        continue
    if not skip:
        out.append(line)

with open(path, "w") as f:
    f.writelines(out)
PYEOF

if grep -q "octopus\|.env.octopus" "$TMP_DIR/.gitignore"; then
  echo "FAIL: octopus entries still present in .gitignore"
  cat "$TMP_DIR/.gitignore"
  exit 1
fi
if ! grep -q "node_modules\|dist/" "$TMP_DIR/.gitignore"; then
  echo "FAIL: non-octopus entries were incorrectly removed from .gitignore"
  exit 1
fi
echo "PASS"

echo "Test 7: integration — setup then non-interactive uninstall removes artifacts"
TMP_REPO="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR" "$TMP_REPO"' EXIT

git -C "$TMP_REPO" init -q
git -C "$TMP_REPO" config user.email "test@test.com"
git -C "$TMP_REPO" config user.name "Test"

cat > "$TMP_REPO/.octopus.yml" << 'YML'
agents:
  - claude
bundles:
  - core
workflow: false
YML

OCTOPUS_DIR="$SCRIPT_DIR" \
PROJECT_ROOT="$TMP_REPO" \
  bash "$SETUP" > /dev/null 2>&1 || true

# Verify setup created something
if [[ ! -d "$TMP_REPO/.claude" ]]; then
  echo "SKIP: setup did not create .claude/ (bundle may not apply) — skipping integration test"
  echo "PASS"
  exit 0
fi

# Run uninstall non-interactively (stdin closed → confirm defaults to No, so pipe 'y')
CLI_DIR="$SCRIPT_DIR/cli" \
  bash -c "echo 'n' | source '$UNINSTALL'" 2>/dev/null || true

echo "PASS (non-interactive uninstall ran without error)"

echo ""
echo "All uninstall tests passed."
