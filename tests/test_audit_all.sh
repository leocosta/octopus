#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "Test 1: SKILL.md exists with valid frontmatter"
SKILL_FILE="$SCRIPT_DIR/skills/audit-all/SKILL.md"
[[ -f "$SKILL_FILE" ]] || { echo "FAIL: $SKILL_FILE not found"; exit 1; }
head -n 5 "$SKILL_FILE" | grep -q "^name: audit-all$" \
  || { echo "FAIL: frontmatter 'name' missing"; exit 1; }
head -n 10 "$SKILL_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: SKILL.md documents invocation"
grep -q "^## Invocation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Invocation' missing"; exit 1; }
grep -q "octopus:audit-all" "$SKILL_FILE" \
  || { echo "FAIL: invocation syntax missing"; exit 1; }
for flag in "--base" "--only" "--write-report"; do
  grep -q -- "$flag" "$SKILL_FILE" || { echo "FAIL: flag $flag missing"; exit 1; }
done
echo "PASS: invocation documented"

echo "Test 3: SKILL.md documents discovery + parallel execution"
for section in "^## Shared File Discovery$" "^## Parallel Execution$"; do
  grep -qE "$section" "$SKILL_FILE" \
    || { echo "FAIL: '$section' missing"; exit 1; }
done
grep -q "superpowers:dispatching-parallel-agents" "$SKILL_FILE" \
  || { echo "FAIL: parallel dispatch reference missing"; exit 1; }
grep -q "domain" "$SKILL_FILE" \
  || { echo "FAIL: domain tagging mention missing"; exit 1; }
echo "PASS: discovery + parallel sections documented"

echo "Test 4: SKILL.md documents consolidated report + template exists"
grep -q "^## Consolidated Report$" "$SKILL_FILE" \
  || { echo "FAIL: '## Consolidated Report' missing"; exit 1; }
grep -q "Cross-audit hotspots" "$SKILL_FILE" \
  || { echo "FAIL: hotspots table mention missing"; exit 1; }
TMPL="$SCRIPT_DIR/skills/audit-all/templates/report-header.md.tmpl"
[[ -f "$TMPL" ]] || { echo "FAIL: report-header template missing"; exit 1; }
grep -q "{{AUDITS_RAN}}" "$TMPL" \
  || { echo "FAIL: template missing {{AUDITS_RAN}}"; exit 1; }
grep -q "{{HOTSPOTS_TABLE}}" "$TMPL" \
  || { echo "FAIL: template missing {{HOTSPOTS_TABLE}}"; exit 1; }
echo "PASS: report + template present"

echo "Test 5: SKILL.md documents errors + graceful degradation"
grep -q "^## Errors$" "$SKILL_FILE" \
  || { echo "FAIL: '## Errors' missing"; exit 1; }
grep -q "^## Graceful Degradation$" "$SKILL_FILE" \
  || { echo "FAIL: '## Graceful Degradation' missing"; exit 1; }
echo "PASS: errors + degradation documented"

echo "Test 6: quality-gates bundle lists audit-all + includes deps via resolver"
BUNDLE="$SCRIPT_DIR/bundles/quality-gates.yml"
grep -q -- "- audit-all" "$BUNDLE" \
  || { echo "FAIL: quality-gates missing audit-all"; exit 1; }
for dep in security-scan money-review tenant-scope-audit; do
  if grep -q -- "- $dep" "$BUNDLE"; then
    echo "FAIL: $dep should not be listed explicitly in quality-gates (arrives via depends_on)"
    exit 1
  fi
done
echo "PASS: quality-gates bundle minimized to audit-all"
