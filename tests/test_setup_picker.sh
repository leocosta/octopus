#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: --bundle starter creates .octopus.yml with bundles: starter"
TMPDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$TMPDIR"
  export OCTOPUS_SCOPE="repo"
  export OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  # source it — should create manifest without launching picker
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle starter --dry-run 2>/dev/null || true
)
grep -q "bundles:" "$TMPDIR/.octopus.yml" 2>/dev/null \
  || { echo "FAIL: .octopus.yml not created with bundles:"; rm -rf "$TMPDIR"; exit 1; }
grep -q "starter" "$TMPDIR/.octopus.yml" \
  || { echo "FAIL: starter not in .octopus.yml"; rm -rf "$TMPDIR"; exit 1; }
rm -rf "$TMPDIR"
echo "PASS"

echo "Test 2: --bundle quality creates .octopus.yml with bundles: quality"
TMPDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$TMPDIR"
  export OCTOPUS_SCOPE="repo"
  export OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle quality --dry-run 2>/dev/null || true
)
grep -q "quality" "$TMPDIR/.octopus.yml" 2>/dev/null \
  || { echo "FAIL: --bundle quality not written to manifest"; rm -rf "$TMPDIR"; exit 1; }
rm -rf "$TMPDIR"
echo "PASS"

echo "Test 3: --no-hooks omits hooks from manifest"
TMPDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$TMPDIR"
  export OCTOPUS_SCOPE="repo"
  export OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle starter --no-hooks --dry-run 2>/dev/null || true
)
grep -q "hooks: true" "$TMPDIR/.octopus.yml" 2>/dev/null \
  && { echo "FAIL: hooks: true should not appear with --no-hooks"; rm -rf "$TMPDIR"; exit 1; }
rm -rf "$TMPDIR"
echo "PASS"

echo "Test 4: --stack dotnet adds dotnet skill and csharp rule"
TMPDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$TMPDIR"
  export OCTOPUS_SCOPE="repo"
  export OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  source "$SCRIPT_DIR/cli/lib/setup.sh" --bundle starter --stack dotnet --dry-run 2>/dev/null || true
)
grep -q "dotnet" "$TMPDIR/.octopus.yml" 2>/dev/null \
  || { echo "FAIL: dotnet skill not in manifest"; rm -rf "$TMPDIR"; exit 1; }
grep -q "csharp" "$TMPDIR/.octopus.yml" 2>/dev/null \
  || { echo "FAIL: csharp rule not in manifest"; rm -rf "$TMPDIR"; exit 1; }
rm -rf "$TMPDIR"
echo "PASS"

echo "Test 5: non-interactive (piped stdin) + no manifest uses starter default"
TMPDIR=$(mktemp -d)
(
  export PROJECT_ROOT="$TMPDIR"
  export OCTOPUS_SCOPE="repo"
  export OCTOPUS_SCOPE_PINNED=1
  CLI_DIR="$SCRIPT_DIR/cli"
  echo "" | source "$SCRIPT_DIR/cli/lib/setup.sh" --dry-run 2>/dev/null || true
) 2>/dev/null || true
# In non-interactive mode the manifest should be created with starter
[[ -f "$TMPDIR/.octopus.yml" ]] \
  || { echo "FAIL: manifest not created in non-interactive mode"; rm -rf "$TMPDIR"; exit 1; }
rm -rf "$TMPDIR"
echo "PASS"

echo "All setup-picker integration tests passed!"
