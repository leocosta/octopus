#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

source "$SCRIPT_DIR/setup.sh" --source-only

echo "Test 1: deliver_hooks rewrites relative hook paths to absolute"

WORKDIR=$(mktemp -d)
mkdir -p "$WORKDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$WORKDIR/.claude/settings.json"

export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$WORKDIR"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"

deliver_hooks "claude" >/dev/null

# Every hook command should start with "/" (absolute path)
python3 - "$WORKDIR/.claude/settings.json" <<'PYEOF'
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

python3 - "$WORKDIR/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
if "PostToolUseFailure" in settings["hooks"]:
    print("FAIL: PostToolUseFailure event present")
    sys.exit(1)
print("PASS: no invalid hook events")
PYEOF

rm -rf "$WORKDIR"

echo "Test 3: deliver_boris_settings drops unsupported keys and normalizes permissionMode"

WORKDIR=$(mktemp -d)
mkdir -p "$WORKDIR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$WORKDIR/.claude/settings.json"

PROJECT_ROOT="$WORKDIR"
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

python3 - "$WORKDIR/.claude/settings.json" <<'PYEOF'
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

rm -rf "$WORKDIR"

echo "Test: destructive-guard is injected by default"
TMPDIR2=$(mktemp -d)
mkdir -p "$TMPDIR2/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR2/.claude/settings.json"
PROJECT_ROOT="$TMPDIR2"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
unset OCTOPUS_DISABLED_HOOKS || true

deliver_hooks "claude" >/dev/null

grep -q '"id": "destructive-guard"' "$TMPDIR2/.claude/settings.json" \
  || { echo "FAIL: destructive-guard missing from rendered settings"; exit 1; }
echo "PASS: destructive-guard injected by default"
rm -rf "$TMPDIR2"

echo "Test: destructive-guard is filtered out when disabled"
TMPDIR3=$(mktemp -d)
mkdir -p "$TMPDIR3/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR3/.claude/settings.json"
PROJECT_ROOT="$TMPDIR3"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
export OCTOPUS_DISABLED_HOOKS="destructive-guard"

deliver_hooks "claude" >/dev/null

if grep -q '"id": "destructive-guard"' "$TMPDIR3/.claude/settings.json"; then
  echo "FAIL: destructive-guard should have been filtered out"
  exit 1
fi
echo "PASS: destructive-guard filtered via OCTOPUS_DISABLED_HOOKS"
unset OCTOPUS_DISABLED_HOOKS
rm -rf "$TMPDIR3"

echo "Test: destructiveGuard manifest field parses to OCTOPUS_DESTRUCTIVE_GUARD"
TMPDIR4=$(mktemp -d)
cat > "$TMPDIR4/test.yml" <<'EOF'
hooks: true
destructiveGuard: false
EOF
OCTOPUS_DESTRUCTIVE_GUARD="true"
parse_octopus_yml "$TMPDIR4/test.yml"
[[ "$OCTOPUS_DESTRUCTIVE_GUARD" == "false" ]] \
  || { echo "FAIL: expected OCTOPUS_DESTRUCTIVE_GUARD=false, got '$OCTOPUS_DESTRUCTIVE_GUARD'"; exit 1; }
echo "PASS: destructiveGuard parsed"
rm -rf "$TMPDIR4"

