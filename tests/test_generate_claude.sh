#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/setup.sh" --source-only

TMPDIR=$(mktemp -d)
PROJECT_ROOT="$TMPDIR"
OCTOPUS_DIR="$SCRIPT_DIR"

OCTOPUS_RULES=(common typescript)
OCTOPUS_SKILLS=(doc-adr)
OCTOPUS_AGENTS=(claude)
declare -A OCTOPUS_AGENT_OUTPUT=()

load_manifest "claude"
generate_main_output "claude"

# Verify CLAUDE.md was generated
[[ -f "$TMPDIR/.claude/CLAUDE.md" ]] || { echo "FAIL: .claude/CLAUDE.md not created"; exit 1; }

# Verify {{RULES}} was replaced
grep -q ".claude/rules/common/" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: common rules not in CLAUDE.md"; exit 1; }
grep -q ".claude/rules/typescript/" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: typescript rules not in CLAUDE.md"; exit 1; }
! grep -q "{{RULES}}" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: {{RULES}} placeholder not replaced"; exit 1; }

# Verify {{SKILLS}} was replaced
grep -q ".claude/skills/doc-adr/" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: adr skill not in CLAUDE.md"; exit 1; }
! grep -q "{{SKILLS}}" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: {{SKILLS}} placeholder not replaced"; exit 1; }

# Verify settings.json was copied
[[ -f "$TMPDIR/.claude/settings.json" ]] || { echo "FAIL: .claude/settings.json not created"; exit 1; }

# Test with no skills
OCTOPUS_SKILLS=()
load_manifest "claude"
generate_main_output "claude"
! grep -q "{{SKILLS}}" "$TMPDIR/.claude/CLAUDE.md" || { echo "FAIL: {{SKILLS}} placeholder should be empty, not literal"; exit 1; }

rm -rf "$TMPDIR"
echo "PASS: Claude generation tests passed"
