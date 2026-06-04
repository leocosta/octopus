#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_RULES=(common typescript)
OCTOPUS_SKILLS=(doc-adr)
OCTOPUS_AGENTS=(copilot)
declare -A OCTOPUS_AGENT_OUTPUT=()

agent="copilot"
load_manifest "copilot"
generate_main_output "copilot"

OUTPUT="$TMPDIR/.github/copilot-instructions.md"

# Verify file was created
[[ -f "$OUTPUT" ]] || { echo "FAIL: copilot-instructions.md not created"; exit 1; }

# Verify header is first
head -1 "$OUTPUT" | grep -q "Copilot" || { echo "FAIL: header not at top"; exit 1; }

# Verify core files are included (in order)
grep -q "Coding Guidelines" "$OUTPUT" || { echo "FAIL: guidelines.md not included"; exit 1; }
grep -q "Architecture" "$OUTPUT" || { echo "FAIL: architecture.md not included"; exit 1; }
grep -q "Commit Conventions" "$OUTPUT" || { echo "FAIL: commit-conventions.md not included"; exit 1; }

# Verify rules are referenced. copilot has native_rules: true, so rules are
# symlinked to .github/instructions/ (the `.instructions.md` mechanism), not
# inlined; the concatenated file carries a reference section instead.
grep -q "## Coding Rules" "$OUTPUT" || { echo "FAIL: Coding Rules reference section missing"; exit 1; }
grep -q ".github/instructions/common/" "$OUTPUT" || { echo "FAIL: common rules reference missing"; exit 1; }
grep -q ".github/instructions/typescript/" "$OUTPUT" || { echo "FAIL: typescript rules reference missing"; exit 1; }

# Verify skills content is appended
grep -q "Architecture Decision Records" "$OUTPUT" || { echo "FAIL: adr SKILL.md not included"; exit 1; }

# Verify correct concatenation order (header before guidelines)
header_line=$(grep -n "Copilot" "$OUTPUT" | head -1 | cut -d: -f1)
guidelines_line=$(grep -n "Coding Guidelines" "$OUTPUT" | head -1 | cut -d: -f1)
[[ "$header_line" -lt "$guidelines_line" ]] || { echo "FAIL: header should come before core content"; exit 1; }

# Test custom output path
OCTOPUS_AGENTS=(gemini)
OCTOPUS_AGENT_OUTPUT=([gemini]="CUSTOM.md")
agent="gemini"
load_manifest "$agent"
generate_main_output "$agent"
[[ -f "$TMPDIR/CUSTOM.md" ]] || { echo "FAIL: custom output path not respected"; exit 1; }
echo "PASS: custom output path test passed"

rm -rf "$TMPDIR"
echo "PASS: concatenation tests passed"