echo "Test: deliver_hooks is idempotent — no duplicate hook ids after two runs"
TMPDIR5=$(mktemp -d)
mkdir -p "$TMPDIR5/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR5/.claude/settings.json"
export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR5"
export MANIFEST_CAP_HOOKS="true"
export MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
export MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
export OCTOPUS_DIR="$SCRIPT_DIR"
unset OCTOPUS_DISABLED_HOOKS
deliver_hooks "claude"
deliver_hooks "claude"  # second run — must not duplicate
hook_ids=$(python3 -c "
import json, sys
with open('$TMPDIR5/.claude/settings.json') as f:
    s = json.load(f)
ids = [h.get('id') for ev in s.get('hooks', {}).values() for m in ev for h in m.get('hooks', [])]
dups = [i for i in ids if ids.count(i) > 1]
print('duplicates:' + ','.join(set(dups)) if dups else 'ok')
")
[[ "$hook_ids" == "ok" ]] \
  || { echo "FAIL: duplicate hook ids found after two deliver_hooks runs: $hook_ids"; exit 1; }
echo "PASS: deliver_hooks is idempotent"
rm -rf "$TMPDIR5"

echo "Test: bundle-aware — typescript-only hooks excluded for csharp-only project"
TMPDIR_BA=$(mktemp -d)
mkdir -p "$TMPDIR_BA/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_BA/.claude/settings.json"
export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR_BA"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
OCTOPUS_RULES=("common" "csharp")

deliver_hooks "claude" >/dev/null

if grep -q '"id": "console-log-warn"' "$TMPDIR_BA/.claude/settings.json"; then
  echo "FAIL: console-log-warn injected for csharp-only project (should be typescript-only)"
  exit 1
fi
grep -q '"id": "auto-format"' "$TMPDIR_BA/.claude/settings.json" \
  || { echo "FAIL: auto-format missing for csharp project"; exit 1; }
echo "PASS: typescript-only hooks excluded for csharp-only project"
rm -rf "$TMPDIR_BA"

echo "Test: bundle-aware — typescript hooks present for typescript project"
TMPDIR_TS=$(mktemp -d)
mkdir -p "$TMPDIR_TS/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_TS/.claude/settings.json"
export PROJECT_ROOT="$TMPDIR_TS"
OCTOPUS_RULES=("common" "typescript")

deliver_hooks "claude" >/dev/null

grep -q '"id": "console-log-warn"' "$TMPDIR_TS/.claude/settings.json" \
  || { echo "FAIL: console-log-warn missing for typescript project"; exit 1; }
echo "PASS: typescript hooks present for typescript project"
rm -rf "$TMPDIR_TS"

echo "Test: .octopus/hooks/hooks.local.json overrides default formatter hook"
TMPDIR_OV=$(mktemp -d)
mkdir -p "$TMPDIR_OV/.claude" "$TMPDIR_OV/.octopus/hooks"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_OV/.claude/settings.json"
cat > "$TMPDIR_OV/.octopus/hooks/hooks.local.json" << 'HOOKEOF'
{
  "PostToolUse": [
    {
      "matcher": "Write|Edit",
      "hooks": [
        {
          "type": "command",
          "command": "/usr/local/bin/custom-format.sh",
          "id": "auto-format"
        }
      ]
    }
  ]
}
HOOKEOF
export PROJECT_ROOT="$TMPDIR_OV"
OCTOPUS_RULES=("common")

deliver_hooks "claude" >/dev/null

python3 - "$TMPDIR_OV/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
for entry in settings["hooks"].get("PostToolUse", []):
    for hook in entry["hooks"]:
        if hook["id"] == "auto-format":
            if hook["command"] == "/usr/local/bin/custom-format.sh":
                print("PASS: .octopus/hooks/hooks.local.json overrides auto-format")
                sys.exit(0)
            else:
                print(f"FAIL: expected custom-format.sh, got {hook['command']}")
                sys.exit(1)
print("FAIL: auto-format hook not found")
sys.exit(1)
PYEOF
rm -rf "$TMPDIR_OV"

echo "Test: stacks field is stripped from delivered hooks"
TMPDIR_ST=$(mktemp -d)
mkdir -p "$TMPDIR_ST/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_ST/.claude/settings.json"
export PROJECT_ROOT="$TMPDIR_ST"
OCTOPUS_RULES=("common" "typescript")

deliver_hooks "claude" >/dev/null

python3 - "$TMPDIR_ST/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
for event, entries in settings["hooks"].items():
    for entry in entries:
        for hook in entry["hooks"]:
            if "stacks" in hook:
                print(f"FAIL: stacks field leaked into delivered hook {hook.get('id')}")
                sys.exit(1)
print("PASS: no stacks field in delivered hooks")
PYEOF
rm -rf "$TMPDIR_ST"

echo "Test: deliver_hooks refreshes version-pinned paths across an upgrade and keeps user hooks"
TMPDIR_UP=$(mktemp -d)
mkdir -p "$TMPDIR_UP/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_UP/.claude/settings.json"

# Stage two fake version dirs under a shared cache base, each carrying hooks.json
# so the path rewrite produces distinguishable old/new prefixes.
mkdir -p "$TMPDIR_UP/cache/v0.0.1/hooks" "$TMPDIR_UP/cache/v0.0.2/hooks"
cp "$SCRIPT_DIR/hooks/hooks.json" "$TMPDIR_UP/cache/v0.0.1/hooks/hooks.json"
cp "$SCRIPT_DIR/hooks/hooks.json" "$TMPDIR_UP/cache/v0.0.2/hooks/hooks.json"

export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR_UP"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
OCTOPUS_RULES=("common")
unset OCTOPUS_DISABLED_HOOKS || true

# First install: old version.
export OCTOPUS_DIR="$TMPDIR_UP/cache/v0.0.1"
deliver_hooks "claude" >/dev/null

grep -q "cache/v0.0.1/hooks" "$TMPDIR_UP/.claude/settings.json" \
  || { echo "FAIL: old version path not written on first install"; exit 1; }

# A user adds their own hook (id not in the template, command outside the cache base).
python3 - "$TMPDIR_UP/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
settings["hooks"].setdefault("PostToolUse", []).append({
    "matcher": "Write|Edit",
    "hooks": [{"type": "command", "command": "/usr/local/bin/my-hook.sh", "id": "my-custom-hook"}],
})
with open(sys.argv[1], "w") as f:
    json.dump(settings, f, indent=2)
PYEOF

# Upgrade: new version. Old Octopus paths must be replaced, user hook preserved.
export OCTOPUS_DIR="$TMPDIR_UP/cache/v0.0.2"
deliver_hooks "claude" >/dev/null

if grep -q "cache/v0.0.1/" "$TMPDIR_UP/.claude/settings.json"; then
  echo "FAIL: stale v0.0.1 hook path survived the upgrade"
  exit 1
fi

python3 - "$TMPDIR_UP/.claude/settings.json" <<'PYEOF'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)

