#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Shadow codex with a no-op to avoid interactive OAuth during tests
SHADOW_DIR=$(mktemp -d)
cat > "$SHADOW_DIR/codex" << 'SHADOW'
#!/bin/bash
exit 1
SHADOW
chmod +x "$SHADOW_DIR/codex"
export PATH="$SHADOW_DIR:$PATH"

# Create a fake consumer repo
TMPDIR=$(mktemp -d)
mkdir -p "$TMPDIR/octopus"

# Symlink octopus content into fake repo
ln -s "$SCRIPT_DIR/core" "$TMPDIR/octopus/core"
ln -s "$SCRIPT_DIR/rules" "$TMPDIR/octopus/rules"
ln -s "$SCRIPT_DIR/skills" "$TMPDIR/octopus/skills"
ln -s "$SCRIPT_DIR/hooks" "$TMPDIR/octopus/hooks"
ln -s "$SCRIPT_DIR/agents" "$TMPDIR/octopus/agents"
ln -s "$SCRIPT_DIR/mcp" "$TMPDIR/octopus/mcp"
ln -s "$SCRIPT_DIR/roles" "$TMPDIR/octopus/roles"
ln -s "$SCRIPT_DIR/commands" "$TMPDIR/octopus/commands"
ln -s "$SCRIPT_DIR/cli" "$TMPDIR/octopus/cli"
ln -s "$SCRIPT_DIR/.env.octopus.example" "$TMPDIR/octopus/.env.octopus.example"
cp "$SCRIPT_DIR/setup.sh" "$TMPDIR/octopus/setup.sh"
chmod +x "$TMPDIR/octopus/setup.sh"

cd "$TMPDIR"

echo "=== Phase 1: Rules + skills + hooks ==="

cat > "$TMPDIR/.octopus.yml" << 'EOF'
rules:
  - csharp
  - typescript

skills:
  - doc-adr
  - test-e2e

hooks: true

agents:
  - claude
  - copilot
  - codex

mcp:
  - notion

workflow: true

reviewers:
  - testuser1

roles:
  - product-manager

commands:
  - name: db-reset
    description: Reset the database
    run: make db-reset
EOF

./octopus/setup.sh

# Verify rules directories exist (per-file symlinks — directories are real, files are symlinks)
[[ -d ".claude/rules/common" ]] || { echo "FAIL: .claude/rules/common directory missing"; exit 1; }
[[ -d ".claude/rules/csharp" ]] || { echo "FAIL: .claude/rules/csharp directory missing"; exit 1; }
[[ -d ".claude/rules/typescript" ]] || { echo "FAIL: .claude/rules/typescript directory missing"; exit 1; }

# Verify individual rule files are symlinks pointing to correct targets
[[ -L ".claude/rules/common/coding-style.md" ]] || { echo "FAIL: coding-style.md not a symlink"; exit 1; }
readlink ".claude/rules/common/coding-style.md" | grep -q "rules/common/coding-style.md" || { echo "FAIL: coding-style.md symlink target wrong"; exit 1; }

# Verify rule files are accessible
[[ -f ".claude/rules/common/coding-style.md" ]] || { echo "FAIL: coding-style.md not accessible"; exit 1; }
[[ -f ".claude/rules/csharp/naming-style.md" ]] || { echo "FAIL: csharp naming-style.md not accessible"; exit 1; }

# Verify .local.md overrides in .octopus/rules/ are symlinked into delivery target
mkdir -p ".octopus/rules/common" ".octopus/rules/csharp"
echo "# override" > ".octopus/rules/common/coding-style.local.md"
echo "# override" > ".octopus/rules/csharp/naming-style.local.md"
./octopus/setup.sh >/dev/null 2>&1
[[ -L ".claude/rules/common/coding-style.local.md" ]] || { echo "FAIL: coding-style.local.md not symlinked"; exit 1; }
[[ -L ".claude/rules/csharp/naming-style.local.md" ]] || { echo "FAIL: csharp naming-style.local.md not symlinked"; exit 1; }
readlink ".claude/rules/common/coding-style.local.md" | grep -q "\.octopus/rules/common/coding-style.local.md" \
  || { echo "FAIL: coding-style.local.md symlink target wrong"; exit 1; }
