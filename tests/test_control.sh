#!/usr/bin/env bash
set -euo pipefail

CLI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../cli" && pwd)"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test: octopus control --help exits 0"
bash "$CLI_DIR/octopus.sh" control --help \
  || { echo "FAIL: control --help returned non-zero"; exit 1; }
echo "PASS"

echo "Test: octopus control --help mentions dashboard"
bash "$CLI_DIR/octopus.sh" control --help | grep -q "dashboard" \
  || { echo "FAIL: --help missing 'dashboard'"; exit 1; }
echo "PASS"

echo "Test: app.tcss exists and defines accent color"
grep -q "7B2FBE" "$REPO_DIR/cli/control/app.tcss" \
  || { echo "FAIL: accent color missing from app.tcss"; exit 1; }
grep -q "080c14\|1a1a2e" "$REPO_DIR/cli/control/app.tcss" \
  || { echo "FAIL: background color missing from app.tcss"; exit 1; }
echo "PASS"

echo "Test: Scheduler starts and stops cleanly"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from pathlib import Path
from cli.control.scheduler import Scheduler

fired = []
def on_fire(entry):
    fired.append(entry)

s = Scheduler(Path("/nonexistent/schedule.yml"), on_fire=on_fire)
s.start()
s.stop()
s.join(timeout=2)
assert not s.is_alive(), "Scheduler thread did not stop"
print("PASS: Scheduler starts and stops cleanly")
PYEOF

echo "Test: app.py imports Scheduler"
grep -q "from .scheduler import Scheduler" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: Scheduler not imported in app.py"; exit 1; }
echo "PASS"

echo "Test: app.py uses RichLog, not Label for output panel"
grep -q "RichLog" "$REPO_DIR/cli/control/app.py" \
  || { echo "FAIL: app.py still uses Label for output panel"; exit 1; }
echo "PASS"

echo "Test: SuggestFromList is available in Textual"
python3 -c "from textual.suggester import SuggestFromList; print('PASS: SuggestFromList available')" \
  || { echo "FAIL: SuggestFromList not available"; exit 1; }

echo "Test: skill_matcher returns needs_confirm for NL single match"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from cli.control.skill_matcher import SkillMatcher

MOCK = {"security-scan": {"keywords": ["auth", "jwt"], "model": None}}
m = SkillMatcher(skills_dir=None, _mock=MOCK)
r = m.resolve("check jwt tokens", role_model="claude-sonnet-4-6")
assert r.needs_confirm is True, f"expected needs_confirm=True, got {r}"
print("PASS: NL single match sets needs_confirm")
PYEOF

echo "Test: completed task log path is predictable"
python3 - << 'PYEOF'
import sys
sys.path.insert(0, ".")
from pathlib import Path
from cli.control.process_manager import ProcessManager

tmp = Path("/tmp/octopus-test-log-viewer")
tmp.mkdir(exist_ok=True)
pm = ProcessManager(tmp)
log = pm.logs_dir / "backend-specialist.log"
log.parent.mkdir(parents=True, exist_ok=True)
log.write_text("line1\nline2\n")
assert log.read_text() == "line1\nline2\n"
print("PASS: log file readable at predictable path")
PYEOF

echo "Test: adopt_orphans integration"
cd "$REPO_DIR"
python3 - << 'PYEOF'
import subprocess, sys
from pathlib import Path
sys.path.insert(0, ".")
from cli.control.process_manager import ProcessManager

tmp = Path("/tmp/octopus-test-adopt")
tmp.mkdir(exist_ok=True)
pm = ProcessManager(tmp)
proc = subprocess.Popen(["sleep", "60"])
(tmp / "pids").mkdir(exist_ok=True)
(tmp / "pids" / "backend-specialist.pid").write_text(str(proc.pid))
adopted = pm.adopt_orphans()
assert "backend-specialist" in adopted, f"not adopted: {adopted}"
proc.terminate()
(tmp / "pids" / "backend-specialist.pid").unlink(missing_ok=True)
print("PASS: adopt_orphans")
PYEOF

# Test: --plan flag with --dry-run exits 0 and prints task list
test_control_plan_dry_run() {
  local tmpdir
  tmpdir=$(mktemp -d)
  cat > "$tmpdir/plan.md" <<'EOF'
---
slug: smoke-test
pipeline:
  pr_on_success: false
tasks:
  - id: t1
    agent: backend-specialist
    depends_on: []
---

- [ ] **t1** — echo hello
EOF
  PYTHONPATH="$(pwd)" python3 -m cli.control.pipeline "$tmpdir/plan.md" --dry-run
  local rc=$?
  rm -rf "$tmpdir"
  if [ "$rc" -eq 0 ]; then
    echo "PASS: control --plan --dry-run"
  else
    echo "FAIL: control --plan --dry-run exited $rc"
    return 1
  fi
}
test_control_plan_dry_run

# Test: octopus run --help shows usage
test_run_help() {
  local output
  output=$(bash cli/octopus.sh run --help 2>&1)
  if echo "$output" | grep -q "Usage: octopus run"; then
    echo "PASS: octopus run --help"
  else
    echo "FAIL: octopus run --help — output was:"
    echo "$output"
    return 1
  fi
}
test_run_help

# Test: octopus ask --help shows usage
test_ask_help() {
  local output
  output=$(bash cli/octopus.sh ask --help 2>&1)
  if echo "$output" | grep -q "Usage: octopus ask"; then
    echo "PASS: octopus ask --help"
  else
    echo "FAIL: octopus ask --help — output was:"
    echo "$output"
    return 1
  fi
}
test_ask_help

# Test: octopus ask --dry-run exits 0 and prints role
test_ask_dry_run() {
  local output
  output=$(bash cli/octopus.sh ask tech-writer "write the ADR" --dry-run 2>&1)
  if echo "$output" | grep -q "tech-writer"; then
    echo "PASS: octopus ask --dry-run"
  else
    echo "FAIL: octopus ask --dry-run — output was:"
    echo "$output"
    return 1
  fi
}
test_ask_dry_run