all_hooks = [h for ev in settings.get("hooks", {}).values() for m in ev for h in m.get("hooks", [])]

# Every Octopus-owned command must now point at the new version.
for h in all_hooks:
    cmd = h.get("command", "")
    if "/cache/v0.0." in cmd and "/cache/v0.0.2/" not in cmd:
        print(f"FAIL: Octopus hook not refreshed to new version: {cmd}")
        sys.exit(1)

# No duplicate ids.
ids = [h.get("id") for h in all_hooks if h.get("id")]
dups = sorted({i for i in ids if ids.count(i) > 1})
if dups:
    print(f"FAIL: duplicate hook ids after upgrade: {','.join(dups)}")
    sys.exit(1)

# The user-added hook survives untouched.
user = [h for h in all_hooks if h.get("id") == "my-custom-hook"]
if len(user) != 1 or user[0].get("command") != "/usr/local/bin/my-hook.sh":
    print("FAIL: user-added hook was dropped or mutated on upgrade")
    sys.exit(1)

print("PASS: version-pinned paths refreshed, user hook preserved, no duplicates")
PYEOF
rm -rf "$TMPDIR_UP"

echo ""
echo "Test: deliver_hooks warns once when the host environment drifts"
TMPDIR_ENV=$(mktemp -d)
mkdir -p "$TMPDIR_ENV/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_ENV/.claude/settings.json"
export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR_ENV"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
export OCTOPUS_DIR="$SCRIPT_DIR"
unset OCTOPUS_DISABLED_HOOKS

# First run, simulated as WSL: no prior marker, must not warn.
unset MSYSTEM
export WSL_DISTRO_NAME="Ubuntu"
out1="$(deliver_hooks "claude")"
[[ "$out1" != *"WARNING:"* ]] \
  || { echo "FAIL: first-ever run warned with no prior marker: $out1"; exit 1; }
[[ "$(cat "$TMPDIR_ENV/.octopus/setup-env")" == "wsl" ]] \
  || { echo "FAIL: marker was not written as 'wsl'"; exit 1; }

# Second run, simulated as Git Bash: environment drifted, must warn once.
unset WSL_DISTRO_NAME
export MSYSTEM="MINGW64"
out2="$(deliver_hooks "claude")"
[[ "$out2" == *"WARNING:"*"wsl"*"msys"* ]] \
  || { echo "FAIL: drift from wsl to msys did not produce a WARNING mentioning both: $out2"; exit 1; }
[[ "$(cat "$TMPDIR_ENV/.octopus/setup-env")" == "msys" ]] \
  || { echo "FAIL: marker was not updated to 'msys'"; exit 1; }

