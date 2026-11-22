#!/usr/bin/env bash
source "${BASH_SOURCE[0]%/*}/../../cli/lib/python.sh" 2>/dev/null || true
source "${BASH_SOURCE[0]%/*}/../../cli/lib/hook_scope.sh" 2>/dev/null || exit 0
# Run type checking after editing typed files.
# On failure, returns JSON with decision:block so Claude Code injects the
# error back into Claude's context and it self-corrects in the same turn.

set -euo pipefail

input=$(cat)
file_path=$(echo "$input" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path','') or d.get('file_path',''))" 2>/dev/null || echo "")

[[ -z "$file_path" || ! -f "$file_path" ]] && exit 0
# Type checkers run project code (mypy plugins, MSBuild targets): only for
# files inside the open project. See cli/lib/hook_scope.sh.
octopus_in_project "$file_path" || exit 0

ext="${file_path##*.}"

fail_with() {
  local errors="$1"
  python3 -c "
import json, sys
print(json.dumps({
  'decision': 'block',
  'reason': sys.argv[1]
}))
" "$errors"
  exit 0
}

case "$ext" in
  ts|tsx)
    if command -v tsc &>/dev/null; then
      out=$(tsc --noEmit --pretty 2>&1 | head -20 || true)
    elif command -v npx &>/dev/null; then
      # --no-install: the project's own TypeScript only. Letting npx install
      # here fetched the npm package named "tsc", a deprecated third-party
      # release, not the project's compiler.
      out=$(npx --no-install tsc --noEmit --pretty 2>&1 | head -20 || true)
    fi
    if [[ -n "${out:-}" ]] && echo "$out" | grep -q "error TS"; then
      fail_with "TypeScript errors after edit:
$out
Fix the errors above."
    fi
    ;;
  py|pyi)
    if command -v mypy &>/dev/null; then
      out=$(mypy "$file_path" --no-error-summary 2>&1 | head -10 || true)
    elif command -v pyright &>/dev/null; then
      out=$(pyright "$file_path" 2>&1 | head -10 || true)
    fi
    if [[ -n "${out:-}" ]] && echo "$out" | grep -qE "error:|Error:"; then
      fail_with "Type errors after edit:
$out
Fix the errors above."
    fi
    ;;
  cs)
    if command -v dotnet &>/dev/null; then
      # The nearest .sln or .csproj, never above the project root.
      proj_dir=$(octopus_nearest_project "$file_path" '*.sln' '*.csproj')
      [[ -z "$proj_dir" ]] && proj_dir=$(dirname "$file_path")
      out=$(cd "$proj_dir" && dotnet build --no-restore 2>&1 | grep -E "error CS|Error\(s\)" | head -10 || true)
      if [[ -n "$out" ]] && echo "$out" | grep -q "error CS"; then
        fail_with "Build errors after edit:
$out
Fix the errors above before proceeding."
      fi
    fi
    ;;
esac

exit 0
