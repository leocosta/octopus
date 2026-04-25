#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CMD_FILE="$SCRIPT_DIR/commands/doc-design.md"
SPEC_CMD_FILE="$SCRIPT_DIR/commands/doc-spec.md"
BUNDLE_FILE="$SCRIPT_DIR/bundles/documentation.yml"
WIZARD="$SCRIPT_DIR/cli/lib/setup-wizard.sh"

echo "Test 1: commands/doc-design.md exists with valid frontmatter"
[[ -f "$CMD_FILE" ]] || { echo "FAIL: $CMD_FILE not found"; exit 1; }
head -n 5 "$CMD_FILE" | grep -q "^name: doc-design$" \
  || { echo "FAIL: frontmatter 'name: doc-design' missing"; exit 1; }
head -n 10 "$CMD_FILE" | grep -q "^description:" \
  || { echo "FAIL: frontmatter 'description:' missing"; exit 1; }
echo "PASS: frontmatter valid"

echo "Test 2: command references templates/spec.md and /octopus:doc-spec fallback"
grep -q "templates/spec.md" "$CMD_FILE" \
  || { echo "FAIL: templates/spec.md reference missing"; exit 1; }
grep -q "/octopus:doc-spec" "$CMD_FILE" \
  || { echo "FAIL: /octopus:doc-spec fallback reference missing"; exit 1; }
echo "PASS: template + doc-spec references present"

echo "Test 3: command documents the HARD-GATE"
grep -q "HARD-GATE:" "$CMD_FILE" \
  || { echo "FAIL: 'HARD-GATE:' anchor missing"; exit 1; }
grep -qE "do not write (production )?code|never writes (production )?code|does not write (production )?code" "$CMD_FILE" \
  || { echo "FAIL: explicit 'do not write code' prohibition missing"; exit 1; }
echo "PASS: HARD-GATE documented"

echo "Test 4: command documents all eight steps"
for n in 1 2 3 4 5 6 7 8; do
  grep -qE "^##+ .*Step $n\b" "$CMD_FILE" \
    || { echo "FAIL: Step $n header missing"; exit 1; }
done
echo "PASS: all eight steps documented"

echo "Test 5: command documents adaptive-section names"
for section in "Non-Goals" "Risks" "Migration"; do
  grep -q "$section" "$CMD_FILE" \
    || { echo "FAIL: adaptive section '$section' missing"; exit 1; }
done
echo "PASS: adaptive sections documented"

echo "Test 6: bundle documentation includes doc-design"
grep -qE "^\s*-\s*doc-design\s*$" "$BUNDLE_FILE" \
  || { echo "FAIL: doc-design not listed in documentation bundle"; exit 1; }
echo "PASS: bundle registration present"

echo "Test 7: wizard includes doc-design"
grep -E "^[[:space:]]*local items=\(.*doc-design.*\)" "$WIZARD" >/dev/null \
  || { echo "FAIL: doc-design not in wizard items array"; exit 1; }
grep -q 'doc-design|' "$WIZARD" \
  || { echo "FAIL: doc-design hint missing"; exit 1; }
echo "PASS: wizard registration present"

echo "Test 8: commands/doc-spec.md chains into doc-design"
grep -q "/octopus:doc-design" "$SPEC_CMD_FILE" \
  || { echo "FAIL: doc-spec does not mention /octopus:doc-design"; exit 1; }
grep -qE "design session|continue into|start design" "$SPEC_CMD_FILE" \
  || { echo "FAIL: doc-spec missing the design-session chain prompt"; exit 1; }
echo "PASS: doc-spec chains into doc-design"

echo "Test 9: HARD-GATE allows docs-only branches and Step 8 creates one"
grep -q "Docs-only branches are permitted" "$CMD_FILE" \
  || { echo "FAIL: HARD-GATE should explicitly permit docs-only branches"; exit 1; }
grep -q "docs/<slug>-design" "$CMD_FILE" \
  || { echo "FAIL: Step 8 should reference docs/<slug>-design branch"; exit 1; }
grep -q "Never commit the spec directly onto" "$CMD_FILE" \
  || { echo "FAIL: Step 8 should forbid committing directly to main/master"; exit 1; }
echo "PASS: docs-only branch flow documented"

echo "Test 10: Step 8 consolidates Author placeholder"
grep -qE "Author.*placeholder|git config user\.name" "$CMD_FILE" \
  || { echo "FAIL: Step 8 should fill Author from git config when still a placeholder"; exit 1; }
echo "PASS: Author placeholder consolidation documented"