# Third run, same simulated environment: must stay quiet (idempotent).
out3="$(deliver_hooks "claude")"
[[ "$out3" != *"WARNING:"* ]] \
  || { echo "FAIL: repeated run under the same environment warned again: $out3"; exit 1; }

echo "PASS: host-environment drift is detected once and then quiet"
unset MSYSTEM WSL_DISTRO_NAME
rm -rf "$TMPDIR_ENV"

echo ""
echo "Test: deliver_hooks writes hook paths through 'current', not the versioned entry (RM-188)"
TMPDIR_CUR=$(mktemp -d)
mkdir -p "$TMPDIR_CUR/.claude"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_CUR/.claude/settings.json"

# Reproduce the real cache layout: <root>/cache/<version> plus the <root>/current link.
# The whole hooks tree, not just hooks.json: the delivered commands name the
# individual scripts, and this test asserts they still resolve after a bump.
mkdir -p "$TMPDIR_CUR/cli/cache/v0.0.1" "$TMPDIR_CUR/cli/cache/v0.0.2"
cp -r "$SCRIPT_DIR/hooks" "$TMPDIR_CUR/cli/cache/v0.0.1/hooks"
cp -r "$SCRIPT_DIR/hooks" "$TMPDIR_CUR/cli/cache/v0.0.2/hooks"
ln -s "$TMPDIR_CUR/cli/cache/v0.0.1" "$TMPDIR_CUR/cli/current"

export OCTOPUS_HOOKS="true"
export PROJECT_ROOT="$TMPDIR_CUR"
MANIFEST_CAP_HOOKS="true"
MANIFEST_DELIVERY_HOOKS_METHOD="settings_json"
MANIFEST_DELIVERY_HOOKS_TARGET=".claude/settings.json"
OCTOPUS_RULES=("common")
unset OCTOPUS_DISABLED_HOOKS || true
export OCTOPUS_CLI_CACHE_ROOT="$TMPDIR_CUR/cli"
export OCTOPUS_DIR="$TMPDIR_CUR/cli/cache/v0.0.1"

deliver_hooks "claude" >/dev/null

grep -q "/cli/current/hooks/" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: hook paths were not written through 'current'"; exit 1; }
if grep -q "/cli/cache/v0.0.1/hooks/" "$TMPDIR_CUR/.claude/settings.json"; then
  echo "FAIL: a version-pinned path was written while 'current' names the same release"
  exit 1
fi

# The point of the change: bumping the release repoints 'current' and every
# delivered hook still resolves, with no setup re-run in this project.
rm -f "$TMPDIR_CUR/cli/current"
ln -s "$TMPDIR_CUR/cli/cache/v0.0.2" "$TMPDIR_CUR/cli/current"
python3 - "$TMPDIR_CUR/.claude/settings.json" <<'PYEOF2'
import json, os, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
missing = [
    h["command"]
    for ev in settings.get("hooks", {}).values()
    for m in ev
    for h in m.get("hooks", [])
    if "/cli/current/" in h.get("command", "") and not os.path.exists(h["command"])
]
if missing:
    print(f"FAIL: {len(missing)} hook(s) stopped resolving after the version bump: {missing[0]}")
    sys.exit(1)
PYEOF2

echo "PASS: hooks delivered through 'current' survive a version bump"

echo ""
echo "Test: the first setup after upgrading migrates legacy version-pinned paths"
# Settings written by a pre-RM-188 Octopus: absolute paths into a cache entry
# that no longer exists — the exact state that made every hook fail.
python3 - "$TMPDIR_CUR/.claude/settings.json" <<'PYEOF2'
import json, sys
with open(sys.argv[1]) as f:
    settings = json.load(f)
settings["hooks"] = {
    "PreToolUse": [{
        "matcher": "Bash",
        "hooks": [{
            "type": "command",
            "id": "block-no-verify",
            "command": "/home/dev/.octopus-cli/cache/v0.0.0/hooks/pre-tool-use/block-no-verify.sh",
        }],
    }],
    "PostToolUse": [{
        "matcher": "Write|Edit",
        "hooks": [{"type": "command", "command": "/usr/local/bin/my-hook.sh", "id": "my-custom-hook"}],
    }],
}
with open(sys.argv[1], "w") as f:
    json.dump(settings, f, indent=2)
PYEOF2

export OCTOPUS_DIR="$TMPDIR_CUR/cli/cache/v0.0.2"
deliver_hooks "claude" >/dev/null