echo "PASS: .local.md overrides symlinked from .octopus/rules/"

# Verify personal ~/.octopus/rules/ overrides are symlinked (RM-068)
mkdir -p "$HOME/.octopus/rules/common"
echo "# personal override" > "$HOME/.octopus/rules/common/patterns.local.md"
./octopus/setup.sh >/dev/null 2>&1
[[ -L ".claude/rules/common/patterns.local.md" ]] \
  || { echo "FAIL: personal patterns.local.md not symlinked from ~/.octopus/rules/"; exit 1; }
readlink ".claude/rules/common/patterns.local.md" | grep -q "\.octopus/rules/common/patterns.local.md" \
  || { echo "FAIL: patterns.local.md symlink should point to ~/.octopus/rules/"; exit 1; }
echo "PASS: personal ~/.octopus/rules/ overrides symlinked"
# project override wins over personal when both define the same file
echo "# project override" > ".octopus/rules/common/patterns.local.md"
./octopus/setup.sh >/dev/null 2>&1
readlink ".claude/rules/common/patterns.local.md" | grep -q "\.octopus/rules/common/patterns.local.md" \
  && readlink ".claude/rules/common/patterns.local.md" | grep -qv "^$HOME" \
  || { echo "FAIL: project override should win over personal override"; exit 1; }
echo "PASS: project override wins over personal override"
rm -f "$HOME/.octopus/rules/common/patterns.local.md" ".octopus/rules/common/patterns.local.md"

# Verify skills symlinks
[[ -L ".claude/skills/doc-adr" ]] || { echo "FAIL: .claude/skills/doc-adr symlink missing"; exit 1; }
[[ -L ".claude/skills/test-e2e" ]] || { echo "FAIL: .claude/skills/test-e2e symlink missing"; exit 1; }
[[ -f ".claude/skills/doc-adr/SKILL.md" ]] || { echo "FAIL: doc-adr SKILL.md not accessible via symlink"; exit 1; }

# Verify hooks injected into settings.json
python3 -c "
import json
with open('.claude/settings.json') as f:
    data = json.load(f)
hooks = data.get('hooks', {})
assert 'PreToolUse' in hooks, 'PreToolUse hooks missing'
assert 'PostToolUse' in hooks, 'PostToolUse hooks missing'
assert 'Stop' in hooks, 'Stop hooks missing'
assert 'SessionStart' in hooks, 'SessionStart hooks missing'
assert 'SessionEnd' in hooks, 'SessionEnd hooks missing'
# Verify detect-secrets hook exists
pre_hooks = hooks['PreToolUse']
hook_ids = [h['hooks'][0].get('id','') for h in pre_hooks]
assert 'block-no-verify' in hook_ids, 'block-no-verify hook missing'
assert 'detect-secrets' in hook_ids, 'detect-secrets hook missing'
print('PASS: hooks injected correctly')
"

# Verify MCP injection
python3 -c "
import json
with open('.claude/settings.json') as f:
    data = json.load(f)
assert 'notion' in data.get('mcpServers', {}), 'MCP not injected'
print('PASS: MCP injection verified')
"

# Verify CLAUDE.md has rules and skills
grep -q ".claude/rules/csharp/" ".claude/CLAUDE.md" || { echo "FAIL: csharp rules not in CLAUDE.md"; exit 1; }
grep -q ".claude/skills/doc-adr/" ".claude/CLAUDE.md" || { echo "FAIL: adr skill not in CLAUDE.md"; exit 1; }

# Verify copilot rules are symlinked as .instructions.md (native_rules: true)
[[ -d ".github/instructions" ]] || { echo "FAIL: .github/instructions/ missing for copilot"; exit 1; }
[[ -L ".github/instructions/common/coding-style.instructions.md" ]] \
  || { echo "FAIL: coding-style.instructions.md not symlinked for copilot"; exit 1; }
echo "PASS: copilot rules symlinked as .instructions.md"

