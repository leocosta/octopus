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
grep -q "1a1a2e" "$REPO_DIR/cli/control/app.tcss" \
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