if grep -q "cache/v0.0.0/" "$TMPDIR_CUR/.claude/settings.json"; then
  echo "FAIL: legacy version-pinned path survived the migration"
  exit 1
fi
grep -q "/cli/current/hooks/pre-tool-use/block-no-verify.sh" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: migrated hook was not rewritten through 'current'"; exit 1; }
grep -q "/usr/local/bin/my-hook.sh" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: user-added hook was dropped during the migration"; exit 1; }

echo "PASS: legacy pinned paths migrate to 'current', user hooks untouched"

echo ""
echo "Test: a hook retired between versions is pruned from the 'current' path"
# Ids carry the prune for hooks that still exist in the template. A hook that
# was REMOVED or RENAMED has no incoming id, so only the path prefix catches
# it — and under RM-188 that path is <root>/current/..., which the install
# root's parent (<root>/cache) does not cover.
python3 - "$TMPDIR_CUR/.claude/settings.json" "$TMPDIR_CUR/cli" <<'PYEOF2'
import json, sys
settings_path, cli_root = sys.argv[1], sys.argv[2]
with open(settings_path) as f:
    settings = json.load(f)
settings["hooks"].setdefault("PreToolUse", []).append({
    "matcher": "Bash",
    "hooks": [{
        "type": "command",
        "id": "retired-in-a-later-version",
        "command": cli_root + "/current/hooks/pre-tool-use/gone.sh",
    }],
})
with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)
PYEOF2

deliver_hooks "claude" >/dev/null

if grep -q "retired-in-a-later-version" "$TMPDIR_CUR/.claude/settings.json"; then
  echo "FAIL: a retired Octopus hook under 'current' was not pruned"
  exit 1
fi
grep -q "/usr/local/bin/my-hook.sh" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: user-added hook was dropped while pruning the retired one"; exit 1; }

echo "PASS: retired hooks under 'current' are pruned, user hooks kept"

echo ""
echo "Test: deliver_hooks keeps the literal path when 'current' names another release"
# A cache entry that 'current' does not point at must not borrow the link —
# doing so would silently deliver a different tree's hooks.
export OCTOPUS_DIR="$TMPDIR_CUR/cli/cache/v0.0.1"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_CUR/.claude/settings.json"
deliver_hooks "claude" >/dev/null
grep -q "/cli/cache/v0.0.1/hooks/" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: mismatched install root did not fall back to the literal path"; exit 1; }
if grep -q "/cli/current/hooks/" "$TMPDIR_CUR/.claude/settings.json"; then
  echo "FAIL: borrowed 'current' while it named a different release"
  exit 1
fi

# A dev checkout is outside the cache root entirely and keeps its own path.
export OCTOPUS_DIR="$SCRIPT_DIR"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_CUR/.claude/settings.json"
deliver_hooks "claude" >/dev/null
grep -q "$SCRIPT_DIR/hooks/" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: dev checkout did not keep its literal hook path"; exit 1; }

echo "PASS: falls back to the literal path outside the cache-plus-current layout"

echo ""
echo "Test: a trailing slash in the cache-root override still uses 'current'"
# The override is compared against pwd-derived paths, so an unnormalized value
# would silently revert delivery to pinned paths with nothing reporting it.
export OCTOPUS_CLI_CACHE_ROOT="$TMPDIR_CUR/cli/"
export OCTOPUS_DIR="$TMPDIR_CUR/cli/cache/v0.0.2"
rm -f "$TMPDIR_CUR/cli/current"; ln -s "$TMPDIR_CUR/cli/cache/v0.0.2" "$TMPDIR_CUR/cli/current"
echo '{"permissions": {}, "hooks": {}, "mcpServers": {}}' > "$TMPDIR_CUR/.claude/settings.json"
deliver_hooks "claude" >/dev/null
grep -q "/cli/current/hooks/" "$TMPDIR_CUR/.claude/settings.json" \
  || { echo "FAIL: a trailing slash in the cache root silently reverted to pinned paths"; exit 1; }
export OCTOPUS_CLI_CACHE_ROOT="$TMPDIR_CUR/cli"

echo "PASS: cache-root override is normalized before comparison"
unset OCTOPUS_CLI_CACHE_ROOT
rm -rf "$TMPDIR_CUR"

echo ""
echo "All hooks injection tests passed!"