# Verify codex rules are symlinked as .md (native_rules: true)
[[ -d ".codex/rules" ]] || { echo "FAIL: .codex/rules/ missing for codex"; exit 1; }
[[ -L ".codex/rules/common/coding-style.md" ]] \
  || { echo "FAIL: coding-style.md not symlinked for codex"; exit 1; }
echo "PASS: codex rules symlinked as .md"

# Verify copilot-instructions.md references .github/instructions/ (RM-073)
grep -q "\.github/instructions/" ".github/copilot-instructions.md" \
  || { echo "FAIL: copilot-instructions.md does not reference .github/instructions/"; exit 1; }
echo "PASS: copilot-instructions.md references rules path (RM-073)"

# Verify AGENTS.md references .codex/rules/ (RM-073)
grep -q "\.codex/rules/" "AGENTS.md" \
  || { echo "FAIL: AGENTS.md does not reference .codex/rules/"; exit 1; }
echo "PASS: AGENTS.md references rules path (RM-073)"

# Verify workspace rules are symlinked (RM-069)
WORKSPACE_DIR=$(mktemp -d)
mkdir -p "$WORKSPACE_DIR/rules/common" "$WORKSPACE_DIR/rules/csharp"
echo "# workspace shared style" > "$WORKSPACE_DIR/rules/common/workspace-style.local.md"
echo "# workspace csharp" > "$WORKSPACE_DIR/rules/csharp/workspace-csharp.local.md"
# Add workspace: to .octopus.yml and re-run setup
echo "workspace: $WORKSPACE_DIR" >> .octopus.yml
./octopus/setup.sh >/dev/null 2>&1
[[ -L ".claude/rules/common/workspace-style.local.md" ]] \
  || { echo "FAIL: workspace common rule not symlinked"; exit 1; }
[[ -L ".claude/rules/csharp/workspace-csharp.local.md" ]] \
  || { echo "FAIL: workspace csharp rule not symlinked"; exit 1; }
# Project override still wins over workspace
echo "# project wins" > ".octopus/rules/common/workspace-style.local.md"
./octopus/setup.sh >/dev/null 2>&1
readlink ".claude/rules/common/workspace-style.local.md" | grep -q "\.octopus/rules" \
  || { echo "FAIL: project override should win over workspace rule"; exit 1; }
rm -f ".octopus/rules/common/workspace-style.local.md"
rm -rf "$WORKSPACE_DIR"
echo "PASS: workspace rules symlinked and project override wins (RM-069)"

# Verify workflow commands
[[ -f ".claude/commands/octopus:branch-create.md" ]] || { echo "FAIL: workflow command missing"; exit 1; }
[[ -f ".claude/commands/octopus:doc-research.md" ]] || { echo "FAIL: doc-research command missing"; exit 1; }
[[ -f ".claude/commands/octopus:db-reset.md" ]] || { echo "FAIL: custom command missing"; exit 1; }

# Verify doc-research command content (first frontmatter stripped, instructions present)
grep -q "Instructions" ".claude/commands/octopus:doc-research.md" || { echo "FAIL: doc-research instructions missing"; exit 1; }
grep -q "Context Scan" ".claude/commands/octopus:doc-research.md" || { echo "FAIL: doc-research context scan step missing"; exit 1; }

# Verify CLAUDE.md references roadmap
grep -q "docs/roadmap.md" ".claude/CLAUDE.md" || { echo "FAIL: roadmap reference missing from CLAUDE.md"; exit 1; }

# Verify roles
[[ -f ".claude/agents/product-manager.md" ]] || { echo "FAIL: product-manager role missing"; exit 1; }
grep -q "product-manager" ".claude/agents/product-manager.md" || { echo "FAIL: product-manager role content missing"; exit 1; }

# Verify .gitignore entries
grep -q ".claude/rules/" ".gitignore" || { echo "FAIL: .gitignore missing rules entry"; exit 1; }
grep -q ".claude/skills/" ".gitignore" || { echo "FAIL: .gitignore missing skills entry"; exit 1; }

echo "PASS: Phase 1 (rules + skills + hooks)"

rm -rf "$TMPDIR" "$SHADOW_DIR"
echo "PASS: full integration test passed"
