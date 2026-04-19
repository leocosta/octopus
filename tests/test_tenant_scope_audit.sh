#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/tenant-scope-audit/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: tenant-scope-audit$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:tenant-scope-audit" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--only" "--write-report"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents tenant-scope config + file discovery"
grep -q "^## Tenant-Scope Config$" "$SKILL_FILE" \
  || { echo "FAIL: '## Tenant-Scope Config' missing"; exit 1; }
grep -q "^## File Discovery$" "$SKILL_FILE" \
  || { echo "FAIL: '## File Discovery' missing"; exit 1; }
grep -q "tenantScope:" "$SKILL_FILE" \
  || { echo "FAIL: tenantScope config key missing"; exit 1; }
echo "PASS: config + discovery documented"

echo "Test 4: patterns template exists"
TEMPLATES="$SCRIPT_DIR/skills/tenant-scope-audit/templates"
[[ -f "$TEMPLATES/patterns.md" ]] || { echo "FAIL: patterns.md missing"; exit 1; }
echo "PASS: patterns template present"

echo "Test 5: SKILL.md documents all six inspection checks"
grep -q "^## Inspection Checks$" "$SKILL_FILE" \
  || { echo "FAIL: '## Inspection Checks' missing"; exit 1; }
for check in "T1" "T2" "T3" "T4" "T5" "T6"; do
  grep -q "^### $check " "$SKILL_FILE" \
    || { echo "FAIL: check $check missing"; exit 1; }
done
for keyword in "query-without-filter" "dbcontext-missing-filter" "raw-sql-no-filter" "id-from-route-no-ownership" "join-to-unfiltered-table" "cross-tenant-admin-endpoint"; do
  grep -q "$keyword" "$SKILL_FILE" \
    || { echo "FAIL: check keyword '$keyword' missing"; exit 1; }
done
echo "PASS: all inspection checks documented"

echo "Test 6: SKILL.md documents output + errors"
grep -q "^## Output$" "$SKILL_FILE" \
  || { echo "FAIL: '## Output' missing"; exit 1; }
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "docs/reviews/" "$SKILL_FILE" \
  || { echo "FAIL: report path missing"; exit 1; }
for sev in "🚫 Block" "⚠ Warn" "ℹ Info"; do
  grep -q -- "$sev" "$SKILL_FILE" || { echo "FAIL: severity '$sev' missing"; exit 1; }
done
grep -q "confidence" "$SKILL_FILE" || { echo "FAIL: confidence label missing"; exit 1; }
echo "PASS: output + errors documented"
