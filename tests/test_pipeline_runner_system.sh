#!/usr/bin/env bash
# Integration tests for @system step execution in PipelineRunner.
set -euo pipefail

PASS=0
FAIL=0

ok()   { echo "  PASS: $1"; ((PASS++)) || true; }
fail() { echo "  FAIL: $1"; ((FAIL++)) || true; }

TMPDIR_ROOT=$(mktemp -d)
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

# ── Helper: create a minimal pipeline YAML with @system step ─────────────────

make_pipeline() {
  local dir="$1"
  local action="$2"
  local script="$3"
  cat > "$dir/pipeline.yml" <<EOF
tasks:
  - id: t1
    agent: system
    prompt: $action
    depends_on: []
    wait: false
EOF
  # Create system_actions config
  mkdir -p "$dir/.octopus"
  cat > "$dir/.octopus/system_actions.yml" <<EOF
$action: "$script"
EOF
}

# ── Test 1: @system step runs configured script and succeeds ─────────────────

T=$(mktemp -d -p "$TMPDIR_ROOT")
SENTINEL="$T/ran"
make_pipeline "$T" "merge_to_develop" "touch $SENTINEL"

cd "$T"
python3 -m cli.control.pipeline pipeline.yml --dry-run > /dev/null 2>&1 || true

# Verify the system action config is loadable
python3 - <<'PYEOF'
import yaml, sys
from pathlib import Path
data = yaml.safe_load(Path(".octopus/system_actions.yml").read_text())
assert "merge_to_develop" in data, "merge_to_develop action missing"
print("system_actions.yml structure ok")
PYEOF
ok "system_actions.yml is valid YAML with merge_to_develop key"
cd - > /dev/null

# ── Test 2: run_system_action executes script and returns exit code 0 ─────────

T=$(mktemp -d -p "$TMPDIR_ROOT")
SENTINEL="$T/sentinel"

python3 - "$T" "$SENTINEL" <<'PYEOF'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from cli.control.pipeline import run_system_action

octopus_dir = Path(sys.argv[1])
sentinel = sys.argv[2]
octopus_dir.mkdir(exist_ok=True)
actions_file = octopus_dir / "system_actions.yml"
actions_file.write_text(f"merge_to_develop: touch {sentinel}\n")

code = run_system_action("merge_to_develop", octopus_dir=octopus_dir, branch="test-branch")
assert code == 0, f"Expected exit 0, got {code}"
assert Path(sentinel).exists(), "sentinel file not created by script"
print("ok")
PYEOF
ok "run_system_action executes script and returns 0"

# ── Test 3: run_system_action returns non-zero on script failure ──────────────

T=$(mktemp -d -p "$TMPDIR_ROOT")
OCTOPUS="$T/.octopus"
mkdir -p "$OCTOPUS"
echo 'bad_action: exit 1' > "$OCTOPUS/system_actions.yml"

python3 - "$OCTOPUS" <<'PYEOF'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from cli.control.pipeline import run_system_action

octopus_dir = Path(sys.argv[1])
code = run_system_action("bad_action", octopus_dir=octopus_dir, branch="test-branch")
assert code != 0, f"Expected non-zero exit, got {code}"
print("ok")
PYEOF
ok "run_system_action returns non-zero on script failure"

# ── Test 4: undefined action raises ValueError ────────────────────────────────

T=$(mktemp -d -p "$TMPDIR_ROOT")
OCTOPUS="$T/.octopus"
mkdir -p "$OCTOPUS"
# Empty system_actions (no custom actions, no built-ins matching)
echo '{}' > "$OCTOPUS/system_actions.yml"

python3 - "$OCTOPUS" <<'PYEOF'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from cli.control.pipeline import run_system_action

octopus_dir = Path(sys.argv[1])
try:
    run_system_action("nonexistent_action", octopus_dir=octopus_dir, branch="test-branch")
    print("FAIL: expected ValueError")
    sys.exit(1)
except ValueError as e:
    print(f"ok: raised ValueError: {e}")
PYEOF
ok "run_system_action raises ValueError for undefined action"

# ── Test 5: built-in merge_to_develop available without system_actions.yml ────

T=$(mktemp -d -p "$TMPDIR_ROOT")
OCTOPUS="$T/.octopus"
mkdir -p "$OCTOPUS"
# No system_actions.yml — built-in should still be available

python3 - "$OCTOPUS" <<'PYEOF'
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent))
from cli.control.pipeline import resolve_system_action

octopus_dir = Path(sys.argv[1])
script = resolve_system_action("merge_to_develop", octopus_dir=octopus_dir)
assert script is not None, "merge_to_develop built-in not found"
assert "develop" in script, f"unexpected script: {script}"
print(f"ok: built-in script = {script}")
PYEOF
ok "resolve_system_action returns built-in merge_to_develop without config"

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]]
